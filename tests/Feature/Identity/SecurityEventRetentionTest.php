<?php

use App\Domains\Identity\Actions\PreserveSecurityEvent;
use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Models\UserSecurityEvent;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

beforeEach(function (): void {
    Carbon::setTestNow(Carbon::parse('2026-11-27 12:00:00'));
});

afterEach(function (): void {
    Carbon::setTestNow();
});

/**
 * @param  array<string, mixed>  $attributes
 */
function createRetentionEvent(array $attributes = []): UserSecurityEvent
{
    return UserSecurityEvent::query()->create(array_merge([
        'event' => 'login.failed',
        'channel' => 'web',
        'occurred_at' => now(),
    ], $attributes));
}

/**
 * @param  array<string, mixed>  $attributes
 */
function createRetentionDevice(array $attributes = []): UserDevice
{
    $user = User::factory()->create();

    return $user->devices()->create(array_merge([
        'uuid' => (string) Str::uuid(),
    ], $attributes));
}

test('simule la purge sans supprimer les événements ni les appareils', function (): void {
    $oldEvent = createRetentionEvent(['occurred_at' => now()->subMonths(13)]);
    $oldDevice = createRetentionDevice(['revoked_at' => now()->subMonths(13)]);

    $this->artisan('identity:purge-security-events')
        ->expectsOutputToContain('Simulation uniquement')
        ->expectsOutputToContain('Événements éligibles : 1')
        ->expectsOutputToContain('Appareils révoqués éligibles : 1')
        ->assertSuccessful();

    expect(UserSecurityEvent::query()->whereKey($oldEvent->getKey())->exists())->toBeTrue()
        ->and(UserDevice::query()->whereKey($oldDevice->getKey())->exists())->toBeTrue();
});

test('purge les événements de plus de douze mois mais conserve les événements préservés', function (): void {
    $expired = createRetentionEvent(['occurred_at' => now()->subMonths(12)->subSecond()]);
    $boundary = createRetentionEvent(['occurred_at' => now()->subMonths(12)]);
    $recent = createRetentionEvent(['occurred_at' => now()->subMonths(11)]);
    $preserved = createRetentionEvent(['occurred_at' => now()->subYears(2)]);

    app(PreserveSecurityEvent::class)->handle($preserved, 'Investigation sécurité INC-2026-0042');

    $this->artisan('identity:purge-security-events', ['--execute' => true, '--chunk' => 1])
        ->expectsOutputToContain('Événements supprimés : 1')
        ->assertSuccessful();

    expect(UserSecurityEvent::query()->whereKey($expired->getKey())->exists())->toBeFalse()
        ->and(UserSecurityEvent::query()->whereKey($boundary->getKey())->exists())->toBeTrue()
        ->and(UserSecurityEvent::query()->whereKey($recent->getKey())->exists())->toBeTrue()
        ->and(UserSecurityEvent::query()->whereKey($preserved->getKey())->exists())->toBeTrue();
});

test('purge les appareils révoqués après douze mois et conserve leurs événements', function (): void {
    $expiredDevice = createRetentionDevice(['revoked_at' => now()->subMonths(13)]);
    $recentDevice = createRetentionDevice(['revoked_at' => now()->subMonths(11)]);
    $activeDevice = createRetentionDevice();

    $event = createRetentionEvent([
        'user_id' => $expiredDevice->user_id,
        'user_device_id' => $expiredDevice->getKey(),
        'occurred_at' => now()->subMonths(2),
    ]);

    $this->artisan('identity:purge-security-events', ['--execute' => true])
        ->expectsOutputToContain('Appareils révoqués supprimés : 1')
        ->assertSuccessful();

    expect(UserDevice::query()->whereKey($expiredDevice->getKey())->exists())->toBeFalse()
        ->and(UserDevice::query()->whereKey($recentDevice->getKey())->exists())->toBeTrue()
        ->and(UserDevice::query()->whereKey($activeDevice->getKey())->exists())->toBeTrue()
        ->and(UserSecurityEvent::query()->whereKey($event->getKey())->value('user_device_id'))->toBeNull();
});

test('une conservation exige un motif et reste idempotente', function (): void {
    $event = createRetentionEvent(['occurred_at' => now()->subYears(2)]);

    expect(fn () => app(PreserveSecurityEvent::class)->handle($event, '   '))
        ->toThrow(ValidationException::class);

    $preserved = app(PreserveSecurityEvent::class)->handle($event, 'Enquête INC-123');
    $preservedAt = $preserved->preserved_at;

    $again = app(PreserveSecurityEvent::class)->handle($preserved, 'Autre motif');

    expect($again->preserved_at->equalTo($preservedAt))->toBeTrue()
        ->and($again->preservation_reason)->toBe('Enquête INC-123');
});

test('refuse une taille de lot invalide', function (): void {
    $this->artisan('identity:purge-security-events', ['--chunk' => 0])
        ->assertFailed();
});
