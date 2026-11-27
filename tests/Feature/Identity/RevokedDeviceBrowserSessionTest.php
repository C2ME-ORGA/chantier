<?php

use App\Domains\Identity\Actions\RevokeUserDevice;
use App\Models\User;
use Database\Seeders\RbacCatalogSeeder;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

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

    $device = $user->devices()->create([
        'uuid' => (string) Str::uuid(),
        'name' => 'Chrome desktop',
        'trusted_at' => now(),
    ]);

    // Persist a real authenticated Laravel session, as a browser would retain it.
    $session = app('session')->driver();
    $sessionId = (string) Str::uuid();
    $session->setId($sessionId);
    $session->start();

    Auth::guard('web')->login($user);

    // The session guard regenerates the ID during authentication.
    // Use the final ID that the browser will receive, not the pre-login ID.
    $sessionId = $session->getId();
    $session->save();

    DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)
        ->update([
            'user_id' => $user->getKey(),
            'device_id' => $device->getKey(),
        ]);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)
        ->value('user_id'))->toBe($user->getKey());

    app(RevokeUserDevice::class)->handle($user, $device);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)->exists())->toBeFalse();

    // Simulate a fresh HTTP request in a separate request lifecycle.
    // The session manager caches drivers, so discard the in-memory store as well
    // as the guard; otherwise the test can reuse the authenticated session state
    // even though its database row has already been deleted.
    Auth::forgetGuards();
    app('session')->forgetDrivers();

    // Reuse the exact session cookie retained by the browser after revocation.
    $this->withCookie(config('session.cookie'), $sessionId)
        ->get('/admin')
        ->assertRedirect('/admin/login');

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)->exists())->toBeFalse();
});
