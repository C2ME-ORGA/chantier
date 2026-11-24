<?php

namespace Database\Seeders;

use App\Domains\Identity\Catalog\RoleCatalog;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;

class RoleCatalogSeeder extends Seeder
{
    public function run(): void
    {
        foreach (array_keys(RoleCatalog::all()) as $name) {
            Role::findOrCreate($name, 'web');
        }
    }
}
