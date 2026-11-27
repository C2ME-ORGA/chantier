<?php

namespace App\Domains\Identity\Actions;

use App\Domains\Identity\Models\UserSecurityEvent;
use Illuminate\Validation\ValidationException;

final class PreserveSecurityEvent
{
    public function handle(UserSecurityEvent $event, string $reason): UserSecurityEvent
    {
        $reason = trim($reason);

        if ($reason === '' || mb_strlen($reason) > 500) {
            throw ValidationException::withMessages([
                'reason' => 'Le motif de conservation doit contenir entre 1 et 500 caractères.',
            ]);
        }

        if ($event->preserved_at !== null) {
            return $event;
        }

        $event->forceFill([
            'preserved_at' => now(),
            'preservation_reason' => $reason,
        ])->save();

        return $event->refresh();
    }
}
