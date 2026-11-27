<?php

use App\Domains\Identity\Actions\RevokeUserDevice;
use App\Models\User;
use Database\Seeders\RbacCatalogSeeder;
use Filament\Auth\MultiFactor\App\AppAuthentication;
use Filament\Auth\Pages\Login;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;

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

    $provider = AppAuthentication::make();
    $secret = $provider->generateSecret();
    $provider->saveSecret($user, $secret);

    // Authenticate through Filament's real password + MFA flow so the browser
    // receives a genuine Laravel session containing the authenticated user.
    $component = Livewire::test(Login::class)
        ->fillForm([
            'email' => $user->email,
            'password' => 'password',
        ])
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $component
        ->fillForm(['app' => ['code' => $provider->getCurrentCode($user, $secret)]], 'multiFactorChallengeForm')
        ->call('authenticate')
        ->assertHasNoFormErrors();

    $this->assertAuthenticatedAs($user, 'web');

    // The next authenticated panel request tracks the device and associates
    // its persisted database session in the RequestHandled listener.
    $this->get('/admin')->assertOk();

    $session = DB::table(config('session.table', 'sessions'))
        ->where('user_id', $user->getKey())
        ->whereNotNull('device_id')
        ->orderByDesc('last_activity')
        ->first();

    expect($session)->not->toBeNull();

    $sessionId = $session->id;
    $device = $user->devices()->findOrFail($session->device_id);

    app(RevokeUserDevice::class)->handle($user, $device);

    expect(DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)->exists())->toBeFalse();

    // Start a fresh guard and session store, then replay the exact browser cookie.
    Auth::forgetGuards();
    app('session')->forgetDrivers();

    $this->withCookie(config('session.cookie'), $sessionId)
        ->get('/admin')
        ->assertRedirect('/admin/login');

    // Laravel may persist a new anonymous session row while handling the
    // deleted session cookie. The security requirement is that the replayed
    // session cannot restore the user or the revoked device association.
    $replayedSession = DB::table(config('session.table', 'sessions'))
        ->where('id', $sessionId)
        ->first();

    expect($replayedSession?->user_id)->toBeNull()
        ->and($replayedSession?->device_id)->toBeNull();
});
