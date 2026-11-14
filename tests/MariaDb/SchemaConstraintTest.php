<?php

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

function chan21MariaDbColumn(string $table, string $column): object
{
    $row = DB::selectOne(
        'SELECT COLUMN_TYPE AS column_type, IS_NULLABLE AS is_nullable, '
        .'COLUMN_DEFAULT AS column_default, EXTRA AS extra '
        .'FROM information_schema.COLUMNS '
        .'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        [$table, $column]
    );

    if ($row === null) {
        throw new RuntimeException("Colonne introuvable : {$table}.{$column}");
    }

    return $row;
}

/**
 * @return list<object>
 */
function chan21MariaDbIndex(string $table, string $index): array
{
    return DB::select(
        'SELECT INDEX_NAME AS index_name, NON_UNIQUE AS non_unique, '
        .'SEQ_IN_INDEX AS seq_in_index, COLUMN_NAME AS column_name '
        .'FROM information_schema.STATISTICS '
        .'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ? '
        .'ORDER BY SEQ_IN_INDEX',
        [$table, $index]
    );
}

test('conserve les types texte natifs MariaDB', function () {
    expect(chan21MariaDbColumn('users', 'remember_token')->column_type)->toBe('varchar(100)')
        ->and(chan21MariaDbColumn('sessions', 'ip_address')->column_type)->toBe('varchar(45)')
        ->and(chan21MariaDbColumn('sessions', 'payload')->column_type)->toBe('longtext')
        ->and(chan21MariaDbColumn('cache', 'value')->column_type)->toBe('mediumtext')
        ->and(chan21MariaDbColumn('jobs', 'payload')->column_type)->toBe('longtext')
        ->and(chan21MariaDbColumn('failed_jobs', 'exception')->column_type)->toBe('longtext');
});

test('conserve les entiers natifs MariaDB', function () {
    expect(chan21MariaDbColumn('jobs', 'attempts')->column_type)->toBe('smallint(5) unsigned')
        ->and(chan21MariaDbColumn('jobs', 'reserved_at')->column_type)->toBe('int(10) unsigned')
        ->and(chan21MariaDbColumn('jobs', 'available_at')->column_type)->toBe('int(10) unsigned')
        ->and(chan21MariaDbColumn('jobs', 'created_at')->column_type)->toBe('int(10) unsigned')
        ->and(chan21MariaDbColumn('job_batches', 'total_jobs')->column_type)->toBe('int(11)')
        ->and(chan21MariaDbColumn('cache', 'expiration')->column_type)->toBe('bigint(20)');
});

test('respecte les colonnes nullables et obligatoires', function () {
    expect(chan21MariaDbColumn('users', 'email_verified_at')->is_nullable)->toBe('YES')
        ->and(chan21MariaDbColumn('users', 'remember_token')->is_nullable)->toBe('YES')
        ->and(chan21MariaDbColumn('users', 'name')->is_nullable)->toBe('NO')
        ->and(chan21MariaDbColumn('users', 'email')->is_nullable)->toBe('NO')
        ->and(chan21MariaDbColumn('sessions', 'user_id')->is_nullable)->toBe('YES')
        ->and(chan21MariaDbColumn('sessions', 'payload')->is_nullable)->toBe('NO')
        ->and(chan21MariaDbColumn('cache', 'value')->is_nullable)->toBe('NO')
        ->and(chan21MariaDbColumn('cache_locks', 'owner')->is_nullable)->toBe('NO')
        ->and(chan21MariaDbColumn('failed_jobs', 'uuid')->is_nullable)->toBe('NO')
        ->and(chan21MariaDbColumn('job_batches', 'options')->is_nullable)->toBe('YES')
        ->and(chan21MariaDbColumn('job_batches', 'cancelled_at')->is_nullable)->toBe('YES')
        ->and(chan21MariaDbColumn('job_batches', 'finished_at')->is_nullable)->toBe('YES');
});

test('conserve la valeur par défaut du timestamp failed_at', function () {
    expect(chan21MariaDbColumn('failed_jobs', 'failed_at')->column_default)
        ->toContain('current_timestamp');
});

test('conserve les index uniques des emails et des uuid', function () {
    $email = chan21MariaDbIndex('users', 'users_email_unique');
    $uuid = chan21MariaDbIndex('failed_jobs', 'failed_jobs_uuid_unique');

    expect($email)->toHaveCount(1)
        ->and($email[0]->column_name)->toBe('email')
        ->and((int) $email[0]->non_unique)->toBe(0)
        ->and($uuid)->toHaveCount(1)
        ->and($uuid[0]->column_name)->toBe('uuid')
        ->and((int) $uuid[0]->non_unique)->toBe(0);
});

test('conserve l index composite de failed_jobs', function () {
    $index = chan21MariaDbIndex('failed_jobs', 'failed_jobs_connection_queue_failed_at_index');

    expect(array_map(static fn (object $row): string => $row->column_name, $index))
        ->toBe(['connection', 'queue', 'failed_at'])
        ->and((int) $index[0]->non_unique)->toBe(1);
});

test('conserve les index simples des sessions, du cache et des jobs', function () {
    expect(chan21MariaDbIndex('sessions', 'sessions_user_id_index'))->toHaveCount(1)
        ->and(chan21MariaDbIndex('sessions', 'sessions_last_activity_index'))->toHaveCount(1)
        ->and(chan21MariaDbIndex('cache', 'cache_expiration_index'))->toHaveCount(1)
        ->and(chan21MariaDbIndex('cache_locks', 'cache_locks_expiration_index'))->toHaveCount(1)
        ->and(chan21MariaDbIndex('jobs', 'jobs_queue_index'))->toHaveCount(1);
});

test('conserve les clés primaires des tables migrées', function () {
    $primaryKeys = [
        'users' => 'id',
        'password_reset_tokens' => 'email',
        'sessions' => 'id',
        'cache' => 'key',
        'cache_locks' => 'key',
        'jobs' => 'id',
        'job_batches' => 'id',
        'failed_jobs' => 'id',
    ];

    foreach ($primaryKeys as $table => $column) {
        $primary = chan21MariaDbIndex($table, 'PRIMARY');

        expect($primary)->toHaveCount(1, "Clé primaire absente : {$table}")
            ->and($primary[0]->column_name)->toBe($column, "Clé primaire inattendue : {$table}");
    }
});

test('refuse un uuid de failed_jobs en double', function () {
    $uuid = (string) Str::uuid();
    $row = [
        'uuid' => $uuid,
        'connection' => 'database',
        'queue' => 'default',
        'payload' => '{}',
        'exception' => 'Exception de test',
    ];

    DB::table('failed_jobs')->insert($row);

    $this->expectException(QueryException::class);

    DB::table('failed_jobs')->insert($row);
});

test('renseigne failed_at par défaut sur MariaDB', function () {
    $uuid = (string) Str::uuid();

    DB::table('failed_jobs')->insert([
        'uuid' => $uuid,
        'connection' => 'database',
        'queue' => 'default',
        'payload' => '{}',
        'exception' => 'Exception de test',
    ]);

    expect(DB::table('failed_jobs')->where('uuid', $uuid)->value('failed_at'))->not->toBeNull();
});

test('accepte une session sans utilisateur mais exige une charge utile', function () {
    DB::table('sessions')->insert([
        'id' => 'session-mariadb-test',
        'user_id' => null,
        'ip_address' => null,
        'user_agent' => null,
        'payload' => 'payload',
        'last_activity' => time(),
    ]);

    expect(DB::table('sessions')->where('id', 'session-mariadb-test')->exists())->toBeTrue();
});
