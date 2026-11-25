<?php

namespace App\Domains\Identity\Actions;

use App\Domains\Identity\Models\UserDevice;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

final class RevokeUserDevice
{
    public function __construct(private readonly RecordSecurityEvent $recordSecurityEvent) {}

    public function handle(User $actor, UserDevice $device): UserDevice
    {
        if ($device->user_id !== $actor->getKey()) {
            throw new AuthorizationException('Vous ne pouvez pas révoquer cet appareil.');
        }

        return DB::transaction(function () use ($actor, $device): UserDevice {
            $device = UserDevice::query()->whereKey($device->getKey())->lockForUpdate()->firstOrFail();

            if ($device->user_id !== $actor->getKey()) {
                throw new AuthorizationException('Vous ne pouvez pas révoquer cet appareil.');
            }

            if ($device->revoked_at !== null) {
                return $device;
            }

            $request = request();
            $currentSessionMatches = false;

            if (config('session.driver') === 'database' && $request->hasSession()
                && Auth::guard('web')->check()
                && (int) Auth::guard('web')->id() === (int) $device->user_id) {
                $currentSessionMatches = DB::connection(config('session.connection'))
                    ->table(config('session.table', 'sessions'))
                    ->where('id', $request->session()->getId())
                    ->where('user_id', $actor->getKey())
                    ->where('device_id', $device->getKey())
                    ->exists();
            }

            $device->forceFill(['revoked_at' => now()])->save();
            $device->accessTokens()->delete();

            if (config('session.driver') === 'database') {
                DB::connection(config('session.connection'))
                    ->table(config('session.table', 'sessions'))
                    ->where('device_id', $device->getKey())
                    ->delete();
            }

            $this->recordSecurityEvent->handle(
                'device.revoked',
                'web',
                $actor,
                $device,
                ['source' => 'user_device_management'],
            );

            if ($currentSessionMatches) {
                Auth::guard('web')->logout();
                $request->session()->invalidate();
                $request->session()->regenerateToken();
            }

            return $device->refresh();
        });
    }
}
