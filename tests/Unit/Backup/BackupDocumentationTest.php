<?php

/**
 * Documentation de sauvegarde et de restauration CHAN-98, lot 2.
 *
 * Ces tests sont statiques : ils vérifient la présence des règles et des
 * documents, pas leur exécution réelle.
 */
$root = dirname(__DIR__, 3);
$docPath = $root.'/docs/development/backup-restore.md';
$runbookPath = $root.'/docs/development/backup-restore-runbook.md';

test('la documentation de sauvegarde existe et contient les sections obligatoires', function () use ($docPath): void {
    expect(is_file($docPath))->toBeTrue();

    $contents = (string) file_get_contents($docPath);

    $requiredSections = [
        '## 1. Principes directeurs',
        '## 2. Inventaire des données persistantes',
        '## 3. Définition d\'une sauvegarde valide',
        '## 4. Cohérence entre la base et les fichiers',
        '## 5. Sauvegarde de la base de données',
        '## 6. Sauvegarde des fichiers',
        '## 7. Jeu de sauvegarde, nommage et manifeste',
        '## 8. Chiffrement, stockage et permissions',
        '## 9. Contrôle d\'intégrité',
        '## 10. Rétention et protection contre la suppression',
        '## 11. RPO, RTO et fréquences',
        '## 12. Restauration isolée',
        '## 13. Rapport de restauration et conservation des preuves',
        '## 14. Checklist GO / NO-GO',
        '## 15. Intégration avec CHAN-97 et le lot 1',
        '## 16. Tests et contrôles',
        '## 17. Décisions, prérequis et limites',
        '## 18. Références',
    ];

    $missing = array_values(array_filter(
        $requiredSections,
        fn (string $section): bool => ! str_contains($contents, $section)
    ));

    expect($missing)->toBe([]);
});

test('la documentation affirme les règles de sécurité et de cohérence obligatoires', function () use ($docPath): void {
    $contents = (string) file_get_contents($docPath);

    expect($contents)
        ->toContain('un dump de base seul n\'est pas une sauvegarde complète')
        ->toContain('Le mode maintenance Laravel **ne suffit pas**')
        ->toContain('L\'inventaire et l\'archive doivent porter sur **le même état**')
        ->toContain('Le serveur ne détient que la **clé publique**')
        ->toContain('n\'est **pas signé** au sens cryptographique')
        ->toContain('Aucun mode `777` n\'est jamais appliqué')
        ->toContain('chantier_restore_<AAAAMMJJ>_<hex8>')
        ->toContain('RTO démontré')
        ->toContain('perte complète du serveur est un **NO-GO**')
        ->toContain('Aucune sauvegarde réelle n\'a été produite')
        ->toContain('aucune restauration réelle n\'a été réalisée');
});

test('la documentation distingue RPO cible, RTO cible et RTO démontré', function () use ($docPath): void {
    $contents = (string) file_get_contents($docPath);

    expect($contents)
        ->toContain('**Cible**, pas une garantie')
        ->toContain('| RTO cible |')
        ->toContain('| RTO démontré | **aucun** |');
});

test('la documentation impose le jeu complet quotidien et exclut les secrets', function () use ($docPath): void {
    $contents = (string) file_get_contents($docPath);

    expect($contents)
        ->toContain('Chaque jour produit **un jeu complet**')
        ->toContain('Aucun secret dans une sauvegarde métier')
        ->toContain('les utilisateurs et droits MySQL (export séparé)')
        ->toContain('procédure de conservation séparée');
});

test('le runbook opérateur existe et contient les étapes de sauvegarde et de restauration', function () use ($runbookPath): void {
    expect(is_file($runbookPath))->toBeTrue();

    $contents = (string) file_get_contents($runbookPath);

    $requiredSteps = [
        '## 2. Sauvegarde',
        '## 2.2 Arrêt des écritures',
        '## 2.3 Production du jeu complet',
        '## 2.4 Contrôle du jeu',
        '## 2.5 Reprise du service',
        '## 4. Restauration isolée',
        '## 4.2 Restauration de la base',
        '## 4.3 Restauration des fichiers',
        '## 4.4 Vérifications',
        '## 4.5 Rapport et clôture',
        '## 5. Rétention',
        '## 7. En cas d\'échec',
    ];

    $missing = array_values(array_filter(
        $requiredSteps,
        fn (string $step): bool => ! str_contains($contents, $step)
    ));

    expect($missing)->toBe([]);

    expect($contents)
        ->toContain('Ne jamais écraser, déplacer ou supprimer une sauvegarde existante.')
        ->toContain('Ne jamais exécuter une restauration sur `chantier_production` ou `chantier_staging`.')
        ->toContain('Ne jamais copier la clé privée `age` sur le serveur.')
        ->toContain('Ne jamais déclarer une restauration réussie sans manifeste, checksums, journaux et rapport.');
});

test('la documentation couvre les signaux, l inspection TAR et les verrous orphelins', function () use ($docPath): void {
    $contents = (string) file_get_contents($docPath);

    expect($contents)
        ->toContain('### 8.5 Détection d\'une clé privée déposée par erreur')
        ->toContain('### 10.4 Verrou orphelin')
        ->toContain('`SIGKILL`')
        ->toContain('tar-inspect.php')
        ->toContain('lien physique')
        ->toContain('FIFO')
        ->toContain('garde-fou heuristique, pas une preuve d\'absence')
        ->toContain('Aucune extraction ne commence si une seule entrée est interdite')
        ->toContain('Formats acceptés : **ustar POSIX** et **GNU**')
        ->toContain('PAX global')
        ->toContain('`GNU.sparse.*`')
        ->toContain('un PID distant ne constitue jamais une preuve de processus mort')
        ->toContain('identité d\'hôte locale doit être **stable, unique et non réservée**')
        ->toContain('sans limite de 512 Kio')
        ->toContain('`gzip -d` et `zstd -d` bloqués');
});

test('le runbook documente la récupération d un verrou orphelin', function () use ($runbookPath): void {
    $contents = (string) file_get_contents($runbookPath);

    expect($contents)
        ->toContain('### 5.1 Verrou orphelin')
        ->toContain('unlock --env "$ENV" --confirm-stale-lock')
        ->toContain('Ne jamais supprimer `.lock` par un `rm -rf` improvisé');
});

test('la documentation est référencée depuis les documents existants', function () use ($root): void {
    $references = [
        $root.'/README.md',
        $root.'/docs/development/environments.md',
        $root.'/docs/development/deployment-process.md',
        $root.'/docs/development/database-migrations.md',
    ];

    foreach ($references as $path) {
        $contents = (string) file_get_contents($path);

        expect(str_contains($contents, 'backup-restore.md'))
            ->toBeTrue("{$path} doit référencer backup-restore.md.");
    }
});
