<?php

namespace App\Domains\Identity\Models;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Append-only security audit record.
 *
 * @property int $id
 * @property int|null $user_id
 * @property int|null $user_device_id
 * @property string $event
 * @property string $channel
 * @property string|null $ip_address
 * @property string|null $user_agent
 * @property array<string, scalar|null>|null $context
 * @property Carbon $occurred_at
 * @property Carbon $created_at
 */
class UserSecurityEvent extends Model
{
    public const UPDATED_AT = null;

    protected $table = 'user_security_events';

    protected $fillable = [
        'user_id',
        'user_device_id',
        'event',
        'channel',
        'ip_address',
        'user_agent',
        'context',
        'occurred_at',
    ];

    /**
     * Get the user associated with this event, when identifiable.
     *
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the device associated with this event, when applicable.
     *
     * @return BelongsTo<UserDevice, $this>
     */
    public function device(): BelongsTo
    {
        return $this->belongsTo(UserDevice::class, 'user_device_id');
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'context' => 'array',
            'occurred_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
        ];
    }
}
