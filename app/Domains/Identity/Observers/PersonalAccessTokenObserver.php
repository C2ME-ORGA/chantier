<?php

namespace App\Domains\Identity\Observers;

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Domains\Identity\Catalog\SecurityEventChannel;
use App\Domains\Identity\Models\PersonalAccessToken;
use App\Models\User;

final class PersonalAccessTokenObserver
{
    public function __construct(private readonly RecordSecurityEvent $recordSecurityEvent) {}

    public function created(PersonalAccessToken $token): void
    {
        $this->record($token, 'token.created');
    }

    public function deleted(PersonalAccessToken $token): void
    {
        $this->record($token, 'token.revoked');
    }

    private function record(PersonalAccessToken $token, string $event): void
    {
        $user = $token->tokenable;

        if (! $user instanceof User) {
            return;
        }

        $this->recordSecurityEvent->handle(
            event: $event,
            channel: SecurityEventChannel::API,
            user: $user,
            device: $token->device,
            context: [
                'source' => 'sanctum',
                'method' => 'personal_access_token',
            ],
        );
    }
}
