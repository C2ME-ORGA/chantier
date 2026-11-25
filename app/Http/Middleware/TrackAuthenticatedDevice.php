<?php

namespace App\Http\Middleware;

use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Services\DeviceActivityTracker;
use App\Models\User;
use Closure;
use Filament\Auth\MultiFactor\Http\Middleware\EnsureMultiFactorAuthenticationIsEnabled;
use Filament\Facades\Filament;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

final class TrackAuthenticatedDevice extends EnsureMultiFactorAuthenticationIsEnabled
{
    public function __construct(private readonly DeviceActivityTracker $deviceActivityTracker) {}

    public function handle(Request $request, Closure $next): Response
    {
        return parent::handle($request, function (Request $request) use ($next): Response {
            $user = Filament::auth()->user();

            if ($user instanceof User) {
                $this->deviceActivityTracker->track($request, $user);

                $uuid = $request->cookie(DeviceActivityTracker::COOKIE_NAME);

                if (is_string($uuid) && Str::isUuid($uuid)) {
                    $device = UserDevice::query()
                        ->where('user_id', $user->getKey())
                        ->where('uuid', $uuid)
                        ->whereNull('revoked_at')
                        ->first();

                    if (
                        $device !== null
                        && $request->hasSession()
                        && config('session.driver') === 'database'
                    ) {
                        DB::connection(config('session.connection'))
                            ->table(config('session.table', 'sessions'))
                            ->where('id', $request->session()->getId())
                            ->where('user_id', $user->getKey())
                            ->update(['device_id' => $device->getKey()]);
                    }
                }
            }

            return $next($request);
        });
    }
}
