<?php

/**
 * Documentation du rollback applicatif CHAN-98, lot 3.
 */
$root = dirname(__DIR__, 3);
$docPath = $root.'/docs/development/application-rollback.md';
$runbookPath = $root.'/docs/development/application-rollback-runbook.md';

test('la documentation de rollback existe et contient les sections obligatoires', function () use ($docPath): void {
    expect(is_file($docPath))->toBeTrue();

    $contents = (string) file_get_contents($docPath);

    $requiredSections = [
        '## 1. Principes directeurs',
        '## 2. Périmètre exact',
        '## 3. Architecture et réutilisation de CHAN-97',
        '## 4. Prérequis',
        '## 5. Décision GO / NO-GO',
        '## 6. Compatibilité N/N-1 et attestation',
        '## 7. Workers, files et jobs',
        '## 8. Health check',
        '## 9. Traçabilité',
        '## 10. Interruptions et concurrence',
        '## 11. Différence avec une restauration de données',
        '## 12. Tests',
        '## 13. Limites et cas non couverts',
    ];

    $missing = array_values(array_filter(
        $requiredSections,
        fn (string $section): bool => ! str_contains($contents, $section)
    ));

    expect($missing)->toBe([]);
});

test('la documentation rappelle les interdictions et la nature manuelle du rollback', function () use ($docPath): void {
    $contents = (string) file_get_contents($docPath);

    expect($contents)
        ->toContain('**Un rollback applicatif ne restaure jamais la base de données.**')
        ->toContain('Aucun workflow, health check, déploiement ou script ne le déclenche automatiquement')
        ->toContain('Aucun argument `--force` n\'existe')
        ->toContain('`migrate:rollback`')
        ->toContain('bascule atomique')
        ->toContain('attestation de compatibilité N/N-1')
        ->toContain('Aucun retour automatique n\'est effectué')
        ->toContain('Les workers et files ne sont pas pilotés par le script');
});

test('le runbook de rollback contient la procédure opérateur complète', function () use ($runbookPath): void {
    expect(is_file($runbookPath))->toBeTrue();

    $contents = (string) file_get_contents($runbookPath);

    $requiredSections = [
        '## 1. Conventions',
        '## 2. Préflight',
        '## 3. Attestation de compatibilité N/N-1',
        '## 4. Contrôle à blanc',
        '## 5. Exécution',
        '## 6. Après le rollback',
        '## 7. Échec du health check après bascule',
        '## 8. Interruption',
        '## 9. Refus fréquents',
    ];

    $missing = array_values(array_filter(
        $requiredSections,
        fn (string $section): bool => ! str_contains($contents, $section)
    ));

    expect($missing)->toBe([]);

    expect($contents)
        ->toContain('Le rollback ne restaure jamais la base de données.')
        ->toContain('Ne jamais utiliser `migrate:rollback`')
        ->toContain('--confirm-workers-stopped')
        ->toContain('--confirm-queues-paused')
        ->toContain('--confirm-jobs-triaged');
});

test('le rollback est référencé depuis les documents existants', function () use ($root): void {
    $references = [
        $root.'/README.md',
        $root.'/docs/development/database-migrations.md',
        $root.'/docs/development/deployment-process.md',
    ];

    foreach ($references as $path) {
        $contents = (string) file_get_contents($path);

        expect(str_contains($contents, 'application-rollback.md'))
            ->toBeTrue("{$path} doit référencer application-rollback.md.");
    }
});

test('le workflow CI exécute les tests de rollback', function () use ($root): void {
    $workflow = (string) file_get_contents($root.'/.github/workflows/tests.yml');

    expect($workflow)->toContain('scripts/ops/tests/test-rollback.sh');
});
