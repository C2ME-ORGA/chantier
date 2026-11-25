<?php

namespace Tests;

use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Base des tests exécutés sur MySQL 8.x local.
 *
 * La suite est volontairement non destructive : elle suppose que les
 * migrations ont déjà été exécutées sur `chantier_test_mysql` et encadre
 * chaque test dans une transaction annulée à la fin. Le garde-fou refuse
 * toute exécution sur un autre moteur ou une autre base.
 */
abstract class MySqlTestCase extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();

        $connection = DB::connection();

        if ($connection->getDriverName() !== 'mysql') {
            $this->fail(sprintf(
                'Les tests MySQL doivent utiliser le pilote « mysql », pilote reçu : « %s ».',
                $connection->getDriverName(),
            ));
        }

        if ($connection->getDatabaseName() !== 'chantier_test_mysql') {
            $this->fail(sprintf(
                'Les tests MySQL doivent cibler la base isolée « chantier_test_mysql », base reçue : « %s ».',
                $connection->getDatabaseName(),
            ));
        }

        if (! Schema::hasTable('migrations') || ! Schema::hasTable('users')) {
            $this->fail('La base MySQL de test n\'est pas migrée. Exécutez les migrations sur chantier_test_mysql.');
        }
    }
}
