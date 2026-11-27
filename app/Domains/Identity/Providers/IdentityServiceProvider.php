<?php

namespace App\\Domains\\Identity\\Providers;

use App\\Domains\\Identity\\Listeners\\AssociateDeviceWithSession;
use App\\Domains\\Identity\\Listeners\\RecordAuthenticationEvent;
use App\\Domains\\Identity\\Models\\PersonalAccessToken;
use App\\Domains\\Identity\\Observers\\PersonalAccessTokenObserver;
use Illuminate\\Auth\\Events\\Failed;
use Illuminate\\Auth\\Events\\Login;
use Illuminate\\Auth\\Events\\Logout;
use Illuminate\\Foundation\\Http\\Events\\RequestHandled;
use Illuminate\\Support\\Facades\\Event;
use Illuminate\\Support\\ServiceProvider;
use Laravel\\Sanctum\\Sanctum;

final class IdentityServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);

        PersonalAccessToken::observe(PersonalAccessTokenObserver::class);

        Event::listen(Login::class, [RecordAuthenticationEvent::class, 'login']);
        Event::listen(Failed::class, [RecordAuthenticationEvent::class, 'failed']);
        Event::listen(Logout::class, [RecordAuthenticationEvent::class, 'logout']);
        Event::listen(RequestHandled::class, AssociateDeviceWithSession::class);
    }
}
