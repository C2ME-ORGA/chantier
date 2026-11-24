<?php

namespace Database\Seeders;

use App\Domains\Identity\Catalog\RoleCatalog;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;

class RoleCatalogSeeder extends Seeder
{
    public function run(): void
    {
        foreach (RoleCatalog::all() as $name => $label) {
            Role::findOrCreate($name, 'web')->forceFill([
                'name' => $name,
                'guard_name' => 'web',
            ])->save();
        }
    }
}
