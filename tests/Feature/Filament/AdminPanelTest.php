<?php

use App\Models\User;
use Database\Seeders\RbacCatalogSeeder;
use Filament\Auth\Pages\Login;
use Filament\Facades\Filament;
use Livewire\Livewire;

beforeEach(function () {
    $this->seed(RbacCatalogSeeder::class);
});

test('redirige un visiteur non authentifié vers la page de connexion du panel', function () {
    $this->get('/admin')
        ->assertRedirect(route('filament.admin.auth.login'));
});

test('affiche la page de connexion du panel', function () {
    $this->get('/admin/login')
        ->assertOk();
});

test('charge les assets Filament sur la page de connexion', function () {
    $this->get('/admin/login')
        ->assertOk()
        ->assertSee('/css/filament/filament/app.css', false)
        ->assertSee('/js/filament/filament/app.js', false)
        ->assertSee('/fonts/filament/', false);

    expect(public_path('css/filament/filament/app.css'))->toBeFile()
        ->and(public_path('js/filament/filament/app.js'))->toBeFile()
        ->and(public_path('fonts/filament/filament/inter/index.css'))->toBeFile();
});

test('authentifie un utilisateur via le formulaire de connexion Filament', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'password',
        ])
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $this->assertAuthenticatedAs($user);
});

test('autorise un utilisateur disposant de la permission d’accès au panel', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');
    $user->saveAppAuthenticationSecret('test-totp-secret');

    expect($user->canAccessPanel(Filament::getPanel('admin')))->toBeTrue();

    $this->actingAs($user)
        ->get('/admin')
        ->assertOk();
});

test('déconnecte un utilisateur autorisé à accéder au panel', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $this->actingAs($user)
        ->post(route('filament.admin.auth.logout'))
        ->assertRedirect(route('filament.admin.auth.login'));

    $this->assertGuest();
});

test('redirige vers la connexion après une déconnexion', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $this->actingAs($user)
        ->post(route('filament.admin.auth.logout'));

    $this->get('/admin')
        ->assertRedirect(route('filament.admin.auth.login'));
});
