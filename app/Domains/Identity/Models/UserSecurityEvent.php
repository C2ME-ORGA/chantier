<?php

namespace App\Domains\Identity\Models;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;
use LogicException;

/**
 * Append-only security audit record.
 *
 * Only preservation metadata may be added after creation. Bulk maintenance
 * deletion is reserved for the explicit retention command.
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
 * @property Carbon|null $preserved_at
 * @property string|null $preservation_reason
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

    protected static function booted(): void
    {
        static::updating(static function (UserSecurityEvent $event): void {
            $allowed = ['preserved_at', 'preservation_reason'];
            $dirty = array_keys($event->getDirty());

            if (array_diff($dirty, $allowed) !== []) {
                throw new LogicException('Les données d’un événement de sécurité ne peuvent pas être modifiées.');
            }

            if (
                $event->getOriginal('preserved_at') !== null
                || $event->getOriginal('preservation_reason') !== null
            ) {
                throw new LogicException('Les métadonnées de préservation ne peuvent pas être modifiées après leur définition.');
            }

            if (
                ! $event->isDirty('preserved_at')
                || ! $event->isDirty('preservation_reason')
                || $event->preserved_at === null
                || blank($event->preservation_reason)
            ) {
                throw new LogicException('La préservation d’un événement exige une date et un motif.');
            }
        });

        static::deleting(static function (): never {
            throw new LogicException('Les événements de sécurité ne peuvent pas être supprimés hors purge contrôlée.');
        });
    }

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
            'preserved_at' => 'immutable_datetime',
            'created_at' => 'immutable_datetime',
        ];
    }
}
