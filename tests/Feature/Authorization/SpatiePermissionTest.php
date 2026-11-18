<?php

use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Exceptions\GuardDoesNotMatch;
use Spatie\Permission\Guard;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

test('crée une permission avec le guard web par défaut', function () {
    $permission = Permission::create(['name' => 'chantiers.consulter']);

    expect($permission->exists)->toBeTrue()
        ->and($permission->guard_name)->toBe('web')
        ->and(Permission::findByName('chantiers.consulter')->getKey())->toBe($permission->getKey());

    $this->assertDatabaseHas('permissions', [
        'name' => 'chantiers.consulter',
        'guard_name' => 'web',
    ]);
});

test('crée un rôle avec le guard web par défaut', function () {
    $role = Role::create(['name' => 'conducteur']);

    expect($role->exists)->toBeTrue()
        ->and($role->guard_name)->toBe('web');

    $this->assertDatabaseHas('roles', [
        'name' => 'conducteur',
        'guard_name' => 'web',
    ]);
});

test('attribue un rôle à un utilisateur', function () {
    $user = User::factory()->create();
    $role = Role::create(['name' => 'conducteur']);

    $user->assignRole($role);

    expect($user->hasRole('conducteur'))->toBeTrue()
        ->and($user->fresh()?->hasRole('conducteur'))->toBeTrue();

    $this->assertDatabaseHas('model_has_roles', [
        'role_id' => $role->getKey(),
        'model_id' => $user->getKey(),
        'model_type' => User::class,
    ]);
});

test('accorde une permission héritée d un rôle', function () {
    $permission = Permission::create(['name' => 'chantiers.consulter']);
    $role = Role::create(['name' => 'conducteur']);
    $role->givePermissionTo($permission);

    $user = User::factory()->create();
    $user->assignRole($role);

    expect($user->hasPermissionTo('chantiers.consulter'))->toBeTrue()
        ->and($user->hasDirectPermission('chantiers.consulter'))->toBeFalse()
        ->and($user->getPermissionsViaRoles()->pluck('name'))->toContain('chantiers.consulter');
});

test('accorde directement une permission à un utilisateur', function () {
    $permission = Permission::create(['name' => 'chantiers.consulter']);
    $user = User::factory()->create();

    $user->givePermissionTo($permission);

    expect($user->hasDirectPermission('chantiers.consulter'))->toBeTrue()
        ->and($user->hasPermissionTo('chantiers.consulter'))->toBeTrue();

    $this->assertDatabaseHas('model_has_permissions', [
        'permission_id' => $permission->getKey(),
        'model_id' => $user->getKey(),
        'model_type' => User::class,
    ]);
});

test('supprime les relations lorsqu une permission directe est supprimée', function () {
    $permission = Permission::create(['name' => 'chantiers.consulter']);
    $user = User::factory()->create();
    $user->givePermissionTo($permission);

    $this->assertDatabaseHas('model_has_permissions', [
        'permission_id' => $permission->getKey(),
        'model_id' => $user->getKey(),
        'model_type' => User::class,
    ]);

    $permission->delete();

    expect($user->fresh()?->permissions)->toHaveCount(0);

    $this->assertDatabaseMissing('model_has_permissions', [
        'permission_id' => $permission->getKey(),
    ]);
});

test('refuse une permission non attribuée à l utilisateur', function () {
    Permission::create(['name' => 'chantiers.consulter']);
    Permission::create(['name' => 'chantiers.supprimer']);

    $user = User::factory()->create();
    $user->givePermissionTo('chantiers.consulter');

    expect($user->hasPermissionTo('chantiers.supprimer'))->toBeFalse()
        ->and($user->checkPermissionTo('chantiers.supprimer'))->toBeFalse();
});

test('utilise le guard web pour les vérifications explicites', function () {
    $permission = Permission::create(['name' => 'chantiers.consulter']);
    $role = Role::create(['name' => 'conducteur']);
    $role->givePermissionTo($permission);

    $user = User::factory()->create();
    $user->assignRole($role);

    expect(Guard::getDefaultName(User::class))->toBe('web')
        ->and($user->hasRole('conducteur', 'web'))->toBeTrue()
        ->and($user->hasPermissionTo('chantiers.consulter', 'web'))->toBeTrue();
});

test('refuse d attribuer un rôle provenant d un guard incompatible', function () {
    $role = Role::create([
        'name' => 'role-api',
        'guard_name' => 'api',
    ]);

    $user = User::factory()->create();

    expect(fn () => $user->assignRole($role))->toThrow(GuardDoesNotMatch::class);
});

test('supprime les relations lorsqu un rôle est supprimé', function () {
    $permission = Permission::create(['name' => 'chantiers.consulter']);
    $role = Role::create(['name' => 'conducteur']);
    $role->givePermissionTo($permission);

    $user = User::factory()->create();
    $user->assignRole($role);

    $role->delete();

    expect($user->fresh()?->hasRole('conducteur'))->toBeFalse();

    $this->assertDatabaseMissing('model_has_roles', [
        'role_id' => $role->getKey(),
    ]);

    $this->assertDatabaseMissing('role_has_permissions', [
        'role_id' => $role->getKey(),
    ]);
});

test('invalide le cache après la création et la suppression d une permission', function () {
    $registrar = app(PermissionRegistrar::class);
    $registrar->forgetCachedPermissions();
    $registrar->getPermissions();

    expect(Cache::has(config('permission.cache.key')))->toBeTrue();

    $permission = Permission::create(['name' => 'chantiers.consulter']);

    expect(Cache::has(config('permission.cache.key')))->toBeFalse()
        ->and($registrar->getPermissions()->pluck('name'))->toContain('chantiers.consulter');

    $permission->delete();

    expect(Cache::has(config('permission.cache.key')))->toBeFalse()
        ->and($registrar->getPermissions()->pluck('name'))->not->toContain('chantiers.consulter');
});

test('désactive le mode Teams et ses colonnes de périmètre', function () {
    expect(config('permission.teams'))->toBeFalse()
        ->and(Schema::hasColumn('roles', 'team_id'))->toBeFalse()
        ->and(Schema::hasColumn('model_has_roles', 'team_id'))->toBeFalse()
        ->and(Schema::hasColumn('model_has_permissions', 'team_id'))->toBeFalse();
});

test('conserve les tables de permissions attendues', function () {
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

    expect(DB::table('permissions')->count())->toBe(0);
});
