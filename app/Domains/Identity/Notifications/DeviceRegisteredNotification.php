<?php

namespace App\Domains\Identity\Notifications;

use App\Domains\Identity\Models\UserDevice;
use Illuminate\Notifications\Notification;

final class DeviceRegisteredNotification extends Notification
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
            'event' => 'device.registered',
            'device_id' => $this->device->getKey(),
            'device_name' => $this->device->name,
            'platform' => $this->device->platform,
            'registered_at' => $this->device->created_at?->toISOString(),
        ];
    }
}
