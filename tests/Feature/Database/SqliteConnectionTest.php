<?php

use Illuminate\Support\Facades\DB;

test('la suite rapide utilise une connexion SQLite isolée et jamais MariaDB', function (): void {
    $connection = DB::connection();
    $database = (string) $connection->getDatabaseName();

    expect($connection->getDriverName())->toBe('sqlite')
        ->and($connection->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME))->toBe('sqlite')
        ->and($database === ':memory:' || basename($database) === 'testing.sqlite')->toBeTrue()
        ->and($database)->not->toBe('chantier_test')
        ->and($database)->not->toBe('chantier_c2me');
});

test('la connexion SQLite applique les contraintes de clés étrangères', function (): void {
    $foreignKeys = DB::connection()->selectOne('PRAGMA foreign_keys');

    expect((int) ($foreignKeys->foreign_keys ?? 0))->toBe(1);
});
