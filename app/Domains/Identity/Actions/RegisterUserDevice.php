<?php

namespace App\Domains\Identity\Actions;

use App\Domains\Identity\Models\UserDevice;
use App\Models\User;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class RegisterUserDevice
{
    /**
     * Register a device after the user has completed the panel authentication flow.
     *
     * @param  array{name?: string|null, platform?: string|null, device_type?: string|null}  $metadata
     * @return array{device: UserDevice, created: bool}
     */
    public function handle(User $user, string $uuid, array $metadata = []): array
    {
        if (! Str::isUuid($uuid)) {
            throw ValidationException::withMessages([
                'device' => 'L’identifiant de l’appareil est invalide.',
            ]);
        }

        $device = UserDevice::query()->where('uuid', $uuid)->first();

        if ($device !== null && $device->user_id !== $user->getKey()) {
            throw ValidationException::withMessages([
                'device' => 'Cet identifiant d’appareil est déjà associé à un autre utilisateur.',
            ]);
        }

        if ($device?->revoked_at !== null) {
            throw ValidationException::withMessages([
                'device' => 'Cet appareil a été révoqué.',
            ]);
        }

        $created = $device === null;

        if ($created) {
            $device = $user->devices()->create([
                'uuid' => $uuid,
                'name' => $metadata['name'] ?? 'Navigateur web',
                'platform' => $metadata['platform'] ?? null,
                'device_type' => $metadata['device_type'] ?? 'browser',
                'trusted_at' => now(),
                'last_seen_at' => now(),
            ]);
        } else {
            $device->forceFill([
                'last_seen_at' => now(),
                'trusted_at' => $device->trusted_at ?? now(),
            ])->save();
        }

        return [
            'device' => $device,
            'created' => $created,
        ];
    }
}
