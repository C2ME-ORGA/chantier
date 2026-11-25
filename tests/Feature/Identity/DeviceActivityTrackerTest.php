<?php

use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Services\DeviceActivityTracker;
use App\Models\User;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Support\Str;

beforeEach(function () {
    Cookie::queue([]);
});

test('crée et approuve un appareil avec un UUID applicatif lorsque le cookie est absent', function () {
    $user = User::factory()->create();

    $request = request()->create('/', 'GET');
    $request->headers->set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');

    app(DeviceActivityTracker::class)->track($request, $user);

    $device = $user->devices()->sole();

    expect($device->uuid)->toBeString()
        ->and(Str::isUuid($device->uuid))->toBeTrue()
        ->and($device->trusted_at)->not->toBeNull()
        ->and($device->last_seen_at)->not->toBeNull()
        ->and($device->platform)->toBe('Windows')
        ->and($device->device_type)->toBe('browser');

    expect($user->securityEvents()->where('event', 'device.registered')->count())->toBe(1);
});

test('réutilise le cookie valide appartenant au même utilisateur', function () {
    $user = User::factory()->create();
    $uuid = (string) Str::uuid();

    $request = request()->create('/', 'GET', cookies: [
        DeviceActivityTracker::COOKIE_NAME => $uuid,
    ]);

    app(DeviceActivityTracker::class)->track($request, $user);

    expect($user->devices()->sole()->uuid)->toBe($uuid)
        ->and($user->securityEvents()->where('event', 'device.registered')->count())->toBe(1);
});

test('fait tourner un UUID déjà associé à un autre utilisateur', function () {
    $owner = User::factory()->create();
    $currentUser = User::factory()->create();
    $uuid = (string) Str::uuid();

    $owner->devices()->create(['uuid' => $uuid]);

    $request = request()->create('/', 'GET', cookies: [
        DeviceActivityTracker::COOKIE_NAME => $uuid,
    ]);

    app(DeviceActivityTracker::class)->track($request, $currentUser);

    $newDevice = $currentUser->devices()->sole();

    expect($newDevice->uuid)->not->toBe($uuid)
        ->and(Str::isUuid($newDevice->uuid))->toBeTrue()
        ->and($owner->devices()->sole()->uuid)->toBe($uuid)
        ->and($currentUser->securityEvents()->where('event', 'device.registered')->count())->toBe(1);
});

test('ne crée pas un second événement lors du suivi d’un appareil déjà enregistré', function () {
    $user = User::factory()->create();
    $uuid = (string) Str::uuid();

    $user->devices()->create([
        'uuid' => $uuid,
        'trusted_at' => now()->subDay(),
    ]);

    $request = request()->create('/', 'GET', cookies: [
        DeviceActivityTracker::COOKIE_NAME => $uuid,
    ]);

    app(DeviceActivityTracker::class)->track($request, $user);

    expect($user->devices()->count())->toBe(1)
        ->and($user->securityEvents()->where('event', 'device.registered')->count())->toBe(0);
});

test('refuse de réactiver un appareil révoqué', function () {
    $user = User::factory()->create();
    $uuid = (string) Str::uuid();

    $user->devices()->create([
        'uuid' => $uuid,
        'revoked_at' => now(),
    ]);

    $request = request()->create('/', 'GET', cookies: [
        DeviceActivityTracker::COOKIE_NAME => $uuid,
    ]);

    expect(fn () => app(DeviceActivityTracker::class)->track($request, $user))
        ->toThrow(\Illuminate\Auth\Access\AuthorizationException::class);

    expect($user->devices()->sole()->revoked_at)->not->toBeNull();
});
