<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class RbacCatalogSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RoleCatalogSeeder::class,
            PermissionCatalogSeeder::class,
        ]);
    }
}
