<?php

use App\Domains\Identity\Actions\RevokeUserDevice;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

beforeEach(function (): void {
    config([
        'session.driver' => 'database',
        'session.connection' => null,
    ]);
});

it('rejects a previously authenticated browser session after its device is revoked', function (): void {
    $user = User::factory()->create();
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
    $session->save();

    DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)
        ->update(['device_id' => $device->getKey()]);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)
        ->value('user_id'))->toBe($user->getKey());

    app(RevokeUserDevice::class)->handle($user, $device);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)->exists())->toBeFalse();

    // Reuse the exact session cookie retained by the browser after revocation.
    Auth::forgetGuards();

    $this->withCookie(config('session.cookie'), $sessionId)
        ->get('/admin')
        ->assertRedirect('/admin/login');

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)->exists())->toBeFalse();
});
