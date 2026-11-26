<?php

namespace App\Domains\Identity\Listeners;

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Domains\Identity\Support\AuthenticationChannelResolver;
use App\Models\User;
use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;

final class RecordAuthenticationEvent
{
    public function __construct(
        private readonly RecordSecurityEvent $recordSecurityEvent,
        private readonly AuthenticationChannelResolver $channelResolver,
    ) {}

    public function login(Login $event): void
    {
        $channel = $this->channelResolver->resolve($event->guard);

        if ($channel === 'filament') {
            return;
        }

        $user = $event->user instanceof User ? $event->user : null;

        $this->recordSecurityEvent->handle(
            'login.succeeded',
            $channel,
            $user,
            context: [
                'method' => $event->remember ? 'remembered_session' : 'password_or_guard',
                'source' => 'laravel_auth',
            ],
        );
    }

    public function failed(Failed $event): void
    {
        $channel = $this->channelResolver->resolve($event->guard);

        if ($channel === 'filament') {
            return;
        }

        $user = $event->user instanceof User ? $event->user : null;

        $this->recordSecurityEvent->handle(
            'login.failed',
            $channel,
            $user,
            context: [
                'method' => 'password_or_guard',
                'failure_code' => 'authentication_failed',
                'source' => 'laravel_auth',
            ],
        );
    }

    public function logout(Logout $event): void
    {
        $user = $event->user instanceof User ? $event->user : null;

        $this->recordSecurityEvent->handle(
            'logout.succeeded',
            $this->channelResolver->resolve($event->guard),
            $user,
            context: ['source' => 'laravel_auth'],
        );
    }
}
