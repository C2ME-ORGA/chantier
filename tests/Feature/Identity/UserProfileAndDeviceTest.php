<?php

use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Models\UserProfile;
use App\Models\User;
use DateTimeInterface;
use Illuminate\Database\QueryException;

test('associe un profil unique à un utilisateur', function () {
    $user = User::factory()->create();

    $profile = $user->profile()->create([
        'first_name' => 'Camille',
        'last_name' => 'Martin',
        'phone' => '0600000000',
        'job_title' => 'Conducteur de travaux',
    ]);

    expect($profile)->toBeInstanceOf(UserProfile::class)
        ->and($profile->user->is($user))->toBeTrue()
        ->and($user->fresh()->profile->is($profile))->toBeTrue();

    expect(fn () => UserProfile::create(['user_id' => $user->id]))
        ->toThrow(QueryException::class);
});

test('associe plusieurs appareils à un utilisateur et caste les dates', function () {
    $user = User::factory()->create();

    $device = $user->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440000',
        'name' => 'Poste atelier',
        'platform' => 'Windows',
        'device_type' => 'computer',
        'last_seen_at' => '2026-11-24 10:00:00',
        'trusted_at' => '2026-11-24 10:00:00',
    ]);

    expect($device)->toBeInstanceOf(UserDevice::class)
        ->and($device->user->is($user))->toBeTrue()
        ->and($user->fresh()->devices)->toHaveCount(1)
        ->and($device->last_seen_at)->toBeInstanceOf(DateTimeInterface::class)
        ->and($device->trusted_at)->toBeInstanceOf(DateTimeInterface::class);
});

test('impose un UUID unique pour les appareils', function () {
    $user = User::factory()->create();
    $attributes = [
        'uuid' => '550e8400-e29b-41d4-a716-446655440001',
        'name' => 'Mobile',
    ];

    $user->devices()->create($attributes);

    expect(fn () => $user->devices()->create($attributes))
        ->toThrow(QueryException::class);
});

test('supprime les profils et appareils avec leur utilisateur', function () {
    $user = User::factory()->create();
    $user->profile()->create(['first_name' => 'Alex']);
    $user->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440002',
    ]);

    $user->delete();

    $this->assertDatabaseMissing('user_profiles', ['user_id' => $user->id]);
    $this->assertDatabaseMissing('user_devices', ['user_id' => $user->id]);
});
