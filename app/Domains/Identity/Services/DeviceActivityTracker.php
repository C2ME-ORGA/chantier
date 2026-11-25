<?php

namespace App\Domains\Identity\Services;

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Domains\Identity\Actions\RegisterUserDevice;
use App\Domains\Identity\Models\UserDevice;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Support\Str;

final class DeviceActivityTracker
{
    public const COOKIE_NAME = 'c2me_device_uuid';

    public function __construct(
        private readonly RegisterUserDevice $registerUserDevice,
        private readonly RecordSecurityEvent $recordSecurityEvent,
    ) {}

    public function track(Request $request, User $user): void
    {
        $uuid = $request->cookie(self::COOKIE_NAME);
        $isNewIdentifier = ! is_string($uuid) || ! Str::isUuid($uuid);

        if (! $isNewIdentifier) {
            $existingDevice = UserDevice::query()->where('uuid', $uuid)->first();

            if ($existingDevice !== null && $existingDevice->user_id !== $user->getKey()) {
                $isNewIdentifier = true;
            }
        }

        if ($isNewIdentifier) {
            $uuid = (string) Str::uuid();
            Cookie::queue(cookie(
                self::COOKIE_NAME,
                $uuid,
                60 * 24 * 365 * 2,
                '/',
                null,
                $request->isSecure(),
                true,
                false,
                'lax',
            ));
        }

        $userAgent = (string) $request->userAgent();
        $platform = $this->detectPlatform($userAgent);

        $result = $this->registerUserDevice->handle($user, $uuid, [
            'name' => 'Navigateur web',
            'platform' => $platform,
            'device_type' => 'browser',
        ]);

        if ($result['created']) {
            $this->recordSecurityEvent->handle(
                'device.registered',
                'filament',
                $user,
                $result['device'],
                ['source' => 'authenticated_panel'],
            );

        }
    }

    private function detectPlatform(string $userAgent): ?string
    {
        return match (true) {
            str_contains($userAgent, 'Windows') => 'Windows',
            str_contains($userAgent, 'Mac OS') => 'macOS',
            str_contains($userAgent, 'Android') => 'Android',
            str_contains($userAgent, 'iPhone'), str_contains($userAgent, 'iPad') => 'iOS',
            str_contains($userAgent, 'Linux') => 'Linux',
            default => null,
        };
    }
}
