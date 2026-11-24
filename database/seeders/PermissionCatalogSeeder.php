<?php

namespace Database\Seeders;

use App\Domains\Identity\Catalog\PermissionCatalog;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

class PermissionCatalogSeeder extends Seeder
{
    public function run(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $roles = Role::query()
            ->where('guard_name', 'web')
            ->get()
            ->keyBy('name');

        foreach (PermissionCatalog::all() as $name => $roleNames) {
            $permission = Permission::findOrCreate($name, 'web');
            $permission->syncRoles(
                collect($roleNames)
                    ->map(fn (string $roleName) => $roles->get($roleName))
                    ->filter()
                    ->values()
                    ->all(),
            );
        }

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }
}
