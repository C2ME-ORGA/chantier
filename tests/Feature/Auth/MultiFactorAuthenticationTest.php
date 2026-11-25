<?php

use App\Models\User;
use Filament\Auth\MultiFactor\App\AppAuthentication;
use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthentication;
use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthenticationRecovery;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Hash;

it('supports Filament app authentication and recovery codes', function (): void {
    $user = new User;

    expect($user)
        ->toBeInstanceOf(HasAppAuthentication::class)
        ->toBeInstanceOf(HasAppAuthenticationRecovery::class);
});

it('encrypts the TOTP secret and recovery codes at rest', function (): void {
    $user = User::factory()->create();

    $secret = 'totp-secret-value';
    $recoveryCodes = ['recovery-code-one', 'recovery-code-two'];

    $user->forceFill([
        'app_authentication_secret' => $secret,
        'app_authentication_recovery_codes' => $recoveryCodes,
    ])->save();

    $raw = $user->getRawOriginal();

    expect($raw['app_authentication_secret'])
        ->not->toBe($secret)
        ->and(Crypt::decryptString($raw['app_authentication_secret']))
        ->toBe($secret)
        ->and($raw['app_authentication_recovery_codes'])
        ->not->toContain('recovery-code-one')
        ->and($user->fresh()->app_authentication_secret)
        ->toBe($secret)
        ->and($user->fresh()->app_authentication_recovery_codes)
        ->toBe($recoveryCodes);
});

it('does not expose MFA secrets when serializing a user', function (): void {
    $user = User::factory()->create();

    $user->forceFill([
        'app_authentication_secret' => 'totp-secret-value',
        'app_authentication_recovery_codes' => ['recovery-code-one'],
    ]);

    expect($user->toArray())
        ->not->toHaveKey('app_authentication_secret')
        ->not->toHaveKey('app_authentication_recovery_codes');
});

it('consumes each recovery code exactly once while preserving other codes', function (): void {
    $user = User::factory()->create();
    $provider = AppAuthentication::make()->recoverable();

    $recoveryCode = 'one-time-recovery-code';
    $remainingCode = 'another-recovery-code';

    $provider->saveRecoveryCodes($user, [$recoveryCode, $remainingCode]);

    expect($provider->verifyRecoveryCode($recoveryCode, $user))->toBeTrue()
        ->and($provider->verifyRecoveryCode($recoveryCode, $user))->toBeFalse()
        ->and($user->fresh()->getAppAuthenticationRecoveryCodes())->toHaveCount(1)
        ->and(Hash::check($remainingCode, $user->fresh()->getAppAuthenticationRecoveryCodes()[0]))->toBeTrue();
});
