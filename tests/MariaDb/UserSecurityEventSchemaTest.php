<?php

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Models\User;
use Illuminate\Support\Facades\Schema;

test('applique le schéma du journal de sécurité sur MariaDB', function () {
    expect(Schema::hasColumns('user_security_events', [
        'id',
        'user_id',
        'user_device_id',
        'event',
        'channel',
        'ip_address',
        'user_agent',
        'context',
        'occurred_at',
        'created_at',
    ]))->toBeTrue();
});

test('persiste un événement de sécurité et ses relations sur MariaDB', function () {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => '550e8400-e29b-41d4-a716-446655440013',
    ]);

    $event = app(RecordSecurityEvent::class)->handle(
        event: 'device.registered',
        channel: 'web',
        user: $user,
        device: $device,
        context: ['source' => 'login'],
    );

    expect($event->exists)->toBeTrue()
        ->and($user->securityEvents()->sole()->is($event))->toBeTrue()
        ->and($device->securityEvents()->sole()->is($event))->toBeTrue();
});
