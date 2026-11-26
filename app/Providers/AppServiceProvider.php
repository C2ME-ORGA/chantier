<?php

namespace App\Providers;

use App\Domains\Identity\Listeners\RecordAuthenticationEvent;
use App\Domains\Identity\Models\PersonalAccessToken;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;
use Laravel\Sanctum\Sanctum;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);

        Event::listen(
            \Illuminate\Auth\Events\Login::class,
            [RecordAuthenticationEvent::class, 'login'],
        );

        Event::listen(
            \Illuminate\Auth\Events\Failed::class,
            [RecordAuthenticationEvent::class, 'failed'],
        );

        Event::listen(
            \Illuminate\Auth\Events\Logout::class,
            [RecordAuthenticationEvent::class, 'logout'],
        );

        $this->configureDefaults();
    }

    /**
     * Configure default behaviors for production-ready applications.
     */
    protected function configureDefaults(): void
    {
        Date::use(CarbonImmutable::class);

        DB::prohibitDestructiveCommands(
            app()->isProduction(),
        );

        Password::defaults(fn (): ?Password => app()->isProduction()
            ? Password::min(12)
                ->mixedCase()
                ->letters()
                ->numbers()
                ->symbols()
                ->uncompromised()
            : null,
        );
    }
}
