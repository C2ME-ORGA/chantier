<?php

namespace App\Domains\Identity\Notifications;

use App\Domains\Identity\Models\UserDevice;
use Illuminate\Notifications\Notification;

final class DeviceRevokedNotification extends Notification
{
    public function __construct(private readonly UserDevice $device) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['database'];
    }

    /**
     * @return array<string, int|string|null>
     */
    public function toArray(object $notifiable): array
    {
        return [
            'event' => 'device.revoked',
            'device_id' => $this->device->getKey(),
            'device_name' => $this->device->name,
            'platform' => $this->device->platform,
            'revoked_at' => $this->device->revoked_at?->toISOString(),
        ];
    }
}
