<?php

namespace App\Domains\Identity\Actions;

use App\Domains\Identity\Catalog\SecurityEventChannel;
use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Models\UserSecurityEvent;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Request;
use Illuminate\Validation\ValidationException;

final class RecordSecurityEvent
{
    /**
     * Context keys are intentionally allow-listed to prevent credentials or
     * arbitrary request payloads from entering the security journal.
     *
     * @var list<string>
     */
    private const CONTEXT_KEYS = [
        'method',
        'failure_code',
        'source',
        'mfa_method',
        'actor_id',
    ];

    /**
     * Record one immutable security event.
     *
     * @param  array<string, mixed>  $context
     */
    public function handle(
        string $event,
        string $channel,
        ?User $user = null,
        ?UserDevice $device = null,
        array $context = [],
        ?Carbon $occurredAt = null,
    ): UserSecurityEvent {
        if (! in_array($channel, SecurityEventChannel::values(), true)) {
            throw ValidationException::withMessages([
                'channel' => 'Le canal de sécurité est invalide.',
            ]);
        }

        if ($device !== null && $user !== null && $device->user_id !== $user->getKey()) {
            throw ValidationException::withMessages([
                'device' => 'L’appareil ne correspond pas à l’utilisateur indiqué.',
            ]);
        }

        $ipAddress = Request::ip();
        $ipAddress = is_string($ipAddress) && filter_var($ipAddress, FILTER_VALIDATE_IP)
            ? $ipAddress
            : null;

        $userAgent = Request::userAgent();

        return UserSecurityEvent::query()->create([
            'user_id' => $user?->getKey(),
            'user_device_id' => $device?->getKey(),
            'event' => mb_substr(trim($event), 0, 100),
            'channel' => $channel,
            'ip_address' => $ipAddress,
            'user_agent' => is_string($userAgent) ? mb_substr($userAgent, 0, 1000) : null,
            'context' => $this->filterContext($context),
            'occurred_at' => $occurredAt ?? now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $context
     * @return array<string, scalar|null>
     */
    private function filterContext(array $context): array
    {
        $filtered = [];

        foreach (self::CONTEXT_KEYS as $key) {
            if (! array_key_exists($key, $context)) {
                continue;
            }

            $value = $context[$key];

            if (is_string($value)) {
                $filtered[$key] = mb_substr($value, 0, 100);
            } elseif (is_bool($value) || is_int($value) || $value === null) {
                $filtered[$key] = $value;
            }
        }

        return $filtered;
    }
}
