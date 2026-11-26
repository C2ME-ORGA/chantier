<?php

namespace App\Http\Middleware;

use App\Domains\Identity\Models\PersonalAccessToken;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class EnsureAccessTokenDeviceIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->user()?->currentAccessToken();

        if ($token instanceof PersonalAccessToken && $token->device_id) {
            $device = $token->device;

            if (! $device || $device->revoked_at !== null) {
                return response()->json(['message' => 'Appareil révoqué.'], 401);
            }
        }

        return $next($request);
    }
}
