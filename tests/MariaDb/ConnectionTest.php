<?php

use Illuminate\Support\Facades\DB;

test('la suite MariaDB utilise réellement MariaDB 10.11', function () {
    $version = DB::selectOne('SELECT VERSION() AS version')->version;

    expect(DB::connection()->getDriverName())->toBe('mariadb')
        ->and(DB::connection()->getDatabaseName())->toBe('chantier_test')
        ->and($version)->toContain('MariaDB')
        ->and($version)->toMatch('/^10\.11\./');
});

test('la connexion MariaDB utilise utf8mb4 et la collation attendue', function () {
    $session = DB::selectOne(
        'SELECT @@character_set_connection AS charset, @@collation_connection AS collation'
    );

    expect($session->charset)->toBe('utf8mb4')
        ->and($session->collation)->toBe('utf8mb4_unicode_ci');
});
