<?php

namespace Database\Seeders;

use App\Domains\Identity\Catalog\PermissionCatalog;
use App\Domains\Identity\Catalog\RoleCatalog;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

class PermissionCatalogSeeder extends Seeder
{
    public function run(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $catalog = PermissionCatalog::all();

        foreach (array_keys($catalog) as $name) {
            Permission::findOrCreate($name, 'web');
        }

        $permissions = Permission::query()
            ->where('guard_name', 'web')
            ->whereIn('name', array_keys($catalog))
            ->get()
            ->keyBy('name');

        foreach (array_keys(RoleCatalog::all()) as $roleName) {
            $role = Role::findByName($roleName, 'web');
            $permissionNames = collect($catalog)
                ->filter(fn (array $roleNames) => in_array($roleName, $roleNames, true))
                ->keys()
                ->all();

            $role->syncPermissions(
                collect($permissionNames)
                    ->map(fn (string $name) => $permissions->get($name))
                    ->filter()
                    ->values()
                    ->all(),
            );
        }

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }
}
