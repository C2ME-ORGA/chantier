<?php

use App\Domains\Identity\Actions\RegisterUserDevice;
use App\Domains\Identity\Models\UserDevice;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Validation\ValidationException;

test('enregistre automatiquement un nouvel appareil approuvé', function () {
    $user = User::factory()->create();

    $result = app(RegisterUserDevice::class)->handle(
        $user,
        '550e8400-e29b-41d4-a716-446655440020',
        ['name' => 'Navigateur web', 'platform' => 'Windows', 'device_type' => 'browser'],
    );

    expect($result['created'])->toBeTrue()
        ->and($result['device'])->toBeInstanceOf(UserDevice::class)
        ->and($result['device']->user_id)->toBe($user->id)
        ->and($result['device']->trusted_at)->not->toBeNull()
        ->and($result['device']->last_seen_at)->not->toBeNull()
        ->and($result['device']->platform)->toBe('Windows');
});

test('réutilise un appareil existant et actualise sa dernière activité', function () {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440021',
        'last_seen_at' => now()->subDay(),
    ]);

    $result = app(RegisterUserDevice::class)->handle($user, $device->uuid);

    expect($result['created'])->toBeFalse()
        ->and($result['device']->is($device))->toBeTrue()
        ->and($result['device']->last_seen_at->greaterThan(now()->subDay()))->toBeTrue();
});

test('refuse un identifiant invalide', function () {
    $user = User::factory()->create();

    expect(fn () => app(RegisterUserDevice::class)->handle($user, 'not-a-uuid'))
        ->toThrow(ValidationException::class);
});

test('refuse un identifiant déjà associé à un autre utilisateur', function () {
    $user = User::factory()->create();
    $otherUser = User::factory()->create();
    $otherUser->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440022',
    ]);

    expect(fn () => app(RegisterUserDevice::class)->handle(
        $user,
        '550e8400-e29b-41d4-a716-446655440022',
    ))->toThrow(ValidationException::class);
});

test('bloque un appareil révoqué', function () {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440023',
        'revoked_at' => now(),
    ]);

    expect(fn () => app(RegisterUserDevice::class)->handle($user, $device->uuid))
        ->toThrow(AuthorizationException::class);
});
