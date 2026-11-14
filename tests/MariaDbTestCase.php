<?php

namespace Tests;

use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Base des tests exécutés sur le service MariaDB 10.11 isolé de la CI.
 *
 * La suite est volontairement non destructive : elle suppose que les
 * migrations ont déjà été exécutées sur `chantier_test` et encadre chaque
 * test dans une transaction annulée à la fin. Le garde-fou refuse toute
 * exécution qui retomberait sur SQLite ou sur une autre base.
 */
abstract class MariaDbTestCase extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();

        $connection = DB::connection();

        if ($connection->getDriverName() !== 'mariadb') {
            $this->fail(sprintf(
                'Les tests MariaDB doivent utiliser le pilote « mariadb », pilote reçu : « %s ».',
                $connection->getDriverName(),
            ));
        }

        if ($connection->getDatabaseName() !== 'chantier_test') {
            $this->fail(sprintf(
                'Les tests MariaDB doivent cibler la base isolée « chantier_test », base reçue : « %s ».',
                $connection->getDatabaseName(),
            ));
        }

        if (! Schema::hasTable('migrations') || ! Schema::hasTable('users')) {
            $this->fail('La base MariaDB de test n\'est pas migrée. Exécutez php artisan migrate --force sur chantier_test.');
        }
    }
}
