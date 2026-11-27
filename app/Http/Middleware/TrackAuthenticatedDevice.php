<?php

namespace App\Http\Middleware;

use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Services\DeviceActivityTracker;
use App\Models\User;
use Closure;
use Filament\Auth\MultiFactor\Http\Middleware\EnsureMultiFactorAuthenticationIsEnabled;
use Filament\Facades\Filament;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

final class TrackAuthenticatedDevice extends EnsureMultiFactorAuthenticationIsEnabled
{
    private const SESSION_DEVICE_ATTRIBUTE = 'identity.session_device';

    public function __construct(private readonly DeviceActivityTracker $deviceActivityTracker) {}

    public function handle(Request $request, Closure $next): Response
    {
        return parent::handle($request, function (Request $request) use ($next): Response {
            $user = Filament::auth()->user();

            if ($user instanceof User) {
                $uuid = $request->cookie(DeviceActivityTracker::COOKIE_NAME);

                if (is_string($uuid) && Str::isUuid($uuid)) {
                    $revokedDevice = UserDevice::query()
                        ->where('user_id', $user->getKey())
                        ->where('uuid', $uuid)
                        ->whereNotNull('revoked_at')
                        ->exists();

                    if ($revokedDevice) {
                        Auth::guard('web')->logout();

                        if ($request->hasSession()) {
                            $request->session()->invalidate();
                            $request->session()->regenerateToken();
                        }

                        $forgetCookie = Cookie::forget(DeviceActivityTracker::COOKIE_NAME);

                        if ($request->expectsJson()) {
                            return response()->json(
                                ['message' => 'Cet appareil a été révoqué. Veuillez vous reconnecter.'],
                                401,
                            )->withCookie($forgetCookie);
                        }

                        return redirect()
                            ->guest(Filament::getCurrentPanel()->getLoginUrl())
                            ->withCookie($forgetCookie);
                    }
                }

                $device = $this->deviceActivityTracker->track($request, $user);

                if (
                    $request->hasSession()
                    && config('session.driver') === 'database'
                ) {
                    $request->session()->put('_identity_device_id', $device->getKey());
                    $request->attributes->set(self::SESSION_DEVICE_ATTRIBUTE, [
                        'device_id' => (int) $device->getKey(),
                        'user_id' => (int) $user->getKey(),
                        'session_id' => $request->session()->getId(),
                    ]);
                }
            }

            return $next($request);
        });
    }
}
