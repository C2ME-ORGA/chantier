<?php

namespace App\Http\Middleware;

use App\Domains\Identity\Services\DeviceActivityTracker;
use Closure;
use Filament\Auth\MultiFactor\Http\Middleware\EnsureMultiFactorAuthenticationIsEnabled;
use Filament\Facades\Filament;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class TrackAuthenticatedDevice extends EnsureMultiFactorAuthenticationIsEnabled
{
    public function __construct(
        private readonly DeviceActivityTracker $deviceActivityTracker,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        return parent::handle($request, function (Request $request) use ($next): Response {
            $user = Filament::auth()->user();

            if ($user instanceof \App\Models\User) {
                $this->deviceActivityTracker->track($request, $user);
            }

            return $next($request);
        });
    }
}
