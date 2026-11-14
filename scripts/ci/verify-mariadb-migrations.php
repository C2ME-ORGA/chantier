#!/usr/bin/env php
<?php

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;
use Illuminate\Support\Facades\DB;

/**
 * Vérifie que toutes les migrations sont appliquées sur la base MariaDB de CI.
 *
 * Ce script est exécuté après `php artisan migrate:fresh` par le job
 * `mariadb` de .github/workflows/tests.yml. Il compare les fichiers de
 * migration au registre `migrations` de Laravel et échoue si une migration
 * est en attente ou inconnue.
 *
 *   php scripts/ci/verify-mariadb-migrations.php
 */
$projectRoot = dirname(__DIR__, 2);

$fail = static function (string $message): never {
    fwrite(STDERR, "ÉCHEC : {$message}\n");

    exit(1);
};

try {
    require $projectRoot.'/vendor/autoload.php';

    /** @var Application $app */
    $app = require $projectRoot.'/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();
} catch (Throwable $exception) {
    $fail('démarrage de Laravel impossible : '.$exception->getMessage());
}

$connectionName = (string) config('database.default');

if ($connectionName !== 'mariadb') {
    $fail(sprintf(
        'la connexion par défaut est « %s » ; DB_CONNECTION=mariadb est requis.',
        $connectionName,
    ));
}

$connection = DB::connection($connectionName);

if ($connection->getDriverName() !== 'mariadb') {
    $fail(sprintf(
        'la connexion « %s » utilise le pilote « %s » au lieu de « mariadb ».',
        $connectionName,
        $connection->getDriverName(),
    ));
}

if ($connection->getDatabaseName() !== 'chantier_test') {
    $fail(sprintf(
        'la base ciblée est « %s » ; la base isolée « chantier_test » est requise.',
        $connection->getDatabaseName(),
    ));
}

$files = glob($projectRoot.'/database/migrations/*.php') ?: [];
$expected = array_map(
    static fn (string $file): string => basename($file, '.php'),
    $files
);
sort($expected);

if ($expected === []) {
    $fail('aucun fichier de migration trouvé dans database/migrations.');
}

$table = (string) config('database.migrations.table', 'migrations');

try {
    $rows = $connection->table($table)
        ->orderBy('batch')
        ->orderBy('migration')
        ->get(['migration', 'batch']);
} catch (Throwable $exception) {
    $fail(sprintf('registre « %s » illisible : %s', $table, $exception->getMessage()));
}

$ran = [];

foreach ($rows as $row) {
    $ran[(string) $row->migration] = (int) $row->batch;
}

$pending = array_values(array_diff($expected, array_keys($ran)));
$unknown = array_values(array_diff(array_keys($ran), $expected));

fwrite(STDOUT, "Base MariaDB       : {$connection->getDatabaseName()}\n");
fwrite(STDOUT, 'Migrations trouvées: '.count($expected)."\n");
fwrite(STDOUT, 'Migrations à jour   : '.count($ran)."\n");

foreach ($expected as $migration) {
    $batch = $ran[$migration] ?? null;

    fwrite(STDOUT, sprintf(
        "  - %s (batch %s)\n",
        $migration,
        $batch === null ? 'manquant' : (string) $batch,
    ));
}

if ($pending !== []) {
    $fail('migrations en attente : '.implode(', ', $pending));
}

if ($unknown !== []) {
    $fail('migrations inconnues dans le registre : '.implode(', ', $unknown));
}

fwrite(STDOUT, "Migration MariaDB : à jour.\n");

exit(0);
