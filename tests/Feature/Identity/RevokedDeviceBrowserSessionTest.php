<?php

use App\\Domains\\Identity\\Actions\\RevokeUserDevice;
use App\\Models\\User;
use Database\\Seeders\\RbacCatalogSeeder;
use Illuminate\\Support\\Facades\\Auth;
use Illuminate\\Support\\Facades\\DB;

beforeEach(function (): void {
    $this->seed(RbacCatalogSeeder::class);

    config([
        'session.driver' => 'database',
        'session.connection' => null,
    ]);
});

it('rejects a previously authenticated browser session after its device is revoked', function (): void {
    $user = User::factory()->create();
    $user->assignRole('ADM');
    $user->saveAppAuthenticationSecret('test-totp-secret');

    // Exercise the real authenticated panel middleware and session lifecycle.
    $this->actingAs($user, 'web')
        ->get('/admin')
        ->assertOk();

    // TrackAuthenticatedDevice creates the browser device and AssociateDeviceWithSession
    // associates it with the persisted database session after the response is handled.
    $session = DB::table(config('session.table', 'sessions'))
        ->where('user_id', $user->getKey())
        ->whereNotNull('device_id')
        ->orderByDesc('last_activity')
        ->first();

    expect($session)->not->toBeNull();

    $sessionId = $session->id;
    $deviceId = $session->device_id;
    $device = $user->devices()->findOrFail($deviceId);

    app(RevokeUserDevice::class)->handle($user, $device);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)->exists())->toBeFalse();

    // Start a fresh guard and session store, then replay the exact browser cookie.
    // The database no longer contains the session, so Laravel must treat it as a guest.
    Auth::forgetGuards();
    app('session')->forgetDrivers();

    $this->withCookie(config('session.cookie'), $sessionId)
        ->get('/admin')
        ->assertRedirect('/admin/login');

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)->exists())->toBeFalse();
});
