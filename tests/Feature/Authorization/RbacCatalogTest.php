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

test('le catalogue respecte les conventions atomiques et la règle DIR', function () {
    $roleNames = array_keys(RoleCatalog::all());

    foreach (PermissionCatalog::all() as $permission => $assignedRoles) {
        expect($permission)->toMatch('/^[a-z_]+\.[a-z_]+\.[a-z_]+$/')
            ->and($assignedRoles)->not->toBeEmpty();

        foreach ($assignedRoles as $roleName) {
            expect($roleNames)->toContain($roleName);
        }

        if ($permission !== 'identity.admin_panel.access') {
            expect($assignedRoles)->toContain('DIR');
        }
    }

    expect(array_keys(PermissionCatalog::all()))
        ->not->toContain('accounting.journals.view')
        ->not->toContain('bank_payments.execute');
});

test('DIR possède exactement toutes les permissions fonctionnelles du catalogue', function () {
    $direction = Role::findByName('DIR', 'web');

    $expected = collect(PermissionCatalog::all())
        ->reject(fn (array $roles, string $permission) => $permission === 'identity.admin_panel.access')
        ->keys()
        ->sort()
        ->values()
        ->all();

    $actual = $direction->permissions()
        ->where('name', '!=', 'identity.admin_panel.access')
        ->pluck('name')
        ->sort()
        ->values()
        ->all();

    expect($actual)->toBe($expected);
});

test('Sanctum authentifie un utilisateur et conserve la résolution des permissions Spatie web', function () {
    $user = User::factory()->create();
    $user->assignRole('DIR');

    $response = $this->actingAs($user, 'sanctum')
        ->getJson('/api/user');

    $response->assertOk()
        ->assertJsonPath('id', $user->id);

    expect(auth('sanctum')->user()->can('clients.reglements.validate'))->toBeTrue();
});

test('la synchronisation remplace les permissions des rôles gérés sans toucher aux autres attributions', function () {
    $permissionManuelle = Permission::findOrCreate('legacy.manual.permission', 'web');

    $administratif = Role::findByName('ADM', 'web');
    $administratif->givePermissionTo($permissionManuelle);

    $roleExterne = Role::create([
        'name' => 'EXTERNAL',
        'guard_name' => 'web',
    ]);
    $roleExterne->givePermissionTo($permissionManuelle);

    $utilisateur = User::factory()->create();
    $utilisateur->givePermissionTo($permissionManuelle);

    $this->seed(RbacCatalogSeeder::class);

    expect(Permission::query()
        ->where('name', 'legacy.manual.permission')
        ->where('guard_name', 'web')
        ->exists())->toBeTrue()
        ->and($administratif->fresh()->hasPermissionTo($permissionManuelle))->toBeFalse()
        ->and($roleExterne->fresh()->hasPermissionTo($permissionManuelle))->toBeTrue()
        ->and($utilisateur->fresh()->hasPermissionTo($permissionManuelle))->toBeTrue();
});
