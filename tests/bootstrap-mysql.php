<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Bootstrap de la suite MySQL
|--------------------------------------------------------------------------
|
| PHPUnit applique <env force="true"> à $_ENV et à putenv(), mais une variable
| déjà présente dans $_SERVER reste prioritaire pour le dépôt Env de Laravel.
| Ce bootstrap force donc la connexion MySQL avant le démarrage de
| l'application, quel que soit l'environnement appelant.
|
*/

$forcedVariables = [
    'APP_ENV' => 'testing',
    'DB_CONNECTION' => 'mysql',
    'DB_DATABASE' => 'chantier_test_mysql',
    'DB_URL' => '',
];

foreach ($forcedVariables as $name => $value) {
    putenv("{$name}={$value}");
    $_ENV[$name] = $value;
    $_SERVER[$name] = $value;
}

require dirname(__DIR__).'/vendor/autoload.php';
