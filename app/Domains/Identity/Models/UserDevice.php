<?php

namespace App\Domains\Identity\Models;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * @property int $id
 * @property int $user_id
 * @property string $uuid
 * @property string|null $name
 * @property string|null $platform
 * @property string|null $device_type
 * @property Carbon|null $last_seen_at
 * @property Carbon|null $trusted_at
 * @property Carbon|null $revoked_at
 */
class UserDevice extends Model
{
    protected $fillable = [
        'user_id',
        'uuid',
        'name',
        'platform',
        'device_type',
        'last_seen_at',
        'trusted_at',
        'revoked_at',
    ];

    /**
     * Get the user who owns this device.
     *
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the security events associated with this device.
     *
     * @return HasMany<UserSecurityEvent, $this>
     */
    public function securityEvents(): HasMany
    {
        return $this->hasMany('App\\Domains\\Identity\\Models\\UserSecurityEvent', 'user_device_id');
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'last_seen_at' => 'datetime',
            'trusted_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }
}
