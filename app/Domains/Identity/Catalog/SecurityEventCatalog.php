<?php

namespace App\Domains\Identity\Catalog;

/**
 * Canonical event names currently emitted by the Identity domain.
 *
 * Keep this catalogue aligned with RecordAuthenticationEvent,
 * TrackedLogin, DeviceActivityTracker and RevokeUserDevice.
 */
final class SecurityEventCatalog
{
    /**
     * @var array<string, string>
     */
    private const EVENTS = [
        'login.succeeded' => 'Connexion réussie',
        'login.failed' => 'Échec de connexion',
        'logout.succeeded' => 'Déconnexion',
        'mfa.challenge.succeeded' => 'Validation MFA réussie',
        'mfa.challenge.failed' => 'Échec de validation MFA',
        'device.registered' => 'Nouvel appareil enregistré',
        'device.revoked' => 'Appareil révoqué',
    ];

    /**
     * @return array<string, string>
     */
    public static function options(): array
    {
        return self::EVENTS;
    }

    public static function label(?string $event): string
    {
        if ($event === null || $event === '') {
            return 'Événement inconnu';
        }

        return self::EVENTS[$event] ?? $event;
    }
}
