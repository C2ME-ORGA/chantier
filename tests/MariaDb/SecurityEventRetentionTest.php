<?php

use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Models\UserSecurityEvent;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

test('MariaDB conserve les événements lorsque leur appareil est purgé', function (): void {
    $user = User::factory()->create();
    $device = $user->devices()->create([
        'uuid' => (string) Illuminate\Support\Str::uuid(),
        'revoked_at' => now()->subMonths(13),
    ]);

    $event = UserSecurityEvent::query()->create([
        'user_id' => $user->getKey(),
        'user_device_id' => $device->getKey(),
        'event' => 'device.revoked',
        'channel' => 'web',
        'occurred_at' => now()->subMonths(2),
    ]);

    DB::table('user_devices')->where('id', $device->getKey())->delete();

    expect(UserSecurityEvent::query()->whereKey($event->getKey())->value('user_device_id'))->toBeNull();
});

test('MariaDB accepte la migration des métadonnées de conservation', function (): void {
    $columns = DB::getSchemaBuilder()->getColumnListing('user_security_events');

    expect($columns)->toContain('preserved_at', 'preservation_reason');

    $event = UserSecurityEvent::query()->create([
        'event' => 'login.failed',
        'channel' => 'web',
        'occurred_at' => Carbon::now()->subYears(2),
    ]);

    DB::table('user_security_events')->where('id', $event->getKey())->update([
        'preserved_at' => now(),
        'preservation_reason' => 'Investigation MariaDB',
    ]);

    expect(DB::table('user_security_events')->where('id', $event->getKey())->value('preservation_reason'))
        ->toBe('Investigation MariaDB');
});
