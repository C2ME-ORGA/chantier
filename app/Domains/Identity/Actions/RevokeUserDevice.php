<?php

namespace App\Domains\Identity\Actions;

use App\Domains\Identity\Models\PersonalAccessToken;
use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Notifications\DeviceRevokedNotification;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use LogicException;

final class RevokeUserDevice
{
    public function __construct(private readonly RecordSecurityEvent $recordSecurityEvent) {}

    public function handle(User $actor, UserDevice $device): UserDevice
    {
        if ($device->user_id !== $actor->getKey() && ! $actor->can('identity.devices.manage')) {
            throw new AuthorizationException('Vous ne pouvez pas révoquer cet appareil.');
        }

        $sessionConnection = $this->assertSessionRevocationIsSupported();

        [$revokedDevice, $ownerToNotify] = DB::connection($sessionConnection)
            ->transaction(function () use ($actor, $device, $sessionConnection): array {
                $device = UserDevice::query()->whereKey($device->getKey())->lockForUpdate()->firstOrFail();

                if ($device->user_id !== $actor->getKey() && ! $actor->can('identity.devices.manage')) {
                    throw new AuthorizationException('Vous ne pouvez pas révoquer cet appareil.');
                }

                if ($device->revoked_at !== null) {
                    return [$device, null];
                }

                $request = request();
                $currentSessionMatches = false;
                $sessions = DB::connection($sessionConnection)
                    ->table(config('session.table', 'sessions'));

                if (
                    $request->hasSession()
                    && Auth::guard('web')->check()
                    && (int) Auth::guard('web')->id() === (int) $device->user_id
                ) {
                    $currentSessionMatches = (clone $sessions)
                        ->where('id', $request->session()->getId())
                        ->where('user_id', $actor->getKey())
                        ->where('device_id', $device->getKey())
                        ->exists();
                }

                $device->forceFill(['revoked_at' => now()])->save();

                PersonalAccessToken::query()
                    ->where('device_id', $device->getKey())
                    ->chunkById(100, static function ($tokens): void {
                        $tokens->each(static fn (PersonalAccessToken $token) => $token->delete());
                    });

                $sessions
                    ->where('device_id', $device->getKey())
                    ->delete();

                $owner = $device->user()->firstOrFail();

                $this->recordSecurityEvent->handle(
                    'device.revoked',
                    'web',
                    $owner,
                    $device,
                    [
                        'source' => 'user_device_management',
                        'actor_id' => (int) $actor->getKey(),
                    ],
                );

                if ($currentSessionMatches) {
                    Auth::guard('web')->logout();
                    $request->session()->invalidate();
                    $request->session()->regenerateToken();
                }

                return [$device->refresh(), $owner];
            });

        if ($ownerToNotify instanceof User) {
            $ownerToNotify->notify(new DeviceRevokedNotification($revokedDevice));
        }

        return $revokedDevice;
    }

    /**
     * Session rows must share the transaction connection for revocation to be atomic.
     */
    private function assertSessionRevocationIsSupported(): string
    {
        if (config('session.driver') !== 'database') {
            throw new LogicException(
                'La révocation complète des appareils exige SESSION_DRIVER=database.',
            );
        }

        $sessionConnection = config('session.connection') ?: config('database.default');
        $modelConnection = (new UserDevice)->getConnectionName() ?: config('database.default');

        if ($sessionConnection !== $modelConnection) {
            throw new LogicException(
                'La connexion des sessions doit être identique à celle de la base applicative pour garantir une révocation atomique.',
            );
        }

        return $sessionConnection;
    }
}
