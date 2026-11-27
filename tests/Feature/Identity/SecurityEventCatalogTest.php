<?php

use App\Domains\Identity\Catalog\SecurityEventCatalog;
use App\Domains\Identity\Catalog\SecurityEventChannel;

it('expose les noms canoniques réellement émis par le domaine Identity', function (): void {
    expect(SecurityEventCatalog::options())->toBe([
        'login.succeeded' => 'Connexion réussie',
        'login.failed' => 'Échec de connexion',
        'logout.succeeded' => 'Déconnexion',
        'mfa.challenge.succeeded' => 'Validation MFA réussie',
        'mfa.challenge.failed' => 'Échec de validation MFA',
        'device.registered' => 'Nouvel appareil enregistré',
        'device.revoked' => 'Appareil révoqué',
        'token.created' => 'Jeton API créé',
        'token.revoked' => 'Jeton API révoqué',
    ]);
});

it('traduit les événements connus et conserve les événements historiques inconnus', function (): void {
    expect(SecurityEventCatalog::label('login.succeeded'))->toBe('Connexion réussie')
        ->and(SecurityEventCatalog::label('token.created'))->toBe('Jeton API créé')
        ->and(SecurityEventCatalog::label('token.revoked'))->toBe('Jeton API révoqué')
        ->and(SecurityEventCatalog::label('authentication.succeeded'))->toBe('authentication.succeeded')
        ->and(SecurityEventCatalog::label(null))->toBe('Événement inconnu');
});

it('centralise les canaux autorisés et leurs libellés', function (): void {
    expect(SecurityEventChannel::values())->toBe(['web', 'api', 'filament'])
        ->and(SecurityEventChannel::options())->toBe([
            'web' => 'Web',
            'api' => 'API',
            'filament' => 'Filament',
        ]);
});
