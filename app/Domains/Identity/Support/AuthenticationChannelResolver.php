<?php

namespace App\Domains\Identity\Support;

use App\Domains\Identity\Catalog\SecurityEventChannel;
use Filament\Facades\Filament;
use Illuminate\Support\Facades\Request;

final class AuthenticationChannelResolver
{
    public function resolve(string $guard): string
    {
        if ($this->isFilamentRequest()) {
            return SecurityEventChannel::FILAMENT;
        }

        if (in_array($guard, ['sanctum', 'api'], true) || Request::is('api/*')) {
            return SecurityEventChannel::API;
        }

        return SecurityEventChannel::WEB;
    }

    private function isFilamentRequest(): bool
    {
        return Filament::getCurrentPanel()?->getId() === 'admin'
            || Request::is('admin', 'admin/*')
            || Request::routeIs('filament.*');
    }
}
