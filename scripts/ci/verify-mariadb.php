#!/usr/bin/env php
<?php

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;
use Illuminate\Support\Facades\DB;

/**
 * Vérifie que Laravel établit réellement une connexion à MariaDB 10.11.
 *
 * Ce script est exécuté par le job `mariadb` de .github/workflows/tests.yml.
 * Il utilise la configuration Laravel (config/database.php et variables
 * d'environnement) et jamais une connexion PDO construite à la main.
 *
 *   php scripts/ci/verify-mariadb.php
 *
 * Le script se connecte réellement, identifie le serveur et sa version, puis
 * échoue avec un code de sortie non nul si la connexion est impossible ou si
 * le serveur n'est pas MariaDB 10.11. Aucun mot de passe n'est affiché.
 */
$projectRoot = dirname(__DIR__, 2);

$fail = static function (string $message): never {
    fwrite(STDERR, "ÉCHEC : {$message}\n");

    exit(1);
};

/**
 * Détermine si une erreur de connexion MariaDB peut disparaître en réessayant.
 *
 * Codes pilote MySQL/MariaDB considérés comme temporaires :
 * - 1040 et 1203 : nombre maximal de connexions atteint ;
 * - 1053 : arrêt du serveur en cours ;
 * - 1927 : connexion interrompue par le serveur (MariaDB) ;
 * - 2002 : connexion refusée ; 2003 : hôte injoignable ;
 * - 2006, 2013 et 2055 : connexion perdue.
 *
 * Codes pilote considérés comme permanents :
 * - 1044 et 1045 : accès refusé ;
 * - 1046 : aucune base sélectionnée ; 1049 : base inconnue ;
 * - 2005 : hôte inconnu.
 *
 * La classe SQLSTATE 08 regroupe les exceptions de connexion ; 28000 couvre
 * l'authentification. Toute autre erreur est considérée comme permanente.
 *
 * @return array{transient: bool, label: string}
 */
function classify_connection_error(Throwable $exception): array
{
    $driverCode = null;

    if ($exception instanceof PDOException) {
        $errorInfo = $exception->errorInfo;

        if (is_array($errorInfo) && is_numeric($errorInfo[1] ?? null)) {
            $driverCode = (int) $errorInfo[1];
        }
    }

    if (in_array($driverCode, [1040, 1053, 1203, 1927, 2002, 2003, 2006, 2013, 2055], true)) {
        return ['transient' => true, 'label' => 'disponibilité du serveur'];
    }

    if (in_array($driverCode, [1044, 1045, 1046, 1049, 2005], true)) {
        return ['transient' => false, 'label' => 'authentification ou configuration'];
    }

    $sqlState = (string) $exception->getCode();

    if (str_starts_with($sqlState, '08')) {
        return ['transient' => true, 'label' => 'lien de communication'];
    }

    if ($sqlState === '28000') {
        return ['transient' => false, 'label' => 'authentification'];
    }

    if (str_contains(strtolower($exception->getMessage()), 'could not find driver')) {
        return ['transient' => false, 'label' => 'pilote PDO absent'];
    }

    return ['transient' => false, 'label' => 'erreur non temporaire'];
}

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

if (! extension_loaded('pdo_mysql')) {
    $fail('l\'extension PHP pdo_mysql est absente ; la connexion MariaDB est impossible.');
}

// Limite chaque tentative à 5 s. La surcharge est locale au processus CI : la
// configuration globale de l'application n'est pas modifiée.
$connectionConfig = config("database.connections.{$connectionName}");
$connectionConfig = is_array($connectionConfig) ? $connectionConfig : [];

$connectionOptions = is_array($connectionConfig['options'] ?? null) ? $connectionConfig['options'] : [];
$connectionOptions[PDO::ATTR_TIMEOUT] = 5;
$connectionConfig['options'] = $connectionOptions;

config(["database.connections.{$connectionName}" => $connectionConfig]);
DB::purge($connectionName);

$connection = DB::connection($connectionName);

if ($connection->getDriverName() !== 'mariadb') {
    $fail(sprintf(
        'la connexion « %s » utilise le pilote « %s » au lieu de « mariadb ».',
        $connectionName,
        $connection->getDriverName(),
    ));
}

$expectedDatabase = (string) config("database.connections.{$connectionName}.database");

// 30 tentatives par défaut, avec 2 s entre les essais. La variable
// CI_DB_CONNECT_ATTEMPTS permet de réduire l'attente lors d'un contrôle local.
$attempts = max(1, (int) (getenv('CI_DB_CONNECT_ATTEMPTS') ?: 30));
$server = null;
$lastError = null;

for ($attempt = 1; $attempt <= $attempts; $attempt++) {
    try {
        $connection->getPdo();

        $row = $connection->selectOne(
            'SELECT VERSION() AS version, @@version_comment AS version_comment, '
            .'@@hostname AS hostname, DATABASE() AS current_database'
        );

        $server = (array) $row;

        break;
    } catch (Throwable $exception) {
        $classification = classify_connection_error($exception);
        $lastError = $exception->getMessage();
        $connection->disconnect();

        if (! $classification['transient']) {
            $fail(sprintf(
                'erreur MariaDB permanente (%s) : %s',
                $classification['label'],
                $lastError,
            ));
        }

        if ($attempt < $attempts) {
            fwrite(STDOUT, sprintf(
                "MariaDB indisponible (%s, tentative %d/%d), nouvelle tentative dans 2 s.\n",
                $classification['label'],
                $attempt,
                $attempts,
            ));

            sleep(2);
        }
    }
}

if ($server === null) {
    $fail(sprintf(
        'connexion MariaDB indisponible après %d tentatives : %s',
        $attempts,
        $lastError ?? 'raison inconnue',
    ));
}

$version = (string) ($server['version'] ?? '');
$versionComment = (string) ($server['version_comment'] ?? '');
$hostname = (string) ($server['hostname'] ?? '');
$database = (string) ($server['current_database'] ?? '');

if (stripos($version, 'mariadb') === false || preg_match('/^10\.11\./', $version) !== 1) {
    $fail(sprintf(
        'serveur « %s » (%s) détecté ; MariaDB 10.11 est requis.',
        $version !== '' ? $version : 'inconnu',
        $versionComment !== '' ? $versionComment : 'commentaire indisponible',
    ));
}

if ($expectedDatabase !== '' && $database !== $expectedDatabase) {
    $fail(sprintf(
        'base connectée « %s » différente de la base configurée « %s ».',
        $database !== '' ? $database : 'inconnue',
        $expectedDatabase,
    ));
}

fwrite(STDOUT, "Connexion MariaDB valide.\n");
fwrite(STDOUT, "  Connexion        : {$connectionName}\n");
fwrite(STDOUT, "  Pilote           : mariadb\n");
fwrite(STDOUT, "  Base de données  : {$database}\n");
fwrite(STDOUT, "  Hôte serveur     : {$hostname}\n");
fwrite(STDOUT, "  Version serveur  : {$version}\n");
fwrite(STDOUT, "  Commentaire      : {$versionComment}\n");

exit(0);
