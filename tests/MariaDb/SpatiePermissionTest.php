<?php

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

test('applique le schéma Spatie sur MariaDB', function () {
    $tables = [
        'permissions',
        'roles',
        'model_has_permissions',
        'model_has_roles',
        'role_has_permissions',
    ];

    foreach ($tables as $table) {
        expect(Schema::hasTable($table))->toBeTrue("Table absente : {$table}");
    }

    expect(Schema::hasColumn('permissions', 'name'))->toBeTrue()
        ->and(Schema::hasColumn('permissions', 'guard_name'))->toBeTrue()
        ->and(Schema::hasColumn('roles', 'name'))->toBeTrue()
        ->and(Schema::hasColumn('roles', 'guard_name'))->toBeTrue()
        ->and(Schema::hasColumn('model_has_permissions', 'model_type'))->toBeTrue()
        ->and(Schema::hasColumn('model_has_roles', 'model_type'))->toBeTrue()
        ->and(Schema::hasColumn('role_has_permissions', 'role_id'))->toBeTrue()
        ->and(Schema::hasColumn('roles', 'team_id'))->toBeFalse()
        ->and(Schema::hasColumn('model_has_roles', 'team_id'))->toBeFalse()
        ->and(Schema::hasColumn('model_has_permissions', 'team_id'))->toBeFalse();
});

test('gère les rôles et permissions sur MariaDB', function () {
    $permission = Permission::create(['name' => 'mariadb.chantiers.consulter']);
    $role = Role::create(['name' => 'mariadb-conducteur']);
    $role->givePermissionTo($permission);

    $user = User::factory()->create();
    $user->assignRole($role);

    expect($user->hasPermissionTo('mariadb.chantiers.consulter'))->toBeTrue();

    $role->delete();

    expect($user->fresh()?->hasRole('mariadb-conducteur'))->toBeFalse()
        ->and(DB::table('model_has_roles')->where('role_id', $role->getKey())->count())->toBe(0);
});
