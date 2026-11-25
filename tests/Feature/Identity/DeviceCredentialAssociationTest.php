<?php

use App\Domains\Identity\Models\PersonalAccessToken;
use App\Domains\Identity\Services\DeviceActivityTracker;
use App\Models\User;

test('associates a newly issued Sanctum token with the registered device cookie', function () {
    $user = User::factory()->create();
    $uuid = (string) Illuminate\Support\Str::uuid();

    $device = $user->devices()->create([
        'uuid' => $uuid,
        'name' => 'Test browser',
        'trusted_at' => now(),
        'last_seen_at' => now(),
    ]);

    request()->cookies->set(DeviceActivityTracker::COOKIE_NAME, $uuid);

    $newToken = $user->createToken('device token');

    expect($newToken->accessToken)
        ->toBeInstanceOf(PersonalAccessToken::class)
        ->and($newToken->accessToken->device_id)->toBe($device->getKey());
});

test('does not associate a Sanctum token with a revoked device', function () {
    $user = User::factory()->create();
    $uuid = (string) Illuminate\Support\Str::uuid();

    $user->devices()->create([
        'uuid' => $uuid,
        'name' => 'Revoked browser',
        'trusted_at' => now(),
        'revoked_at' => now(),
    ]);

    request()->cookies->set(DeviceActivityTracker::COOKIE_NAME, $uuid);

    $newToken = $user->createToken('unbound token');

    expect($newToken->accessToken->device_id)->toBeNull();
});
