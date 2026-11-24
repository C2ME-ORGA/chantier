<?php

use App\Domains\Identity\Catalog\PermissionCatalog;
use App\Domains\Identity\Catalog\RoleCatalog;
use App\Models\User;
use Database\Seeders\RbacCatalogSeeder;
use Filament\Panel;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

beforeEach(function () {
    $this->seed(RbacCatalogSeeder::class);
});

test('le catalogue crée les huit rôles avec le guard web', function () {
    expect(Role::query()->where('guard_name', 'web')->count())
        ->toBe(count(RoleCatalog::all()));

    foreach (array_keys(RoleCatalog::all()) as $roleName) {
        expect(Role::query()
            ->where('name', $roleName)
            ->where('guard_name', 'web')
            ->exists())->toBeTrue();
    }
});

test('le catalogue crée uniquement les permissions définies', function () {
    expect(Permission::query()->where('guard_name', 'web')->count())
        ->toBe(count(PermissionCatalog::all()));

    expect(Permission::query()
        ->where('name', 'identity.admin_panel.access')
        ->where('guard_name', 'web')
        ->exists())->toBeTrue();

    expect(Permission::query()
        ->where('name', 'clients.factures_clients.issue')
        ->exists())->toBeTrue();
});

test('les associations de rôles suivent le catalogue explicite', function () {
    $direction = Role::findByName('DIR', 'web');
    $administratif = Role::findByName('ADM', 'web');
    $gestionnaire = Role::findByName('GAF', 'web');
    $salarie = Role::findByName('SAL', 'web');

    expect($direction->hasPermissionTo('clients.reglements.validate'))->toBeTrue()
        ->and($administratif->hasPermissionTo('clients.reglements.validate'))->toBeFalse()
        ->and($gestionnaire->hasPermissionTo('clients.factures_clients.issue'))->toBeTrue()
        ->and($salarie->hasPermissionTo('identity.admin_panel.access'))->toBeFalse();
});

test('le seeder est réexécutable sans créer de doublons', function () {
    $expectedRoles = count(RoleCatalog::all());
    $expectedPermissions = count(PermissionCatalog::all());

    $this->seed(RbacCatalogSeeder::class);
    $this->seed(RbacCatalogSeeder::class);

    expect(Role::query()->where('guard_name', 'web')->count())->toBe($expectedRoles)
        ->and(Permission::query()->where('guard_name', 'web')->count())->toBe($expectedPermissions);
});

test('aucun rôle n’est attribué automatiquement à un utilisateur existant', function () {
    $user = User::factory()->create();

    expect($user->roles)->toBeEmpty();
});

test('le panel est réservé aux rôles disposant de la permission dédiée', function () {
    $panel = Mockery::mock(Panel::class);

    $administratif = User::factory()->create();
    $administratif->assignRole('ADM');

    $salarie = User::factory()->create();
    $salarie->assignRole('SAL');

    $sansRole = User::factory()->create();

    expect($administratif->canAccessPanel($panel))->toBeTrue()
        ->and($salarie->canAccessPanel($panel))->toBeFalse()
        ->and($sansRole->canAccessPanel($panel))->toBeFalse();
});
