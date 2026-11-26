<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\MariaDbTestCase;
use Tests\MySqlTestCase;
use Tests\TestCase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
|
| Les tests Feature utilisent le TestCase Laravel et une base SQLite
| réinitialisée pour chaque test.
|
*/

pest()->extend(TestCase::class)
    ->use(RefreshDatabase::class)
    ->in('Feature');

/*
|--------------------------------------------------------------------------
| MariaDB Test Case
|--------------------------------------------------------------------------
|
| La suite MariaDB est exécutée uniquement avec phpunit.mariadb.xml. Elle
| utilise une base déjà migrée et une transaction annulée après chaque test.
|
*/

pest()->extend(MariaDbTestCase::class)->in('MariaDb');

/*
|--------------------------------------------------------------------------
| MySQL Test Case
|--------------------------------------------------------------------------
|
| La suite MySQL locale utilise une base dédiée déjà migrée et une
| transaction annulée après chaque test.
|
*/

pest()->extend(MySqlTestCase::class)->in('MySql');
