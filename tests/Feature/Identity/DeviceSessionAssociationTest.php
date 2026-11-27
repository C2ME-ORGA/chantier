<?php

use App\Domains\Identity\Listeners\AssociateDeviceWithSession;
use App\Models\User;
use Illuminate\Foundation\Http\Events\RequestHandled;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

test('persists the device association after the database session has been saved', function (): void {
    config(['session.driver' => 'database', 'session.connection' => null]);

    $user = User::factory()->create();
    $device = $user->devices()->create(['uuid' => (string) Str::uuid()]);
    $sessionId = (string) Str::uuid();

    DB::table(config('session.table', 'sessions'))->insert([
        'id' => $sessionId,
        'user_id' => $user->getKey(),
        'ip_address' => '127.0.0.1',
        'user_agent' => 'Pest',
        'payload' => '',
        'last_activity' => now()->timestamp,
    ]);

    $request = Request::create('/');
    $request->attributes->set('identity.session_device', [
        'device_id' => (int) $device->getKey(),
        'user_id' => (int) $user->getKey(),
        'session_id' => $sessionId,
    ]);

    $event = new RequestHandled(app(\Illuminate\Contracts\Http\Kernel::class), $request, new Response());
    app(AssociateDeviceWithSession::class)->handle($event);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)
        ->value('device_id'))->toBe($device->getKey());
});

test('does not attempt database association when the session driver is not database', function (): void {
    config(['session.driver' => 'array']);

    $request = Request::create('/');
    $request->attributes->set('identity.session_device', [
        'device_id' => 1,
        'user_id' => 1,
        'session_id' => (string) Str::uuid(),
    ]);

    $event = new RequestHandled(app(\Illuminate\Contracts\Http\Kernel::class), $request, new Response());

    expect(fn () => app(AssociateDeviceWithSession::class)->handle($event))
        ->not->toThrow(Throwable::class);
});
