<?php

use App\Domains\Identity\Services\DeviceActivityTracker;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Support\Str;

test('crée et approuve un appareil avec un UUID applicatif lorsque le cookie est absent', function () {
    $user = User::factory()->create();

    $request = Request::create('/');
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

    $request = Request::create('/', 'GET', [], [
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

    $request = Request::create('/', 'GET', [], [
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

    $request = Request::create('/', 'GET', [], [
        DeviceActivityTracker::COOKIE_NAME => $uuid,
    ]);

    app(DeviceActivityTracker::class)->track($request, $user);

    expect($user->devices()->count())->toBe(1)
        ->and($user->securityEvents()->where('event', 'device.registered')->count())->toBe(0);
});

test('renouvelle le cookie lorsqu’un appareil est révoqué sans réactiver l’ancien', function () {
    $user = User::factory()->create();
    $revokedUuid = (string) Str::uuid();

    $revokedDevice = $user->devices()->create([
        'uuid' => $revokedUuid,
        'revoked_at' => now(),
    ]);

    $request = Request::create('/', 'GET', [], [
        DeviceActivityTracker::COOKIE_NAME => $revokedUuid,
    ]);

    app(DeviceActivityTracker::class)->track($request, $user);

    $devices = $user->devices()->orderBy('id')->get();
    $newDevice = $devices->sole('id', '!=', $revokedDevice->getKey());

    expect($devices)->toHaveCount(2)
        ->and($revokedDevice->fresh()->revoked_at)->not->toBeNull()
        ->and($newDevice->uuid)->not->toBe($revokedUuid)
        ->and(Str::isUuid($newDevice->uuid))->toBeTrue()
        ->and($newDevice->trusted_at)->not->toBeNull()
        ->and($user->securityEvents()->where('event', 'device.registered')->count())->toBe(1)
        ->and(Cookie::queued(DeviceActivityTracker::COOKIE_NAME)?->getValue())->toBe($newDevice->uuid);
});
