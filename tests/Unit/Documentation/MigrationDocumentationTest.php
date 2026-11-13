<?php

$root = dirname(__DIR__, 3);

test('la documentation de migration existe et contient les sections obligatoires', function () use ($root): void {
    $path = $root.'/docs/development/database-migrations.md';

    expect(is_file($path))->toBeTrue();

    $contents = (string) file_get_contents($path);

    $requiredSections = [
        '## 1. Principes directeurs',
        '## 2. Audit initial du schéma',
        '## 3. Règle de compatibilité N/N-1',
        '## 4. Stratégie Expand / Migrate / Contract',
        '## 5. Politique d\'exécution',
        '## 6. Politique de rollback',
        '## 7. Conventions de rédaction',
        '## 8. Opérations interdites dans une migration automatique',
        '## 9. Règles de validation manuelle',
        '## 10. Procédures en cas d\'échec',
        '## 11. Critères autorisant une migration destructive différée',
        '## 12. Intégration avec le mécanisme de releases CHAN-97',
    ];

    $missing = array_values(array_filter(
        $requiredSections,
        fn (string $section): bool => ! str_contains($contents, $section)
    ));

    expect($missing)->toBe([]);
});

test('la documentation rappelle les règles absolues de compatibilité et de rollback', function () use ($root): void {
    $contents = (string) file_get_contents($root.'/docs/development/database-migrations.md');

    expect($contents)
        ->toContain('Un retour à la release précédente ne restaure jamais automatiquement la base de données.')
        ->toContain('Aucune migration n\'est exécutée automatiquement')
        ->toContain('Expand')
        ->toContain('Migrate')
        ->toContain('Contract');
});

test('le processus de deploiement reference la strategie de migrations', function () use ($root): void {
    $contents = (string) file_get_contents($root.'/docs/development/deployment-process.md');

    expect($contents)
        ->toContain('[`database-migrations.md`](database-migrations.md)')
        ->toContain('Un rollback applicatif ne restaure jamais la base de données.')
        ->toContain('Aucune migration n\'est exécutée par `deploy-staging`')
        ->toContain('migrate:fresh');
});
