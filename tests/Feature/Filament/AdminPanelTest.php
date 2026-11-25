<?php

use App\Models\User;
use Database\Seeders\RbacCatalogSeeder;
use Filament\Auth\MultiFactor\App\AppAuthentication;
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

test('requires the TOTP challenge after validating the password', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $provider = AppAuthentication::make();
    $secret = $provider->generateSecret();
    $provider->saveSecret($user, $secret);

    $component = Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'password',
        ])
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $component->assertSet('userUndertakingMultiFactorAuthentication', fn ($value) => filled($value));

    $this->assertGuest();

    $code = $provider->getCurrentCode($user, $secret);

    $component
        ->fillForm(['code' => $code], 'multiFactorChallengeForm')
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $this->assertAuthenticatedAs($user);
});


test('allows login with a one-time recovery code', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $provider = AppAuthentication::make()->recoverable();
    $provider->saveSecret($user, $provider->generateSecret());

    $recoveryCode = 'recovery-code-for-login';
    $provider->saveRecoveryCodes($user, [$recoveryCode, 'unused-recovery-code']);

    $component = Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'password',
        ])
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $this->assertGuest();

    $component
        ->fillForm([
            'useRecoveryCode' => true,
            'recoveryCode' => $recoveryCode,
        ], 'multiFactorChallengeForm')
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $this->assertAuthenticatedAs($user);
    expect($user->fresh()->getAppAuthenticationRecoveryCodes())->toHaveCount(1);
});

test('redirects an authenticated user without MFA enrollment to mandatory setup', function () {
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

    $this->get('/admin')
        ->assertRedirect(route('filament.admin.auth.multi-factor-authentication.set-up-required'));
});

test('rejects an invalid TOTP code without authenticating the user', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $provider = AppAuthentication::make();
    $secret = $provider->generateSecret();
    $provider->saveSecret($user, $secret);
    $invalidCode = str_pad((string) (((int) $provider->getCurrentCode($user, $secret) + 500000) % 1000000), 6, '0', STR_PAD_LEFT);

    Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'password',
        ])
        ->call('authenticate')
        ->assertHasNoFormErrors()
        ->fillForm(['code' => $invalidCode], 'multiFactorChallengeForm')
        ->call('authenticate')
        ->assertHasFormErrors(['data.multiFactor.code']);

    $this->assertGuest();
});

test('denies access to a user without the panel permission', function () {
    $user = User::factory()->create();

    expect($user->canAccessPanel(Filament::getPanel('admin')))->toBeFalse();
});

test('allows a user with panel permission and an enrolled MFA secret', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');
    $user->saveAppAuthenticationSecret('test-totp-secret');

    expect($user->canAccessPanel(Filament::getPanel('admin')))->toBeTrue();

    $this->actingAs($user)
        ->get('/admin')
        ->assertOk();
});

test('logs out an authorized user', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $this->actingAs($user)
        ->post(route('filament.admin.auth.logout'))
        ->assertRedirect(route('filament.admin.auth.login'));

    $this->assertGuest();
});

test('redirects to login after logout', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $this->actingAs($user)
        ->post(route('filament.admin.auth.logout'));

    $this->get('/admin')
        ->assertRedirect(route('filament.admin.auth.login'));
});
