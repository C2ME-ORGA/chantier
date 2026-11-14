<?php

/**
 * Gardes statiques du rollback applicatif CHAN-98, lot 3.
 */
$root = dirname(__DIR__, 3);
$scriptPath = $root.'/scripts/ops/rollback.sh';
$attestationPath = $root.'/scripts/ops/lib/rollback-attestation.php';

test('le script de rollback et le validateur existent', function () use ($scriptPath, $attestationPath): void {
    expect(is_file($scriptPath))->toBeTrue();
    expect(is_file($attestationPath))->toBeTrue();
    expect(is_file(dirname($scriptPath).'/tests/test-rollback.sh'))->toBeTrue();
});

test('le rollback n exécute ni migration, ni accès base, ni restauration', function () use ($scriptPath): void {
    $contents = (string) file_get_contents($scriptPath);

    foreach ([
        '/\bartisan\s+migrate\b/i',
        '/\bmigrate:(?:rollback|fresh|refresh|reset)\b/i',
        '/\bdb:wipe\b/i',
        '/\b(?:mariadb|mysql|mysqldump)\b/i',
        '/\bpg_restore\b/i',
        '/\brsync\b/i',
        '/\bsudo\b/i',
    ] as $pattern) {
        expect(preg_match($pattern, $contents))->toBe(0);
    }

    expect($contents)
        ->toContain('Aucune migration, aucune restauration de base')
        ->not->toContain('activate_release "$source_dir"');
});

test('le rollback ne modifie ni .env, ni le stockage, ni les jobs', function () use ($scriptPath): void {
    $contents = (string) file_get_contents($scriptPath);

    expect($contents)
        ->not->toMatch('/>>?\s*"?\$shared\/\.env/')
        ->not->toMatch('/>>?\s*"?\$C2ME_STORAGE_ROOT/')
        ->not->toContain('queue:flush')
        ->not->toContain('queue:clear')
        ->not->toContain('failed_jobs')
        ->not->toContain('cache:clear');
});

test('le rollback refuse --force et exige les confirmations', function () use ($scriptPath): void {
    $contents = (string) file_get_contents($scriptPath);

    expect($contents)
        ->not->toMatch('/--force\)/')
        ->not->toContain('force=1')
        ->toContain('--confirm-workers-stopped')
        ->toContain('--confirm-queues-paused')
        ->toContain('--confirm-jobs-triaged')
        ->toContain('--schema-attestation')
        ->toContain('l option --schema-attestation est obligatoire');
});

test('le rollback bascule current de manière atomique', function () use ($scriptPath): void {
    $contents = (string) file_get_contents($scriptPath);

    expect($contents)
        ->toContain('ln -sfn "$target_dir" "$tmp_link"')
        ->toContain('mv -Tf "$tmp_link" "$current_link"')
        ->toContain('mask_signals')
        ->toContain('unmask_signals')
        ->toContain('c2me_realpath')
        ->toContain('releases');

    expect(substr_count($contents, 'activate_release'))->toBe(2);
});

test('le rollback est tracé, verrouillé et interrompable', function () use ($scriptPath): void {
    $contents = (string) file_get_contents($scriptPath);

    expect($contents)
        ->toContain('rollback.log')
        ->toContain('operation_id')
        ->toContain('current_before')
        ->toContain('current_after')
        ->toContain('schema_attestation_sha256')
        ->toContain('"health"')
        ->toContain('"result"')
        ->toContain('c2me_acquire_lock')
        ->toContain('rollback_on_signal 143 TERM')
        ->toContain('c2me_terminate_children');
});

test('le rollback vérifie la concurrence et l état des workers', function () use ($scriptPath): void {
    $contents = (string) file_get_contents($scriptPath);

    expect($contents)
        ->toContain('.incoming-*')
        ->toContain('déploiement en cours')
        ->toContain('queue:work|queue:listen|horizon')
        ->toContain('C2ME_SUPERVISOR_PROGRAM')
        ->toContain('assert_current_unchanged');
});

test('aucun workflow ne déclenche automatiquement le rollback', function () use ($root): void {
    $workflowDirectory = $root.'/.github/workflows';
    $files = glob($workflowDirectory.'/*.yml') ?: [];

    expect($files)->not->toBeEmpty();

    $violations = [];

    foreach ($files as $file) {
        $contents = (string) file_get_contents($file);

        if (str_contains($contents, 'scripts/ops/rollback.sh')) {
            $violations[] = basename($file);
        }
    }

    expect($violations)->toBe([]);
});

test('le workflow CI exécute les tests de rollback', function () use ($root): void {
    $workflow = (string) file_get_contents($root.'/.github/workflows/tests.yml');

    expect($workflow)->toContain('scripts/ops/tests/test-rollback.sh');
});
