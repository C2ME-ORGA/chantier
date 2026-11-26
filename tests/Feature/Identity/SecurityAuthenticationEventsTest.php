<?php

use App\Models\User;
use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use Illuminate\Support\Facades\Event;

it('journalise les connexions et déconnexions Web via les événements Laravel', function (): void {
    $user = User::factory()->create();

    Event::dispatch(new Login('web', $user, false));
    Event::dispatch(new Logout('web', $user));

    expect($user->fresh()->securityEvents()->orderBy('id')->pluck('event')->all())
        ->toBe(['login.succeeded', 'logout.succeeded'])
        ->and($user->fresh()->securityEvents()->pluck('channel')->unique()->all())
        ->toBe(['web']);
});

it('journalise un échec Web sans conserver les identifiants soumis', function (): void {
    $user = User::factory()->create();

    Event::dispatch(new Failed('web', $user, [
        'email' => $user->email,
        'password' => 'must-not-be-recorded',
    ]));

    $event = $user->fresh()->securityEvents()->sole();

    expect($event->event)->toBe('login.failed')
        ->and($event->channel)->toBe('web')
        ->and($event->context)->toBe([
            'method' => 'password_or_guard',
            'failure_code' => 'authentication_failed',
            'source' => 'laravel_auth',
        ])
        ->and(json_encode($event->context))->not->toContain('must-not-be-recorded')
        ->and(json_encode($event->context))->not->toContain($user->email);
});

it('journalise les connexions API sans enregistrer de secret de token', function (): void {
    $user = User::factory()->create();

    request()->server->set('REQUEST_URI', '/api/session');
    Event::dispatch(new Login('sanctum', $user, false));

    $event = $user->fresh()->securityEvents()->sole();

    expect($event->event)->toBe('login.succeeded')
        ->and($event->channel)->toBe('api')
        ->and($event->context)->toBe([
            'method' => 'password_or_guard',
            'source' => 'laravel_auth',
        ]);
});

it('ne duplique pas la journalisation du login Filament géré après le MFA', function (): void {
    $user = User::factory()->create();

    request()->server->set('REQUEST_URI', '/admin/login');
    Event::dispatch(new Login('web', $user, false));

    expect($user->fresh()->securityEvents()->count())->toBe(0);
});

it('journalise la création et la révocation d’un token Sanctum', function (): void {
    $user = User::factory()->create();

    $token = $user->createToken('integration-test');
    $createdEvent = $user->fresh()->securityEvents()->where('event', 'token.created')->sole();

    expect($createdEvent->channel)->toBe('api')
        ->and($createdEvent->context)->toBe([
            'source' => 'sanctum',
            'method' => 'personal_access_token',
        ]);

    $token->accessToken->delete();

    $revokedEvent = $user->fresh()->securityEvents()->where('event', 'token.revoked')->sole();

    expect($revokedEvent->channel)->toBe('api')
        ->and($revokedEvent->context)->toBe([
            'source' => 'sanctum',
            'method' => 'personal_access_token',
        ])
        ->and($revokedEvent->context)->not->toHaveKey('token');
});
