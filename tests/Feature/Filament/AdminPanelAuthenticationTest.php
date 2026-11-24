<?php

use App\Models\User;
use Database\Seeders\RbacCatalogSeeder;
use Filament\Auth\Notifications\ResetPassword as ResetPasswordNotification;
use Filament\Auth\Pages\Login;
use Filament\Auth\Pages\PasswordReset\RequestPasswordReset;
use Filament\Auth\Pages\PasswordReset\ResetPassword;
use Filament\Facades\Filament;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Livewire\Livewire;

beforeEach(function () {
    $this->seed(RbacCatalogSeeder::class);
});

test('configure le panel avec le guard web et le broker users et active la réinitialisation native', function () {
    $panel = Filament::getPanel('admin');

    expect($panel->getAuthGuard())->toBe('web')
        ->and($panel->getAuthPasswordBroker())->toBe('users')
        ->and($panel->hasPasswordReset())->toBeTrue()
        ->and($panel->hasRegistration())->toBeFalse();
});

test('affiche la page native de demande de réinitialisation', function () {
    $this->get('/admin/password-reset/request')
        ->assertOk();
});

test('envoie la notification native de réinitialisation à un utilisateur autorisé', function () {
    Notification::fake();

    $user = User::factory()->create();
    $user->assignRole('ADM');

    Livewire::test(RequestPasswordReset::class)
        ->fillForm(['email' => $user->email])
        ->call('request')
        ->assertHasNoFormErrors();

    Notification::assertSentTo($user, ResetPasswordNotification::class);
});

test('réinitialise le mot de passe avec un jeton valide et invalide le jeton', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $token = Password::broker('users')->createToken($user);

    Livewire::test(ResetPassword::class, [
        'email' => $user->email,
        'token' => $token,
    ])
        ->set('password', 'NewSecurePassword123!')
        ->set('passwordConfirmation', 'NewSecurePassword123!')
        ->call('resetPassword');

    $user->refresh();

    expect(Hash::check('NewSecurePassword123!', $user->password))->toBeTrue();

    $this->assertDatabaseMissing('password_reset_tokens', [
        'email' => $user->email,
    ]);
});

test('refuse un jeton de réinitialisation invalide sans modifier le mot de passe', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');
    $originalPassword = $user->password;

    Livewire::test(ResetPassword::class, [
        'email' => $user->email,
        'token' => 'invalid-reset-token',
    ])
        ->set('password', 'NewSecurePassword123!')
        ->set('passwordConfirmation', 'NewSecurePassword123!')
        ->call('resetPassword');

    expect($user->fresh()->password)->toBe($originalPassword);
});

test('renouvelle l’identifiant de session après une connexion réussie', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');
    $sessionId = session()->getId();

    Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'password',
        ])
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $this->assertAuthenticatedAs($user);
    expect(session()->getId())->not->toBe($sessionId);
});

test('limite les tentatives de connexion après cinq échecs', function () {
    $user = User::factory()->create();
    $user->assignRole('ADM');

    $component = Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'incorrect-password',
        ]);

    foreach (range(1, 5) as $attempt) {
        $component->call('authenticate')
            ->assertHasFormErrors(['data.email']);
    }

    $component->call('authenticate')
        ->assertNotified();

    $this->assertGuest();
});

test('refuse la connexion d’un utilisateur sans permission d’accès au panel', function () {
    $user = User::factory()->create();

    Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'password',
        ])
        ->call('authenticate')
        ->assertHasFormErrors(['data.email']);

    $this->assertGuest();
});

test('ne transmet pas de lien de réinitialisation à un utilisateur sans accès au panel', function () {
    Notification::fake();

    $user = User::factory()->create();

    Livewire::test(RequestPasswordReset::class)
        ->fillForm(['email' => $user->email])
        ->call('request');

    Notification::assertNotSentTo($user, ResetPasswordNotification::class);
});

test('ne réinitialise pas le mot de passe d’un utilisateur sans accès au panel', function () {
    $user = User::factory()->create();
    $originalPassword = $user->password;
    $token = Password::broker('users')->createToken($user);

    Livewire::test(ResetPassword::class, [
        'email' => $user->email,
        'token' => $token,
    ])
        ->set('password', 'NewSecurePassword123!')
        ->set('passwordConfirmation', 'NewSecurePassword123!')
        ->call('resetPassword');

    expect($user->fresh()->password)->toBe($originalPassword);
    $this->assertGuest();
});
