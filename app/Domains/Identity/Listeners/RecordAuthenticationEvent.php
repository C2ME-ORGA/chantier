<?php

namespace App\Domains\Identity\Listeners;

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Models\User;
use Illuminate\Auth\Events\Failed;
use Illuminate\Auth\Events\Login;
use Illuminate\Auth\Events\Logout;
use Illuminate\Support\Facades\Request;

final class RecordAuthenticationEvent
{
    public function __construct(private readonly RecordSecurityEvent $recordSecurityEvent) {}

    public function login(Login $event): void
    {
        if ($this->isFilamentRequest()) {
            return;
        }

        $user = $event->user instanceof User ? $event->user : null;

        $this->recordSecurityEvent->handle(
            'login.succeeded',
            $this->channel($event->guard),
            $user,
            context: [
                'method' => $event->remember ? 'remembered_session' : 'password_or_guard',
                'source' => 'laravel_auth',
            ],
        );
    }

    public function failed(Failed $event): void
    {
        if ($this->isFilamentRequest()) {
            return;
        }

        $user = $event->user instanceof User ? $event->user : null;

        $this->recordSecurityEvent->handle(
            'login.failed',
            $this->channel($event->guard),
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
            $this->channel($event->guard),
            $user,
            context: ['source' => 'laravel_auth'],
        );
    }

    private function channel(string $guard): string
    {
        if ($this->isFilamentRequest()) {
            return 'filament';
        }

        if (in_array($guard, ['sanctum', 'api'], true) || Request::is('api/*')) {
            return 'api';
        }

        return 'web';
    }

    private function isFilamentRequest(): bool
    {
        return Request::is('admin', 'admin/*')
            || Request::routeIs('filament.*');
    }
}
