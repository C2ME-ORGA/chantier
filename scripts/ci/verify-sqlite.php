#!/usr/bin/env php
<?php

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;
use Illuminate\Support\Facades\DB;

/**
 * Vérifie que Laravel établit réellement une connexion SQLite sur le fichier
 * de test dédié.
 *
 * Ce script est exécuté par le job `sqlite` de .github/workflows/tests.yml.
 * Il utilise la configuration Laravel et jamais une connexion PDO construite
 * à la main.
 *
 *   php scripts/ci/verify-sqlite.php
 *
 * Le script échoue avec un code de sortie non nul si le pilote n'est pas
 * SQLite, si le fichier n'est pas le fichier de test dédié ou si la connexion
 * ne répond pas.
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

if (! extension_loaded('pdo_sqlite')) {
    $fail('l\'extension PHP pdo_sqlite est absente ; la connexion SQLite est impossible.');
}

$expectedDatabase = (string) config("database.connections.{$connectionName}.database");

if ($expectedDatabase === '' || $expectedDatabase === ':memory:') {
    $fail('la connexion SQLite doit cibler un fichier de test dédié, pas une base en mémoire.');
}

if (basename($expectedDatabase) !== 'testing.sqlite') {
    $fail(sprintf(
        'la base SQLite doit être le fichier dédié « testing.sqlite », fichier configuré : « %s ».',
        $expectedDatabase,
    ));
}

$expectedRealPath = realpath($expectedDatabase);

if ($expectedRealPath === false || ! is_file($expectedRealPath)) {
    $fail(sprintf(
        'le fichier SQLite de test « %s » est absent ; créez-le avant les migrations.',
        $expectedDatabase,
    ));
}

if (! is_readable($expectedRealPath) || ! is_writable($expectedRealPath)) {
    $fail(sprintf(
        'le fichier SQLite de test « %s » doit être lisible et inscriptible.',
        $expectedDatabase,
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

try {
    $pdo = $connection->getPdo();
    $version = (string) $connection->selectOne('SELECT sqlite_version() AS version')->version;
    $databaseList = $connection->select('PRAGMA database_list');
} catch (Throwable $exception) {
    $fail('connexion SQLite impossible : '.$exception->getMessage());
}

if ($pdo->getAttribute(PDO::ATTR_DRIVER_NAME) !== 'sqlite') {
    $fail('la connexion PDO effective n\'utilise pas le pilote sqlite.');
}

$actualDatabase = '';

foreach ($databaseList as $database) {
    if ((string) ($database->name ?? '') === 'main') {
        $actualDatabase = (string) ($database->file ?? '');

        break;
    }
}

$actualRealPath = $actualDatabase !== '' ? realpath($actualDatabase) : false;

if ($actualRealPath === false || $actualRealPath !== $expectedRealPath) {
    $fail(sprintf(
        'la base SQLite connectée « %s » ne correspond pas au fichier de test « %s ».',
        $actualDatabase !== '' ? $actualDatabase : 'inconnue',
        $expectedRealPath,
    ));
}

$foreignKeys = $connection->selectOne('PRAGMA foreign_keys');

if ((int) ($foreignKeys->foreign_keys ?? 0) !== 1) {
    $fail('les contraintes de clés étrangères SQLite ne sont pas activées.');
}

fwrite(STDOUT, "Connexion SQLite valide.\n");
fwrite(STDOUT, "  Connexion        : {$connectionName}\n");
fwrite(STDOUT, "  Pilote           : sqlite\n");
fwrite(STDOUT, "  Base de données  : {$actualRealPath}\n");
fwrite(STDOUT, "  Version SQLite   : {$version}\n");
fwrite(STDOUT, "  Clés étrangères  : activées\n");

exit(0);
