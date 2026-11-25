<?php

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Domains\Identity\Models\UserSecurityEvent;
use App\Models\User;
use Illuminate\Validation\ValidationException;

test('enregistre un événement de sécurité lié à un utilisateur et un appareil', function () {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440010',
        'name' => 'Poste atelier',
    ]);

    request()->server->set('REMOTE_ADDR', '192.0.2.10');
    request()->headers->set('User-Agent', 'C2ME-Test-Agent/1.0');

    $event = app(RecordSecurityEvent::class)->handle(
        event: 'device.registered',
        channel: 'web',
        user: $user,
        device: $device,
        context: ['source' => 'login', 'password' => 'must-not-be-stored'],
    );

    expect($event)->toBeInstanceOf(UserSecurityEvent::class)
        ->and($event->user_id)->toBe($user->id)
        ->and($event->user_device_id)->toBe($device->id)
        ->and($event->event)->toBe('device.registered')
        ->and($event->channel)->toBe('web')
        ->and($event->ip_address)->toBe('192.0.2.10')
        ->and($event->user_agent)->toBe('C2ME-Test-Agent/1.0')
        ->and($event->context)->toBe(['source' => 'login'])
        ->and($event->created_at)->not->toBeNull()
        ->and($event->getUpdatedAtColumn())->toBeNull();
});

test('autorise un événement sans utilisateur identifiable', function () {
    $event = app(RecordSecurityEvent::class)->handle(
        event: 'login.failed',
        channel: 'api',
    );

    expect($event->user_id)->toBeNull()
        ->and($event->user_device_id)->toBeNull()
        ->and($event->channel)->toBe('api');
});

test('refuse un canal de sécurité inconnu', function () {
    expect(fn () => app(RecordSecurityEvent::class)->handle(
        event: 'login.succeeded',
        channel: 'mobile',
    ))->toThrow(ValidationException::class);
});

test('refuse de rattacher un appareil appartenant à un autre utilisateur', function () {
    $user = User::factory()->create();
    $otherUser = User::factory()->create();
    $device = $otherUser->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440011',
    ]);

    expect(fn () => app(RecordSecurityEvent::class)->handle(
        event: 'device.registered',
        channel: 'web',
        user: $user,
        device: $device,
    ))->toThrow(ValidationException::class);
});

test('expose les événements depuis les relations utilisateur et appareil', function () {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440012',
    ]);

    $event = app(RecordSecurityEvent::class)->handle(
        event: 'device.registered',
        channel: 'filament',
        user: $user,
        device: $device,
    );

    expect($user->securityEvents()->sole()->is($event))->toBeTrue()
        ->and($device->securityEvents()->sole()->is($event))->toBeTrue();
});

test('ne conserve que les champs de contexte autorisés et les types scalaires', function () {
    $event = app(RecordSecurityEvent::class)->handle(
        event: 'login.failed',
        channel: 'web',
        context: [
            'method' => 'password',
            'failure_code' => 'invalid_credentials',
            'source' => ['untrusted' => 'payload'],
            'mfa_method' => null,
            'password' => 'secret',
            'access_token' => 'secret-token',
        ],
    );

    expect($event->context)->toBe([
        'method' => 'password',
        'failure_code' => 'invalid_credentials',
        'mfa_method' => null,
    ]);
});

test('tronque les métadonnées textuelles aux longueurs prévues', function () {
    request()->headers->set('User-Agent', str_repeat('A', 1200));

    $event = app(RecordSecurityEvent::class)->handle(
        event: 'login.succeeded',
        channel: 'web',
        context: ['source' => str_repeat('B', 150)],
    );

    expect(mb_strlen($event->user_agent))->toBe(1000)
        ->and(mb_strlen($event->context['source']))->toBe(100);
});
