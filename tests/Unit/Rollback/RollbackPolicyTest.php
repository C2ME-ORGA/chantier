<?php

/**
 * Gardes statiques du rollback applicatif CHAN-98, lot 3.
 */
$root = dirname(__DIR__, 3);
$ops = $root.'/scripts/ops';
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

test('le verrou est partagé avec le déploiement', function () use ($root, $ops): void {
    $rollback = (string) file_get_contents($ops.'/rollback.sh');
    $deploy = (string) file_get_contents($root.'/.github/scripts/deploy/remote-deploy.sh');
    $doc = (string) file_get_contents($root.'/docs/development/application-rollback.md');

    foreach ([$rollback, $deploy] as $contents) {
        expect($contents)
            ->toContain('.release-operation.lock')
            ->toContain('operation');
    }

    expect($deploy)
        ->toContain('acquire_operation_lock')
        ->toContain('release_operation_lock')
        ->toContain('mkdir -- "$lock_dir"')
        ->toContain('jeton différent')
        ->toContain('rollback.sh unlock --env')
        ->toContain('--confirm-stale-lock');

    expect($doc)
        ->toContain('partagé avec le déploiement')
        ->toContain('shared/.release-operation.lock');
});

test('la libération du verrou vérifie le jeton d appartenance', function () use ($root, $ops): void {
    $common = (string) file_get_contents($ops.'/lib/common.sh');
    $rollback = (string) file_get_contents($ops.'/rollback.sh');
    $deploy = (string) file_get_contents($root.'/.github/scripts/deploy/remote-deploy.sh');

    expect($common)
        ->toContain('C2ME_LOCK_TOKEN')
        ->toContain('C2ME_LOCK_INODE')
        ->toContain('C2ME_LOCK_OWNED')
        ->toContain('c2me_release_lock')
        ->toContain('jeton ou identité différents')
        ->toContain('c2me_guard_enter')
        ->toContain('flock -x')
        ->toContain('C2ME_REQUIRE_FLOCK')
        ->toContain('c2me_lock_write_metadata')
        ->toContain('c2me_remove_lock_if_owned')
        ->toContain('lien symbolique : libération refusée')
        ->not->toContain('C2ME_CLEANUP_PATHS+=("$lock_dir")')
        ->not->toContain('>"$lock_dir/token" 2>/dev/null || true');

    expect($deploy)
        ->toContain('operation_guard_enter')
        ->toContain('operation_lock_inode')
        ->toContain('write_operation_metadata')
        ->toContain('remove_operation_lock_if_owned')
        ->toContain('flock -x')
        ->toContain('jeton ou identité différents')
        ->not->toContain('>"$lock_dir/token" 2>/dev/null || true');

    expect($rollback)
        ->toContain('unlock')
        ->toContain('--confirm-stale-lock')
        ->toContain('c2me_release_stale_lock');
});

test('la preuve migrate:status est vérifiée par empreinte', function () use ($root, $ops): void {
    $validator = (string) file_get_contents($ops.'/lib/rollback-attestation.php');
    $runbook = (string) file_get_contents($root.'/docs/development/application-rollback-runbook.md');

    expect($validator)
        ->toContain('.migrate-status.txt')
        ->toContain('hash_equals')
        ->toContain('rollback_attestation_validate_proof')
        ->toContain('Preuve migrate:status absente')
        ->toContain('environnement incohérent')
        ->toContain('release incohérente')
        ->toContain('base incohérente')
        ->toContain('captured_at');

    expect($runbook)
        ->toContain('C2ME-MIGRATE-STATUS-PROOF')
        ->toContain('.migrate-status.txt')
        ->toContain('sha256sum "$PROOF"');
});

test('le dry-run ne modifie aucun état et sa sortie est séparée', function () use ($root, $ops): void {
    $contents = (string) file_get_contents($ops.'/rollback.sh');
    $doc = (string) file_get_contents($root.'/docs/development/application-rollback.md');

    expect($contents)
        ->toContain("printf 'PLAN=ok\\n'")
        ->toContain("printf 'MODE=dry-run\\n'")
        ->toContain("printf 'VALIDATION=ok\\n'")
        ->toContain("printf 'Aucune modification effectuée (--dry-run).\\n'")
        ->not->toContain("printf 'PLAN=ok\\nENVIRONMENT=")
        ->not->toContain("'planned'");

    expect($doc)
        ->toContain('`--dry-run` n\'écrit ni journal, ni verrou, ni fichier temporaire');
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
