<?php

/**
 * Gardes statiques des scripts et documents de sauvegarde CHAN-98, lot 2.
 *
 * Ces tests ne prouvent pas l'exécution réelle : ils empêchent la régression
 * des règles de sécurité validées dans la conception.
 */
$root = dirname(__DIR__, 3);
$ops = $root.'/scripts/ops';

/**
 * @return list<string>
 */
function chan98OpsFiles(string $directory): array
{
    $files = [];

    if (! is_dir($directory)) {
        return $files;
    }

    $root = dirname(__DIR__, 3);
    $testsDirectory = $root.'/scripts/ops/tests';

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS)
    );

    foreach ($iterator as $file) {
        if (! $file->isFile()) {
            continue;
        }

        $path = $file->getPathname();

        if (str_starts_with($path, $testsDirectory)) {
            continue;
        }

        if (in_array($file->getExtension(), ['sh', 'php', 'json'], true)) {
            $files[] = $path;
        }
    }

    sort($files);

    return $files;
}

test('les scripts d exploitation sont présents et localisés hors des scripts de déploiement', function () use ($root, $ops): void {
    $expected = [
        $ops.'/backup.sh',
        $ops.'/restore.sh',
        $ops.'/lib/common.sh',
        $ops.'/lib/manifest.php',
        $ops.'/schema/backup-manifest.schema.json',
        $ops.'/tests/test-backup-restore.sh',
    ];

    foreach ($expected as $path) {
        expect(is_file($path))->toBeTrue("Fichier attendu absent : {$path}");
    }

    $deployScripts = glob($root.'/.github/scripts/*/*.sh') ?: [];

    foreach ($deployScripts as $path) {
        expect(basename($path))->not->toStartWith('backup-');
        expect(basename($path))->not->toStartWith('restore-');
    }
});

test('aucun script ne peut appliquer de permissions 777 ni conserver les UID/GID d origine', function () use ($ops): void {
    $violations = [];

    foreach (chan98OpsFiles($ops) as $file) {
        $contents = (string) file_get_contents($file);

        if (preg_match('/chmod\s+(?:-R\s+)?0?777\b/', $contents) === 1) {
            $violations[] = basename($file).' : chmod 777 détecté.';
        }

        if (preg_match('/umask\s+0{3,4}\b/', $contents) === 1) {
            $violations[] = basename($file).' : umask permissif détecté.';
        }
    }

    $backup = (string) file_get_contents($ops.'/backup.sh');
    $restore = (string) file_get_contents($ops.'/restore.sh');

    if (str_contains($backup, '--same-owner') || str_contains($restore, '--same-owner')) {
        $violations[] = '--same-owner ne doit jamais être utilisé.';
    }

    if (! str_contains($restore, '--no-same-owner')) {
        $violations[] = 'la restauration doit extraire avec --no-same-owner.';
    }

    if (! str_contains($restore, 'chown -R')) {
        $violations[] = 'la restauration doit remapper explicitement l appartenance.';
    }

    expect($violations)->toBe([]);
});

test('la sauvegarde exige le mode maintenance et la vérification des workers et du cron', function () use ($ops): void {
    $contents = (string) file_get_contents($ops.'/backup.sh');
    $common = (string) file_get_contents($ops.'/lib/common.sh');

    expect($common)->toContain('framework/down');

    expect($contents)
        ->toContain('C2ME_MAINTENANCE_MARKER')
        ->toContain('--confirm-workers-stopped')
        ->toContain('--confirm-scheduler-disabled')
        ->toContain('C2ME_SUPERVISOR_PROGRAM')
        ->toContain('queue:work')
        ->toContain('schedule:run')
        ->toContain('assert_maintenance_mode')
        ->toContain('assert_workers_stopped')
        ->toContain('assert_scheduler_disabled');
});

test('la sauvegarde refuse les tables non InnoDB et les liens symboliques', function () use ($ops): void {
    $contents = (string) file_get_contents($ops.'/backup.sh');

    expect($contents)
        ->toContain('assert_database_innodb')
        ->toContain("engine <> 'InnoDB'")
        ->toContain('assert_no_symlinks_or_specials')
        ->toContain('inventory_compare')
        ->toContain('changé pendant la sauvegarde');
});

test('la clé privée age ne peut jamais être déposée sur le serveur', function () use ($ops): void {
    $lib = (string) file_get_contents($ops.'/lib/common.sh');
    $backup = (string) file_get_contents($ops.'/backup.sh');
    $restore = (string) file_get_contents($ops.'/restore.sh');

    foreach ([$lib, $backup, $restore] as $contents) {
        expect($contents)->not->toContain('age-keygen');
    }

    expect($backup)
        ->toContain('assert_private_key_absent')
        ->toContain('keys/recipient.pub')
        ->not->toContain('--identity');

    expect($restore)
        ->toContain('assert_identity_file')
        ->toContain('--identity')
        ->toContain('c2me_assert_not_forbidden_path');

    expect($lib)->toContain('--recipients-file');
});

test('la restauration cible une base unique et refuse une cible préexistante', function () use ($ops): void {
    $contents = (string) file_get_contents($ops.'/restore.sh');

    expect($contents)
        ->toContain('^chantier_restore_[0-9]{8}_[0-9a-f]{8}$')
        ->toContain('la base cible existe déjà')
        ->toContain('information_schema.SCHEMATA')
        ->toContain('le répertoire cible existe déjà')
        ->toContain('ne doit jamais être la base applicative')
        ->toContain("'chantier_production'")
        ->toContain('c2me_assert_not_forbidden_path');
});

test('la restauration vérifie les permissions finales sans jamais utiliser 777', function () use ($ops): void {
    $contents = (string) file_get_contents($ops.'/restore.sh');

    expect($contents)
        ->toContain('assert_final_permissions')
        ->toContain('-perm -0002')
        ->toContain('chmod 2770')
        ->toContain('chmod 0640')
        ->toContain('c2me_setgid_supported');

    expect(preg_match('/chmod\s+(?:-R\s+)?0?777\b/', $contents))->toBe(0);
});

test('la restauration décompresse avant import et refuse les archives dangereuses', function () use ($ops): void {
    $contents = (string) file_get_contents($ops.'/restore.sh');
    $common = (string) file_get_contents($ops.'/lib/common.sh');

    expect($common)->toContain('c2me_decompress');

    expect($contents)
        ->toContain('artifact_compression')
        ->toContain('assert_dump_safe')
        ->toContain('assert_archive_safe')
        ->toContain('assert_inventory_safe')
        ->toContain('traversée de répertoire dans l archive')
        ->toContain('hors du périmètre app/private ou app/public')
        ->toContain('CREATE|DROP)[[:space:]]+DATABASE');
});

test('le rapport de restauration n est jamais présenté comme signé', function () use ($root, $ops): void {
    $restore = (string) file_get_contents($ops.'/restore.sh');
    $doc = (string) file_get_contents($root.'/docs/development/backup-restore.md');
    $runbook = (string) file_get_contents($root.'/docs/development/backup-restore-runbook.md');

    expect($restore)
        ->toContain('"signature": "none"')
        ->toContain('REPORT_SIGNED=false')
        ->toContain('chain.jsonl');

    expect($doc)->toContain('n\'est **pas signé** au sens cryptographique');
    expect($runbook)->toContain('Il n\'est **pas signé** cryptographiquement');
});

test('aucune automatisation de cron, de service ou de migration n est introduite', function () use ($ops): void {
    $violations = [];

    foreach (chan98OpsFiles($ops) as $file) {
        $contents = (string) file_get_contents($file);
        $name = basename($file);

        $patterns = [
            '/\bcrontab\s+-[a-z]/i' => 'modification de crontab',
            '/\bsystemctl\s+(?:enable|start|stop|disable)/i' => 'gestion de service systemd',
            '/\bsupervisorctl\s+(?:start|stop|update|restart)/i' => 'gestion de worker Supervisor',
            '/\bartisan\s+migrate\b/i' => 'exécution de migration',
            '/\bdocker\s+(?:run|compose)/i' => 'orchestration de conteneur',
        ];

        foreach ($patterns as $pattern => $label) {
            if (preg_match($pattern, $contents) === 1) {
                $violations[] = "{$name} : {$label} détectée.";
            }
        }
    }

    expect($violations)->toBe([]);
});

test('les documents ne contiennent aucun secret ni commande destructrice de production', function () use ($root): void {
    $documents = [
        $root.'/docs/development/backup-restore.md',
        $root.'/docs/development/backup-restore-runbook.md',
    ];

    foreach ($documents as $path) {
        $contents = (string) file_get_contents($path);

        expect($contents)
            ->not->toContain('BEGIN OPENSSH PRIVATE KEY')
            ->not->toContain('BEGIN AGE SECRET KEY')
            ->not->toContain('DB_PASSWORD=')
            ->not->toContain('AGE-SECRET-KEY-1')
            ->not->toContain('migrate:fresh')
            ->not->toContain('migrate:rollback');
    }
});

test('la documentation interdit la restauration sur les bases actives et la perte de serveur est un NO-GO', function () use ($root): void {
    $doc = (string) file_get_contents($root.'/docs/development/backup-restore.md');

    expect($doc)
        ->toContain('ne touche **jamais** la base active')
        ->toContain('perte complète du serveur est un **NO-GO**')
        ->toContain('Aucune copie hors site')
        ->toContain('RTO démontré | **aucun**');
});

test('le controle d integration continue execute les tests des scripts d exploitation', function () use ($root): void {
    $workflow = (string) file_get_contents($root.'/.github/workflows/tests.yml');

    expect($workflow)->toContain('scripts/ops/tests/test-backup-restore.sh');
});
