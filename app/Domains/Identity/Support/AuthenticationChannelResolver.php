<?php

namespace App\Domains\Identity\Support;

use Filament\Facades\Filament;
use Illuminate\Support\Facades\Request;

final class AuthenticationChannelResolver
{
    public function resolve(string $guard): string
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
        return Filament::getCurrentPanel()?->getId() === 'admin'
            || Request::is('admin', 'admin/*')
            || Request::routeIs('filament.*');
    }
}
