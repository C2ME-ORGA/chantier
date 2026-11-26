<?php

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Symfony\Component\Console\Input\ArgvInput;

require __DIR__.'/bootstrap-mysql.php';

$app = require dirname(__DIR__).'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$connection = DB::connection();

if ($connection->getDriverName() !== 'mysql') {
    fwrite(STDERR, sprintf(
        "ERREUR : MySQL requis, pilote reçu : %s.\n",
        $connection->getDriverName(),
    ));
    exit(1);
}

$database = $connection->getDatabaseName();

if ($database !== 'chantier_test_mysql') {
    fwrite(STDERR, sprintf(
        "ERREUR : base de test attendue « chantier_test_mysql », base reçue : « %s ». Aucune migration exécutée.\n",
        $database,
    ));
    exit(1);
}

$serverVersion = (string) DB::selectOne('SELECT VERSION() AS version')->version;

if (stripos($serverVersion, 'mariadb') !== false || ! preg_match('/^8\./', $serverVersion)) {
    fwrite(STDERR, sprintf(
        "ERREUR : MySQL 8.x requis, serveur détecté : %s. Aucune migration exécutée.\n",
        $serverVersion,
    ));
    exit(1);
}

fwrite(STDOUT, sprintf(
    "Base isolée vérifiée : %s | MySQL %s\n",
    $database,
    $serverVersion,
));

$status = $app->handleCommand(new ArgvInput([
    'artisan',
    'migrate',
    '--database=mysql',
    '--force',
    '--no-interaction',
]));

exit($status);
