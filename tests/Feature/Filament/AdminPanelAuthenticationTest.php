<?php

use App\\Models\\User;
use Database\\Seeders\\RbacCatalogSeeder;
use Filament\\Auth\\Notifications\\ResetPassword as ResetPasswordNotification;
use Filament\\Auth\\Pages\\PasswordReset\\RequestPasswordReset;
use Filament\\Auth\\Pages\\PasswordReset\\ResetPassword;
use Filament\\Facades\\Filament;
use Illuminate\\Support\\Facades\\Hash;
use Illuminate\\Support\\Facades\\Notification;
use Illuminate\\Support\\Facades\\Password;
use Livewire\\Livewire;

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
