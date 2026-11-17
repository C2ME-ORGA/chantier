#!/usr/bin/env php
<?php

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Migrations\Migrator;
use Illuminate\Foundation\Application;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Vérifie que toutes les migrations sont appliquées sur la base SQLite de CI.
 *
 * Ce script est exécuté après `php artisan migrate` par le job `sqlite` de
 * .github/workflows/tests.yml. Il compare les fichiers de migration au registre
 * `migrations` de Laravel et échoue si une migration est en attente ou inconnue.
 *
 *   php scripts/ci/verify-sqlite-migrations.php
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

if ($connectionName !== 'sqlite') {
    $fail(sprintf(
        'la connexion par défaut est « %s » ; DB_CONNECTION=sqlite est requis.',
        $connectionName,
    ));
}

$connection = DB::connection($connectionName);

if ($connection->getDriverName() !== 'sqlite') {
    $fail(sprintf(
        'la connexion « %s » utilise le pilote « %s » au lieu de « sqlite ».',
        $connectionName,
        $connection->getDriverName(),
    ));
}

if (basename($connection->getDatabaseName()) !== 'testing.sqlite') {
    $fail(sprintf(
        'la base ciblée est « %s » ; le fichier dédié « testing.sqlite » est requis.',
        $connection->getDatabaseName(),
    ));
}

$table = (string) config('database.migrations.table', 'migrations');

if (! Schema::hasTable($table)) {
    $fail(sprintf('le registre « %s » est absent ; exécutez les migrations SQLite.', $table));
}

/** @var Migrator $migrator */
$migrator = $app->make('migrator');
$files = $migrator->getMigrationFiles(database_path('migrations'));
$expected = array_keys($files);
sort($expected);

if ($expected === []) {
    $fail('aucun fichier de migration trouvé dans database/migrations.');
}

try {
    $ran = $migrator->getRepository()->getRan();
} catch (Throwable $exception) {
    $fail(sprintf('registre « %s » illisible : %s', $table, $exception->getMessage()));
}

sort($ran);

$pending = array_values(array_diff($expected, $ran));
$unknown = array_values(array_diff($ran, $expected));

fwrite(STDOUT, "Base SQLite        : {$connection->getDatabaseName()}\n");
fwrite(STDOUT, 'Migrations trouvées: '.count($expected)."\n");
fwrite(STDOUT, 'Migrations à jour   : '.count($ran)."\n");

foreach ($expected as $migration) {
    fwrite(STDOUT, sprintf(
        "  - %s (%s)\n",
        $migration,
        in_array($migration, $ran, true) ? 'appliquée' : 'manquante',
    ));
}

if ($pending !== []) {
    $fail('migrations en attente : '.implode(', ', $pending));
}

if ($unknown !== []) {
    $fail('migrations inconnues dans le registre : '.implode(', ', $unknown));
}

fwrite(STDOUT, "Migration SQLite : à jour.\n");

exit(0);
