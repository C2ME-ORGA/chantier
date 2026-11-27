<?php

use App\Domains\Identity\Catalog\SecurityEventCatalog;

it('expose les noms canoniques réellement émis par le domaine Identity', function (): void {
    expect(SecurityEventCatalog::options())->toBe([
        'login.succeeded' => 'Connexion réussie',
        'login.failed' => 'Échec de connexion',
        'logout.succeeded' => 'Déconnexion',
        'mfa.challenge.succeeded' => 'Validation MFA réussie',
        'mfa.challenge.failed' => 'Échec de validation MFA',
        'device.registered' => 'Nouvel appareil enregistré',
        'device.revoked' => 'Appareil révoqué',
    ]);
});

it('traduit les événements connus et conserve les événements historiques inconnus', function (): void {
    expect(SecurityEventCatalog::label('login.succeeded'))->toBe('Connexion réussie')
        ->and(SecurityEventCatalog::label('authentication.succeeded'))->toBe('authentication.succeeded')
        ->and(SecurityEventCatalog::label(null))->toBe('Événement inconnu');
});
