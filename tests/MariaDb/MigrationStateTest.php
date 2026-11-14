<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

test('toutes les migrations sont appliquées sur MariaDB', function () {
    $files = glob(database_path('migrations/*.php')) ?: [];
    $expected = array_map(
        static fn (string $file): string => basename($file, '.php'),
        $files
    );
    sort($expected);

    $ran = DB::table('migrations')->orderBy('migration')->pluck('migration')->all();
    sort($ran);

    expect($expected)->not->toBeEmpty()
        ->and($ran)->toBe($expected);
});

test('les tables créées par les migrations existent', function () {
    $tables = [
        'users',
        'password_reset_tokens',
        'sessions',
        'cache',
        'cache_locks',
        'jobs',
        'job_batches',
        'failed_jobs',
    ];

    foreach ($tables as $table) {
        expect(Schema::hasTable($table))->toBeTrue("Table absente : {$table}");
    }
});
