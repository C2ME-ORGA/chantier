<?php

namespace App\Domains\Identity\Models;

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Domains\Identity\Support\DeviceCookie;
use App\Models\User;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;
use Laravel\Sanctum\PersonalAccessToken as SanctumPersonalAccessToken;

/**
 * @property int|null $device_id
 */
class PersonalAccessToken extends SanctumPersonalAccessToken
{
    protected static function booted(): void
    {
        static::creating(function (self $token): void {
            if (
                $token->tokenable_type !== User::class
                || $token->device_id !== null
            ) {
                return;
            }

            $uuid = request()->cookie(DeviceCookie::NAME);

            if (! is_string($uuid) || ! Str::isUuid($uuid)) {
                return;
            }

            $device = UserDevice::query()
                ->where('user_id', $token->tokenable_id)
                ->where('uuid', $uuid)
                ->whereNull('revoked_at')
                ->first();

            if ($device !== null) {
                $token->device_id = $device->getKey();
            }
        });

        static::created(function (self $token): void {
            $user = $token->tokenable;

            if (! $user instanceof User) {
                return;
            }

            app(RecordSecurityEvent::class)->handle(
                event: 'token.created',
                channel: 'api',
                user: $user,
                device: $token->device,
                context: [
                    'source' => 'sanctum',
                    'method' => 'personal_access_token',
                ],
            );
        });

        static::deleted(function (self $token): void {
            $user = $token->tokenable;

            if (! $user instanceof User) {
                return;
            }

            app(RecordSecurityEvent::class)->handle(
                event: 'token.revoked',
                channel: 'api',
                user: $user,
                device: $token->device,
                context: [
                    'source' => 'sanctum',
                    'method' => 'personal_access_token',
                ],
            );
        });
    }

    /**
     * Get the device that owns this API token.
     *
     * @return BelongsTo<UserDevice, $this>
     */
    public function device(): BelongsTo
    {
        return $this->belongsTo(UserDevice::class);
    }
}
