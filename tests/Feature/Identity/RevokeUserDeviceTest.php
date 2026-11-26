<?php

use App\Domains\Identity\Actions\RevokeUserDevice;
use App\Domains\Identity\Models\UserSecurityEvent;
use App\Domains\Identity\Notifications\DeviceRevokedNotification;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

beforeEach(function (): void {
    config(['session.driver' => 'array']);
});

test('revokes a device, its tokens and records a notification and security event', function (): void {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => (string) Str::uuid(),
        'name' => 'Chrome desktop',
        'trusted_at' => now(),
    ]);

    $token = $user->createToken('test token')->accessToken;
    $token->forceFill(['device_id' => $device->getKey()])->save();

    app(RevokeUserDevice::class)->handle($user, $device);

    expect($device->fresh()->revoked_at)->not->toBeNull()
        ->and($user->tokens()->whereKey($token->getKey())->exists())->toBeFalse()
        ->and(UserSecurityEvent::query()->where('event', 'device.revoked')->count())->toBe(1)
        ->and(UserSecurityEvent::query()->where('event', 'token.revoked')->count())->toBe(1)
        ->and($user->notifications()->where('type', DeviceRevokedNotification::class)->count())->toBe(1);
});

test('refuses to revoke another users device', function (): void {
    $owner = User::factory()->create();
    $actor = User::factory()->create();
    $device = $owner->devices()->create(['uuid' => (string) Str::uuid()]);

    expect(fn () => app(RevokeUserDevice::class)->handle($actor, $device))
        ->toThrow(AuthorizationException::class);

    expect($device->fresh()->revoked_at)->toBeNull()
        ->and($owner->notifications()->count())->toBe(0)
        ->and(UserSecurityEvent::query()->count())->toBe(0);
});

test('repeated revocation is idempotent and does not duplicate records', function (): void {
    $user = User::factory()->create();
    $device = $user->devices()->create(['uuid' => (string) Str::uuid()]);

    app(RevokeUserDevice::class)->handle($user, $device);
    app(RevokeUserDevice::class)->handle($user, $device->fresh());

    expect(UserSecurityEvent::query()->where('event', 'device.revoked')->count())->toBe(1)
        ->and($user->notifications()->where('type', DeviceRevokedNotification::class)->count())->toBe(1);
});

test('deletes every database session associated with the revoked device', function (): void {
    config(['session.driver' => 'database']);

    $user = User::factory()->create();
    $device = $user->devices()->create(['uuid' => (string) Str::uuid()]);

    DB::table(config('session.table', 'sessions'))->insert([
        'id' => (string) Str::uuid(),
        'user_id' => $user->getKey(),
        'device_id' => $device->getKey(),
        'ip_address' => '127.0.0.1',
        'user_agent' => 'Pest',
        'payload' => '',
        'last_activity' => now()->timestamp,
    ]);

    app(RevokeUserDevice::class)->handle($user, $device);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('device_id', $device->getKey())->exists())->toBeFalse();
});

test('rejects API access when the bearer token belongs to a revoked device', function (): void {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => (string) Str::uuid(),
        'trusted_at' => now(),
        'revoked_at' => now(),
    ]);

    $newToken = $user->createToken('revoked device token');
    $newToken->accessToken->forceFill(['device_id' => $device->getKey()])->save();

    $this->withToken($newToken->plainTextToken)
        ->getJson('/api/user')
        ->assertUnauthorized();
});
