<?php

namespace App\Domains\Identity\Models;

use App\Models\User;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;
use Laravel\Sanctum\PersonalAccessToken as SanctumPersonalAccessToken;

class PersonalAccessToken extends SanctumPersonalAccessToken
{
    protected $fillable = [
        'name',
        'token',
        'abilities',
        'expires_at',
        'device_id',
    ];

    protected static function booted(): void
    {
        static::creating(function (self $token): void {
            if (
                $token->tokenable_type !== User::class
                || $token->device_id !== null
            ) {
                return;
            }

            $uuid = request()->cookie(DeviceActivityTracker::COOKIE_NAME);

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
