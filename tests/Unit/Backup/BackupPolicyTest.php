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

test('la restauration décompresse avant import et inspecte les archives', function () use ($ops): void {
    $contents = (string) file_get_contents($ops.'/restore.sh');
    $common = (string) file_get_contents($ops.'/lib/common.sh');
    $inspector = (string) file_get_contents($ops.'/lib/tar-inspect.php');

    expect($common)->toContain('c2me_decompress');

    expect($contents)
        ->toContain('artifact_compression')
        ->toContain('tar-inspect.php')
        ->toContain('assert_dump_safe')
        ->toContain('assert_archive_safe')
        ->toContain('assert_inventory_safe')
        ->toContain('files.file_count')
        ->toContain('files.total_bytes')
        ->toContain('CREATE|DROP)[[:space:]]+DATABASE');

    expect($inspector)
        ->toContain('lien symbolique')
        ->toContain('lien physique')
        ->toContain('FIFO')
        ->toContain('périphérique')
        ->toContain('traversée ou composant de chemin invalide')
        ->toContain('app/(private|public)')
        ->toContain('checksum d en-tête TAR invalide');

    expect(is_file($ops.'/tests/make-tar-fixture.php'))->toBeTrue();
});

test('les signaux nettoient puis terminent le processus avec un code explicite', function () use ($ops): void {
    $common = (string) file_get_contents($ops.'/lib/common.sh');

    expect($common)
        ->toContain('c2me_on_signal')
        ->toContain('trap - EXIT HUP INT TERM')
        ->toContain('exit "$code"');

    foreach (['backup.sh', 'restore.sh'] as $script) {
        $contents = (string) file_get_contents($ops.'/'.$script);

        expect($contents)
            ->toContain('trap c2me_cleanup EXIT')
            ->toContain("trap 'c2me_on_signal 129' HUP")
            ->toContain("trap 'c2me_on_signal 130' INT")
            ->toContain("trap 'c2me_on_signal 143' TERM")
            ->not->toContain('trap c2me_cleanup EXIT HUP INT TERM');
    }
});

test('un verrou orphelin n est jamais supprimé automatiquement', function () use ($root, $ops): void {
    $common = (string) file_get_contents($ops.'/lib/common.sh');
    $backup = (string) file_get_contents($ops.'/backup.sh');
    $restore = (string) file_get_contents($ops.'/restore.sh');
    $doc = (string) file_get_contents($root.'/docs/development/backup-restore.md');
    $runbook = (string) file_get_contents($root.'/docs/development/backup-restore-runbook.md');

    expect($common)
        ->toContain('c2me_lock_pid_alive')
        ->toContain('kill -0')
        ->toContain('verrou orphelin')
        ->toContain('c2me_release_stale_lock');

    expect($backup)->toContain('--confirm-stale-lock');
    expect($restore)->toContain('--confirm-stale-lock');

    expect($doc)->toContain('### 10.4 Verrou orphelin');
    expect($runbook)->toContain('### 5.1 Verrou orphelin');
});

test('les archives sont créées sans ACL ni xattrs et inspectées strictement', function () use ($ops): void {
    $backup = (string) file_get_contents($ops.'/backup.sh');
    $inspector = (string) file_get_contents($ops.'/lib/tar-inspect.php');

    expect($backup)
        ->not->toContain("'--acls'")
        ->not->toContain("'--xattrs'")
        ->toContain('--format=gnu')
        ->toContain('c2me_run "$C2ME_TAR_BIN"');

    expect($inspector)
        ->toContain('tar_assert_supported_format')
        ->toContain('TAR_PAX_ALLOWED_KEYS')
        ->toContain("['path', 'linkpath']")
        ->toContain('en-tête PAX global g interdit')
        ->toContain('clé PAX non autorisée')
        ->toContain('format TAR non pris en charge')
        ->toContain('en-tête PAX malformé')
        ->toContain('métadonnées PAX et GNU contradictoires')
        ->toContain('en-tête GNU K (lien long) refusé')
        ->toContain('métadonnées TAR sans entrée cible');
});

test('les processus enfants sont terminés avant la suppression de la zone de travail et du verrou', function () use ($ops): void {
    $common = (string) file_get_contents($ops.'/lib/common.sh');
    $backup = (string) file_get_contents($ops.'/backup.sh');
    $restore = (string) file_get_contents($ops.'/restore.sh');

    expect($common)
        ->toContain('C2ME_CHILD_PIDS')
        ->toContain('c2me_run')
        ->toContain('c2me_terminate_children')
        ->toContain('c2me_descendant_pids')
        ->toContain('kill -TERM')
        ->toContain('kill -KILL');

    $signalHandler = substr($common, (int) strpos($common, 'c2me_on_signal()'));

    $terminatePosition = strpos($signalHandler, 'c2me_terminate_children');
    $cleanupPosition = strpos($signalHandler, 'c2me_cleanup');

    expect($terminatePosition)->not->toBeFalse();
    expect($cleanupPosition)->not->toBeFalse();
    expect($terminatePosition)->toBeLessThan($cleanupPosition);

    expect($backup)->toContain('c2me_run "$C2ME_DB_DUMP_BIN"');

    expect($restore)
        ->toContain('c2me_run "$C2ME_MYSQL_BIN"')
        ->toContain('c2me_run "$C2ME_TAR_BIN"');

    expect($common)
        ->toContain('c2me_run "$C2ME_AGE_BIN"')
        ->toContain('c2me_run "$C2ME_ZSTD_BIN"')
        ->toContain('c2me_run "$C2ME_GZIP_BIN"');
});

test('le verrou est associé à l hôte et refuse une libération distante', function () use ($root, $ops): void {
    $common = (string) file_get_contents($ops.'/lib/common.sh');
    $doc = (string) file_get_contents($root.'/docs/development/backup-restore.md');

    expect($common)
        ->toContain('lock_host')
        ->toContain('verrou détenu par un autre hôte')
        ->toContain('verrou sans hôte identifiable')
        ->toContain("appartient à l'hôte");

    expect($doc)
        ->toContain('un PID distant ne constitue jamais une preuve de processus mort')
        ->toContain('un verrou provenant d\'un autre hôte ne peut pas être libéré localement');
});

test('files.total_bytes ne somme que les fichiers réguliers', function () use ($ops): void {
    $contents = (string) file_get_contents($ops.'/backup.sh');

    expect($contents)->toContain('$2 == "f" {sum += $3}');
});

test('la détection des clés privées est documentée comme heuristique', function () use ($root, $ops): void {
    $doc = (string) file_get_contents($root.'/docs/development/backup-restore.md');
    $backup = (string) file_get_contents($ops.'/backup.sh');

    expect($backup)
        ->toContain('age-identity*')
        ->toContain('*.agekey')
        ->toContain('keys.txt');

    expect($doc)
        ->toContain('### 8.5 Détection d\'une clé privée déposée par erreur')
        ->toContain('garde-fou heuristique, pas une preuve d\'absence')
        ->toContain('ne lit pas le contenu des fichiers');
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
