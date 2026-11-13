<?php

/**
 * Manifeste de sauvegarde CHAN-98, lot 2.
 *
 * Ces tests valident le validateur et le schéma, pas une sauvegarde réelle.
 */
$root = dirname(__DIR__, 3);
$libPath = $root.'/scripts/ops/lib/manifest.php';
$schemaPath = $root.'/scripts/ops/schema/backup-manifest.schema.json';

require_once $libPath;

/**
 * @param  array<string, mixed>  $overrides
 * @return array<string, mixed>
 */
function chan98ValidManifest(array $overrides = []): array
{
    $timestamp = '20261113T020000Z';

    $manifest = [
        'schema_version' => 1,
        'backup_set_id' => 'set-production-'.$timestamp.'-a1b2c3d4',
        'environment' => 'production',
        'scope' => 'full',
        'restorable_as_complete' => true,
        'status' => 'complete',
        'created_at' => '2026-11-13T02:00:00Z',
        'completed_at' => '2026-11-13T02:04:00Z',
        'trigger' => 'scheduled',
        'consistency' => [
            'mode' => 'maintenance',
            'maintenance_marker' => true,
            'workers_verified' => true,
            'scheduler_verified' => true,
            'file_changes_detected' => false,
            'started_at' => '2026-11-13T02:00:10Z',
            'finished_at' => '2026-11-13T02:03:50Z',
            'downtime_seconds' => 220,
        ],
        'release' => [
            'version' => 'v0.1.0',
            'commit_sha' => '8742e19ba18a48e3297792a7ee4058e0ad71497a',
            'tree_sha' => '1111111111111111111111111111111111111111',
        ],
        'database' => [
            'name' => 'chantier_production',
            'server_version' => '10.11.14-MariaDB',
            'tool' => 'mariadb-dump',
            'tool_version' => '10.11.14-MariaDB',
            'options_sha256' => str_repeat('a', 64),
            'tables' => 9,
            'rows' => 1234,
            'non_innodb_tables' => [],
        ],
        'files' => [
            'included_roots' => ['app/private', 'app/public'],
            'exclusions' => ['framework/', 'logs/', '*.part', '*.partial'],
            'file_count' => 12,
            'total_bytes' => 4096,
            'inventory_sha256' => str_repeat('b', 64),
        ],
        'artifacts' => [
            [
                'kind' => 'database',
                'name' => 'db-production-'.$timestamp.'-v0.1.0-8742e19-scheduled.sql.zst.age',
                'bytes' => 2048,
                'sha256' => str_repeat('c', 64),
                'compression' => 'zstd',
                'encryption' => [
                    'tool' => 'age',
                    'recipient' => 'age1'.str_repeat('q', 58),
                ],
            ],
            [
                'kind' => 'files',
                'name' => 'files-production-'.$timestamp.'-v0.1.0-8742e19-scheduled.tar.gz.age',
                'bytes' => 4096,
                'sha256' => str_repeat('d', 64),
                'compression' => 'gzip',
                'encryption' => [
                    'tool' => 'age',
                    'recipient' => 'age1'.str_repeat('q', 58),
                ],
            ],
        ],
        'retention' => [
            'class' => 'daily',
            'delete_after' => '2026-12-13T02:00:00Z',
        ],
        'host' => [
            'name' => 'serveur-c2me-01',
            'operator' => 'c2me-deploy-production',
        ],
    ];

    return array_replace($manifest, $overrides);
}

test('un manifeste complet valide est accepté', function (): void {
    expect(backup_manifest_validate_array(chan98ValidManifest()))->toBe([]);
});

test('un jeu database-only est accepté mais jamais restaurable comme complet', function (): void {
    $manifest = chan98ValidManifest([
        'scope' => 'database-only',
        'restorable_as_complete' => false,
        'files' => null,
        'artifacts' => [
            [
                'kind' => 'database',
                'name' => 'db-production-20261113T020000Z-v0.1.0-8742e19-manual.sql.gz.age',
                'bytes' => 2048,
                'sha256' => str_repeat('c', 64),
                'compression' => 'gzip',
                'encryption' => ['tool' => 'age', 'recipient' => 'age1'.str_repeat('q', 58)],
            ],
        ],
        'trigger' => 'manual',
    ]);

    expect(backup_manifest_validate_array($manifest))->toBe([]);

    $manifest['restorable_as_complete'] = true;

    expect(backup_manifest_validate_array($manifest))
        ->toContain('Un jeu database-only ne doit jamais porter restorable_as_complete: true.');
});

test('un jeu full sans artefact fichiers est refusé', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['artifacts'] = [$manifest['artifacts'][0]];

    expect(backup_manifest_validate_array($manifest))
        ->toContain('Un jeu full doit contenir exactement un artefact files.');
});

test('un identifiant de jeu incohérent avec l environnement est refusé', function (): void {
    $manifest = chan98ValidManifest([
        'backup_set_id' => 'set-staging-20261113T020000Z-a1b2c3d4',
    ]);

    expect(backup_manifest_validate_array($manifest))
        ->toContain('backup_set_id ne correspond pas à environment.');
});

test('une base incohérente avec l environnement est refusée', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['database']['name'] = 'chantier_staging';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('database.name doit valoir chantier_production pour l\'environnement déclaré.');
});

test('une table non InnoDB interdit le manifeste', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['database']['non_innodb_tables'] = ['legacy_attachments'];

    expect(backup_manifest_validate_array($manifest))
        ->toContain('database.non_innodb_tables doit être vide : un dump à chaud non cohérent est interdit.');
});

test('une modification de fichier pendant l opération invalide le manifeste', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['consistency']['file_changes_detected'] = true;

    expect(backup_manifest_validate_array($manifest))
        ->toContain('consistency.file_changes_detected doit être false.');
});

test('un worker non vérifié invalide le manifeste', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['consistency']['workers_verified'] = false;

    expect(backup_manifest_validate_array($manifest))
        ->toContain('consistency.workers_verified doit être true : la cohérence n\'est pas démontrée.');
});

test('le mode maintenance est obligatoire', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['consistency']['mode'] = 'online';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('consistency.mode doit valoir maintenance.');
});

test('un checksum invalide est refusé', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['artifacts'][0]['sha256'] = 'xyz';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('artifacts[0].sha256 doit être un SHA-256 hexadécimal.');
});

test('un nom d artefact avec traversée de chemin est refusé', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['artifacts'][0]['name'] = '../db-production-20261113T020000Z-v0.1.0-8742e19-scheduled.sql.zst.age';

    $errors = backup_manifest_validate_array($manifest);

    expect($errors)->toContain('artifacts[0].name doit être un nom de fichier simple.');
});

test('un nom d artefact sans horodatage de jeu est refusé', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['artifacts'][0]['name'] = 'db-production-20250101T000000Z-v0.1.0-8742e19-scheduled.sql.zst.age';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('artifacts[0].name ne reprend pas l\'horodatage du jeu.');
});

test('un artefact non chiffré est refusé', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['artifacts'][0]['encryption']['tool'] = 'none';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('artifacts[0].encryption.tool doit valoir age.');
});

test('aucun secret ni clé privée ne peut apparaître dans le manifeste', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['artifacts'][0]['encryption']['private_key'] = 'contenu-interdit';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('Clé interdite dans le manifeste : artifacts.0.encryption.private_key.');

    $manifest = chan98ValidManifest();
    $manifest['host']['operator'] = "-----BEGIN OPENSSH PRIVATE KEY-----\ncontenu";

    expect(backup_manifest_validate_array($manifest))
        ->toContain('Contenu de clé privée détecté dans le manifeste : host.operator.');
});

test('un horodatage non UTC ou inexistant est refusé', function (): void {
    $manifest = chan98ValidManifest();
    $manifest['created_at'] = '2026-02-31T02:00:00Z';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('created_at doit respecter le format UTC YYYY-MM-DDTHH:MM:SSZ.');

    $manifest = chan98ValidManifest();
    $manifest['completed_at'] = '2026-11-13T01:00:00Z';

    expect(backup_manifest_validate_array($manifest))
        ->toContain('completed_at doit être postérieur ou égal à created_at.');
});

test('le validateur de fichier refuse un JSON invalide, un fichier absent et un objet vide', function (): void {
    $directory = sys_get_temp_dir().'/chan98-manifest-'.bin2hex(random_bytes(4));
    mkdir($directory, 0700, true);

    $invalid = $directory.'/invalid.json';
    file_put_contents($invalid, '{');

    $empty = $directory.'/empty.json';
    file_put_contents($empty, '[]');

    expect(backup_manifest_validate_file($directory.'/absent.json'))
        ->toContain('Manifeste introuvable : '.$directory.'/absent.json.');

    expect(backup_manifest_validate_file($invalid)[0])->toStartWith('Manifeste JSON invalide');

    expect(backup_manifest_validate_file($empty))
        ->toContain('Le manifeste doit être un objet JSON non vide.');

    unlink($invalid);
    unlink($empty);
    rmdir($directory);
});

test('le schéma du manifeste et le validateur déclarent les mêmes champs obligatoires', function () use ($schemaPath): void {
    expect(is_file($schemaPath))->toBeTrue();

    $schema = json_decode((string) file_get_contents($schemaPath), true, 512, JSON_THROW_ON_ERROR);

    expect($schema['$schema'])->toBe('https://json-schema.org/draft/2020-12/schema');
    expect($schema['additionalProperties'])->toBeFalse();
    expect($schema['required'])->toBe(backup_manifest_required_fields());
    expect($schema['properties']['artifacts']['items']['required'])
        ->toBe(backup_manifest_required_artifact_fields());
    expect($schema['properties']['consistency']['required'])
        ->toBe(backup_manifest_required_consistency_fields());
    expect($schema['properties']['database']['required'])
        ->toBe(backup_manifest_required_database_fields());
    expect($schema['properties']['files']['required'])
        ->toBe(backup_manifest_required_files_fields());
});

test('le schéma interdit les noms de propriétés évoquant un secret', function () use ($schemaPath): void {
    $schema = json_decode((string) file_get_contents($schemaPath), true, 512, JSON_THROW_ON_ERROR);

    $pattern = $schema['propertyNames']['not']['pattern'] ?? '';

    expect($pattern)->not->toBe('');

    foreach (['password', 'secret', 'private_key', 'identity', 'passphrase', 'token', 'credential'] as $name) {
        expect(preg_match('/'.$pattern.'/i', $name))->toBe(1, "Le schéma doit refuser la propriété {$name}.");
    }
});
