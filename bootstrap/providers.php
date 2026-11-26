<?php

use App\Domains\Identity\Providers\IdentityServiceProvider;
use App\Providers\AppServiceProvider;
use App\Providers\Filament\AdminPanelProvider;

return [
    AppServiceProvider::class,
    IdentityServiceProvider::class,
    AdminPanelProvider::class,
];
