<?php

use App\Domains\Identity\Actions\RevokeUserDevice;
use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Models\UserSecurityEvent;
use App\Domains\Identity\Notifications\DeviceRevokedNotification;
use App\Filament\Pages\DeviceManagementPage;
use App\Filament\Pages\MyDevicesPage;
use App\Filament\Pages\MySecurityEventsPage;
use App\Filament\Pages\SecurityEventsPage;
use App\Models\User;
use Filament\Facades\Filament;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Notification;
use Livewire\Livewire;
use Spatie\Permission\Models\Permission;

beforeEach(function (): void {
    Filament::setCurrentPanel(Filament::getPanel('admin'));
});

it('limits the personal device page to the authenticated users devices', function (): void {
    $owner = User::factory()->create();
    $other = User::factory()->create();

    $ownDevice = UserDevice::query()->create([
        'user_id' => $owner->getKey(),
        'uuid' => (string) str()->uuid(),
        'name' => 'Mon navigateur',
        'device_type' => 'browser',
        'trusted_at' => now(),
        'last_seen_at' => now(),
    ]);

    $otherDevice = UserDevice::query()->create([
        'user_id' => $other->getKey(),
        'uuid' => (string) str()->uuid(),
        'name' => 'Autre navigateur',
        'device_type' => 'browser',
        'trusted_at' => now(),
        'last_seen_at' => now(),
    ]);

    Livewire::actingAs($owner)
        ->test(MyDevicesPage::class)
        ->assertCanSeeTableRecords([$ownDevice])
        ->assertCanNotSeeTableRecords([$otherDevice]);
});

it('limits the personal security history query to the authenticated user', function (): void {
    $owner = User::factory()->create();
    $other = User::factory()->create();

    $ownEvent = $owner->securityEvents()->create([
        'event' => 'login.succeeded',
        'channel' => 'filament',
        'occurred_at' => now(),
    ]);

    $otherEvent = $other->securityEvents()->create([
        'event' => 'login.succeeded',
        'channel' => 'filament',
        'occurred_at' => now(),
    ]);

    Livewire::actingAs($owner)
        ->test(MySecurityEventsPage::class)
        ->assertCanSeeTableRecords([$ownEvent])
        ->assertCanNotSeeTableRecords([$otherEvent]);
});

it('protects global security pages with their dedicated permissions', function (): void {
    $user = User::factory()->create();
    Auth::login($user);

    expect(SecurityEventsPage::canAccess())->toBeFalse()
        ->and(DeviceManagementPage::canAccess())->toBeFalse();

    Permission::findOrCreate('identity.security_events.view', 'web');
    Permission::findOrCreate('identity.devices.manage', 'web');

    $user->givePermissionTo('identity.security_events.view');

    expect(SecurityEventsPage::canAccess())->toBeTrue()
        ->and(DeviceManagementPage::canAccess())->toBeFalse();

    $user->givePermissionTo('identity.devices.manage');

    expect(DeviceManagementPage::canAccess())->toBeTrue();
});

it('allows a user with the device management permission to revoke another users device', function (): void {
    Notification::fake();

    $administrator = User::factory()->create();
    $owner = User::factory()->create();

    Permission::findOrCreate('identity.devices.manage', 'web');
    $administrator->givePermissionTo('identity.devices.manage');

    $device = UserDevice::query()->create([
        'user_id' => $owner->getKey(),
        'uuid' => (string) str()->uuid(),
        'name' => 'Appareil à révoquer',
        'device_type' => 'browser',
        'trusted_at' => now(),
        'last_seen_at' => now(),
    ]);

    $revoked = app(RevokeUserDevice::class)->handle($administrator, $device);

    expect($revoked->revoked_at)->not->toBeNull();

    $event = UserSecurityEvent::query()->where('event', 'device.revoked')->sole();

    expect($event->user_id)->toBe($owner->getKey())
        ->and($event->context['actor_id'])->toBe($administrator->getKey());

    Notification::assertSentTo($owner, DeviceRevokedNotification::class);
    Notification::assertNotSentTo($administrator, DeviceRevokedNotification::class);
});
