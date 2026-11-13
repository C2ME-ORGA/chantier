<?php

declare(strict_types=1);

/**
 * Validateur du manifeste de sauvegarde CHAN-98 (lot 2).
 *
 * Ce fichier est autonome : il ne dépend pas du framework et peut être appelé
 * par les scripts d'exploitation, les tests ou un opérateur.
 *
 *   php scripts/ops/lib/manifest.php validate /chemin/vers/manifest.json
 *   php scripts/ops/lib/manifest.php required-fields
 *
 * Le schéma de référence est scripts/ops/schema/backup-manifest.schema.json.
 * En cas de divergence, ce validateur fait foi : il est exécuté à chaque
 * production de manifeste et par les tests.
 */

/**
 * @return list<string>
 */
function backup_manifest_required_fields(): array
{
    return [
        'schema_version',
        'backup_set_id',
        'environment',
        'scope',
        'restorable_as_complete',
        'status',
        'created_at',
        'completed_at',
        'trigger',
        'consistency',
        'release',
        'database',
        'files',
        'artifacts',
        'retention',
        'host',
    ];
}

/**
 * Champs d'un artefact.
 *
 * @return list<string>
 */
function backup_manifest_required_artifact_fields(): array
{
    return ['kind', 'name', 'bytes', 'sha256', 'compression', 'encryption'];
}

/**
 * Champs du bloc de cohérence.
 *
 * @return list<string>
 */
function backup_manifest_required_consistency_fields(): array
{
    return [
        'mode',
        'maintenance_marker',
        'workers_verified',
        'scheduler_verified',
        'file_changes_detected',
        'started_at',
        'finished_at',
        'downtime_seconds',
    ];
}

/**
 * @return list<string>
 */
function backup_manifest_required_database_fields(): array
{
    return [
        'name',
        'server_version',
        'tool',
        'tool_version',
        'options_sha256',
        'tables',
        'rows',
        'non_innodb_tables',
    ];
}

/**
 * @return list<string>
 */
function backup_manifest_required_files_fields(): array
{
    return ['included_roots', 'exclusions', 'file_count', 'total_bytes', 'inventory_sha256'];
}

/**
 * Valide un manifeste déjà décodé.
 *
 * @param  array<mixed>  $manifest
 * @return list<string> Liste d'erreurs ; une liste vide signifie que le manifeste est valide.
 */
function backup_manifest_validate_array(array $manifest): array
{
    $errors = [];

    if ($manifest === [] || array_is_list($manifest)) {
        return ['Le manifeste doit être un objet JSON non vide.'];
    }

    foreach (backup_manifest_required_fields() as $field) {
        if (! array_key_exists($field, $manifest)) {
            $errors[] = "Champ obligatoire absent : {$field}.";
        }
    }

    if ($errors !== []) {
        return $errors;
    }

    backup_manifest_collect_secret_keys($manifest, '', $errors);

    if (($manifest['schema_version'] ?? null) !== 1) {
        $errors[] = 'schema_version doit valoir 1.';
    }

    $environment = $manifest['environment'] ?? null;

    if (! in_array($environment, ['staging', 'production'], true)) {
        $errors[] = 'environment doit valoir staging ou production.';
    }

    $setId = $manifest['backup_set_id'] ?? null;

    if (! is_string($setId) || preg_match('/^set-(staging|production)-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$/', $setId) !== 1) {
        $errors[] = 'backup_set_id ne respecte pas le format set-<env>-<horodatage>-<hex8>.';
    } elseif (is_string($environment)) {
        $expectedPrefix = 'set-'.$environment.'-';

        if (! str_starts_with($setId, $expectedPrefix)) {
            $errors[] = 'backup_set_id ne correspond pas à environment.';
        }
    }

    $scope = $manifest['scope'] ?? null;

    if (! in_array($scope, ['full', 'database-only'], true)) {
        $errors[] = 'scope doit valoir full ou database-only.';
    }

    $restorable = $manifest['restorable_as_complete'] ?? null;

    if (! is_bool($restorable)) {
        $errors[] = 'restorable_as_complete doit être un booléen.';
    }

    if ($scope === 'full' && $restorable !== true) {
        $errors[] = 'Un jeu full doit porter restorable_as_complete: true.';
    }

    if ($scope === 'database-only' && $restorable !== false) {
        $errors[] = 'Un jeu database-only ne doit jamais porter restorable_as_complete: true.';
    }

    if (! in_array($manifest['status'] ?? null, ['complete', 'incomplete'], true)) {
        $errors[] = 'status doit valoir complete ou incomplete.';
    }

    $createdAt = backup_manifest_check_timestamp($manifest['created_at'] ?? null, 'created_at', $errors);
    $completedAt = backup_manifest_check_timestamp($manifest['completed_at'] ?? null, 'completed_at', $errors);

    if ($createdAt instanceof DateTimeImmutable && $completedAt instanceof DateTimeImmutable && $completedAt < $createdAt) {
        $errors[] = 'completed_at doit être postérieur ou égal à created_at.';
    }

    if (! in_array($manifest['trigger'] ?? null, ['scheduled', 'pre-migration', 'manual', 'pre-restore'], true)) {
        $errors[] = 'trigger doit valoir scheduled, pre-migration, manual ou pre-restore.';
    }

    backup_manifest_validate_consistency($manifest['consistency'] ?? null, $errors);
    backup_manifest_validate_release($manifest['release'] ?? null, $errors);
    backup_manifest_validate_database($manifest['database'] ?? null, $environment, $errors);
    backup_manifest_validate_files($manifest['files'] ?? null, $scope, $errors);
    backup_manifest_validate_artifacts(
        $manifest['artifacts'] ?? null,
        $scope,
        $environment,
        $manifest['trigger'] ?? null,
        $manifest['backup_set_id'] ?? null,
        $errors
    );
    backup_manifest_validate_retention($manifest['retention'] ?? null, $errors);
    backup_manifest_validate_host($manifest['host'] ?? null, $errors);

    return $errors;
}

/**
 * Valide un fichier de manifeste.
 *
 * @return list<string>
 */
function backup_manifest_validate_file(string $path): array
{
    if (! is_file($path)) {
        return ["Manifeste introuvable : {$path}."];
    }

    $contents = file_get_contents($path);

    if ($contents === false) {
        return ["Manifeste illisible : {$path}."];
    }

    try {
        $decoded = json_decode($contents, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        return ["Manifeste JSON invalide : {$exception->getMessage()}."];
    }

    if (! is_array($decoded)) {
        return ['Le manifeste doit être un objet JSON.'];
    }

    return backup_manifest_validate_array($decoded);
}

/**
 * Refuse toute clé dont le nom évoque un secret, à n'importe quel niveau.
 *
 * @param  array<mixed>  $value
 * @param  list<string>  $errors
 */
function backup_manifest_collect_secret_keys(array $value, string $path, array &$errors): void
{
    foreach ($value as $key => $item) {
        $keyPath = $path === '' ? (string) $key : $path.'.'.$key;

        if (is_string($key) && preg_match('/(password|secret|private|identity|passphrase|token|credential)/i', $key) === 1) {
            $errors[] = "Clé interdite dans le manifeste : {$keyPath}.";
        }

        if (is_array($item)) {
            backup_manifest_collect_secret_keys($item, $keyPath, $errors);
        }

        if (is_string($item) && preg_match('/-----BEGIN [A-Z ]*PRIVATE KEY-----/', $item) === 1) {
            $errors[] = "Contenu de clé privée détecté dans le manifeste : {$keyPath}.";
        }
    }
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_check_timestamp(mixed $value, string $field, array &$errors): ?DateTimeImmutable
{
    if (! is_string($value)) {
        $errors[] = "{$field} doit être une chaîne UTC ISO 8601.";

        return null;
    }

    $date = DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s\Z', $value, new DateTimeZone('UTC'));

    if ($date === false || $date->format('Y-m-d\TH:i:s\Z') !== $value) {
        $errors[] = "{$field} doit respecter le format UTC YYYY-MM-DDTHH:MM:SSZ.";

        return null;
    }

    return $date;
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_validate_consistency(mixed $consistency, array &$errors): void
{
    if (! is_array($consistency) || array_is_list($consistency)) {
        $errors[] = 'consistency doit être un objet.';

        return;
    }

    foreach (backup_manifest_required_consistency_fields() as $field) {
        if (! array_key_exists($field, $consistency)) {
            $errors[] = "consistency.{$field} est obligatoire.";
        }
    }

    if (($consistency['mode'] ?? null) !== 'maintenance') {
        $errors[] = 'consistency.mode doit valoir maintenance.';
    }

    foreach (['maintenance_marker', 'workers_verified', 'scheduler_verified'] as $flag) {
        if (($consistency[$flag] ?? null) !== true) {
            $errors[] = "consistency.{$flag} doit être true : la cohérence n'est pas démontrée.";
        }
    }

    if (($consistency['file_changes_detected'] ?? null) !== false) {
        $errors[] = 'consistency.file_changes_detected doit être false.';
    }

    $startedAt = backup_manifest_check_timestamp($consistency['started_at'] ?? null, 'consistency.started_at', $errors);
    $finishedAt = backup_manifest_check_timestamp($consistency['finished_at'] ?? null, 'consistency.finished_at', $errors);

    if ($startedAt instanceof DateTimeImmutable && $finishedAt instanceof DateTimeImmutable && $finishedAt < $startedAt) {
        $errors[] = 'consistency.finished_at doit être postérieur ou égal à started_at.';
    }

    if (! is_int($consistency['downtime_seconds'] ?? null) || ($consistency['downtime_seconds'] ?? -1) < 0) {
        $errors[] = 'consistency.downtime_seconds doit être un entier positif ou nul.';
    }
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_validate_release(mixed $release, array &$errors): void
{
    if (! is_array($release) || array_is_list($release)) {
        $errors[] = 'release doit être un objet.';

        return;
    }

    $version = $release['version'] ?? null;

    if (! is_string($version) || preg_match('/^(v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.[1-9][0-9]*)?|unknown)$/', $version) !== 1) {
        $errors[] = 'release.version doit être une version SemVer ou unknown.';
    }

    $commit = $release['commit_sha'] ?? null;

    if (! is_string($commit) || preg_match('/^([0-9a-f]{40}|unknown)$/', $commit) !== 1) {
        $errors[] = 'release.commit_sha doit être un SHA de 40 caractères ou unknown.';
    }

    $tree = $release['tree_sha'] ?? null;

    if ($tree !== null && (! is_string($tree) || preg_match('/^([0-9a-f]{40}|unknown)$/', $tree) !== 1)) {
        $errors[] = 'release.tree_sha doit être un SHA de 40 caractères, unknown ou null.';
    }
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_validate_database(mixed $database, mixed $environment, array &$errors): void
{
    if (! is_array($database) || array_is_list($database)) {
        $errors[] = 'database doit être un objet.';

        return;
    }

    foreach (backup_manifest_required_database_fields() as $field) {
        if (! array_key_exists($field, $database)) {
            $errors[] = "database.{$field} est obligatoire.";
        }
    }

    $expectedDatabase = $environment === 'staging' ? 'chantier_staging' : 'chantier_production';

    if (($database['name'] ?? null) !== $expectedDatabase) {
        $errors[] = "database.name doit valoir {$expectedDatabase} pour l'environnement déclaré.";
    }

    if (($database['tool'] ?? null) !== 'mariadb-dump') {
        $errors[] = 'database.tool doit valoir mariadb-dump.';
    }

    foreach (['server_version', 'tool_version'] as $field) {
        if (! is_string($database[$field] ?? null) || trim((string) $database[$field]) === '') {
            $errors[] = "database.{$field} doit être une chaîne non vide.";
        }
    }

    if (! is_string($database['options_sha256'] ?? null) || preg_match('/^[0-9a-f]{64}$/', (string) $database['options_sha256']) !== 1) {
        $errors[] = 'database.options_sha256 doit être un SHA-256 hexadécimal.';
    }

    if (! is_int($database['tables'] ?? null) || $database['tables'] < 1) {
        $errors[] = 'database.tables doit être un entier supérieur ou égal à 1.';
    }

    if (! is_int($database['rows'] ?? null) || $database['rows'] < 0) {
        $errors[] = 'database.rows doit être un entier positif ou nul.';
    }

    if (($database['non_innodb_tables'] ?? null) !== []) {
        $errors[] = 'database.non_innodb_tables doit être vide : un dump à chaud non cohérent est interdit.';
    }
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_validate_files(mixed $files, mixed $scope, array &$errors): void
{
    if ($scope === 'database-only') {
        if ($files !== null) {
            $errors[] = 'files doit être null pour un jeu database-only.';
        }

        return;
    }

    if (! is_array($files) || array_is_list($files)) {
        $errors[] = 'files doit être un objet pour un jeu full.';

        return;
    }

    foreach (backup_manifest_required_files_fields() as $field) {
        if (! array_key_exists($field, $files)) {
            $errors[] = "files.{$field} est obligatoire.";
        }
    }

    $roots = $files['included_roots'] ?? null;

    if (! is_array($roots) || $roots === []) {
        $errors[] = 'files.included_roots doit lister au moins une racine.';
    } else {
        foreach ($roots as $root) {
            if (! in_array($root, ['app/private', 'app/public'], true)) {
                $errors[] = 'files.included_roots contient une racine non autorisée.';
            }
        }
    }

    if (! is_array($files['exclusions'] ?? null) || $files['exclusions'] === []) {
        $errors[] = 'files.exclusions doit lister les exclusions appliquées.';
    }

    if (! is_int($files['file_count'] ?? null) || $files['file_count'] < 0) {
        $errors[] = 'files.file_count doit être un entier positif ou nul.';
    }

    if (! is_int($files['total_bytes'] ?? null) || $files['total_bytes'] < 0) {
        $errors[] = 'files.total_bytes doit être un entier positif ou nul.';
    }

    if (! is_string($files['inventory_sha256'] ?? null) || preg_match('/^[0-9a-f]{64}$/', (string) $files['inventory_sha256']) !== 1) {
        $errors[] = 'files.inventory_sha256 doit être un SHA-256 hexadécimal.';
    }
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_validate_artifacts(
    mixed $artifacts,
    mixed $scope,
    mixed $environment,
    mixed $trigger,
    mixed $setId,
    array &$errors
): void {
    if (! is_array($artifacts) || $artifacts === [] || ! array_is_list($artifacts)) {
        $errors[] = 'artifacts doit être une liste non vide.';

        return;
    }

    $kinds = [];
    $names = [];
    $environmentPattern = is_string($environment) && in_array($environment, ['staging', 'production'], true)
        ? $environment
        : '(staging|production)';
    $triggerPattern = is_string($trigger) && in_array($trigger, ['scheduled', 'pre-migration', 'manual', 'pre-restore'], true)
        ? $trigger
        : '(scheduled|pre-migration|manual|pre-restore)';

    foreach ($artifacts as $index => $artifact) {
        if (! is_array($artifact) || array_is_list($artifact)) {
            $errors[] = "artifacts[{$index}] doit être un objet.";

            continue;
        }

        foreach (backup_manifest_required_artifact_fields() as $field) {
            if (! array_key_exists($field, $artifact)) {
                $errors[] = "artifacts[{$index}].{$field} est obligatoire.";
            }
        }

        $kind = $artifact['kind'] ?? null;

        if (! in_array($kind, ['database', 'files'], true)) {
            $errors[] = "artifacts[{$index}].kind doit valoir database ou files.";
        } else {
            $kinds[] = $kind;
        }

        $name = $artifact['name'] ?? null;
        $expectedPrefix = $kind === 'files' ? 'files' : 'db';
        $expectedExtension = $kind === 'files' ? 'tar' : 'sql';

        if (! is_string($name) || basename($name) !== $name || $name === '.') {
            $errors[] = "artifacts[{$index}].name doit être un nom de fichier simple.";
        } elseif (preg_match(
            '/^'.preg_quote($expectedPrefix, '/').'-'.preg_quote($environmentPattern, '/').'-[0-9]{8}T[0-9]{6}Z-[A-Za-z0-9._-]+-(unknown|[0-9a-f]{7})-'.preg_quote($triggerPattern, '/').'\.'.preg_quote($expectedExtension, '/').'\.(zst|gz)\.age$/',
            $name
        ) !== 1) {
            $errors[] = "artifacts[{$index}].name ne respecte pas la convention de nommage.";
        } else {
            $names[] = $name;
        }

        if (! is_int($artifact['bytes'] ?? null) || $artifact['bytes'] < 1) {
            $errors[] = "artifacts[{$index}].bytes doit être un entier strictement positif.";
        }

        if (! is_string($artifact['sha256'] ?? null) || preg_match('/^[0-9a-f]{64}$/', (string) $artifact['sha256']) !== 1) {
            $errors[] = "artifacts[{$index}].sha256 doit être un SHA-256 hexadécimal.";
        }

        $compression = $artifact['compression'] ?? null;

        if (! in_array($compression, ['zstd', 'gzip'], true)) {
            $errors[] = "artifacts[{$index}].compression doit valoir zstd ou gzip.";
        }

        $encryption = $artifact['encryption'] ?? null;

        if (! is_array($encryption) || array_is_list($encryption)) {
            $errors[] = "artifacts[{$index}].encryption doit être un objet.";
        } else {
            if (($encryption['tool'] ?? null) !== 'age') {
                $errors[] = "artifacts[{$index}].encryption.tool doit valoir age.";
            }

            if (! is_string($encryption['recipient'] ?? null) || preg_match('/^age1[0-9a-z]{20,}$/', (string) $encryption['recipient']) !== 1) {
                $errors[] = "artifacts[{$index}].encryption.recipient doit être un destinataire age valide.";
            }
        }

        if (is_string($setId) && is_string($name)
            && preg_match('/^set-(?:staging|production)-([0-9]{8}T[0-9]{6}Z)-[0-9a-f]{8}$/', $setId, $setMatches) === 1
            && ! str_contains($name, $setMatches[1])) {
            $errors[] = "artifacts[{$index}].name ne reprend pas l'horodatage du jeu.";
        }
    }

    if (count($names) !== count(array_unique($names))) {
        $errors[] = 'Deux artefacts portent le même nom.';
    }

    if ($scope === 'full') {
        if (count(array_keys($kinds, 'database', true)) !== 1) {
            $errors[] = 'Un jeu full doit contenir exactement un artefact database.';
        }

        if (count(array_keys($kinds, 'files', true)) !== 1) {
            $errors[] = 'Un jeu full doit contenir exactement un artefact files.';
        }
    }

    if ($scope === 'database-only' && in_array('files', $kinds, true)) {
        $errors[] = 'Un jeu database-only ne doit contenir aucun artefact files.';
    }
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_validate_retention(mixed $retention, array &$errors): void
{
    if (! is_array($retention) || array_is_list($retention)) {
        $errors[] = 'retention doit être un objet.';

        return;
    }

    if (! in_array($retention['class'] ?? null, ['daily', 'monthly', 'pre-migration', 'manual'], true)) {
        $errors[] = 'retention.class doit valoir daily, monthly, pre-migration ou manual.';
    }

    backup_manifest_check_timestamp($retention['delete_after'] ?? null, 'retention.delete_after', $errors);
}

/**
 * @param  list<string>  $errors
 */
function backup_manifest_validate_host(mixed $host, array &$errors): void
{
    if (! is_array($host) || array_is_list($host)) {
        $errors[] = 'host doit être un objet.';

        return;
    }

    $name = $host['name'] ?? null;

    if (! is_string($name) || preg_match('/^[A-Za-z0-9._-]{1,64}$/', $name) !== 1) {
        $errors[] = 'host.name doit être un identifiant simple de 1 à 64 caractères.';
    }

    $operator = $host['operator'] ?? null;

    if (! is_string($operator) || trim($operator) === '' || strlen($operator) > 64) {
        $errors[] = 'host.operator doit être une chaîne non vide de 64 caractères au maximum.';
    }
}

/**
 * Point d'entrée CLI. Ne s'exécute jamais lorsqu'un test ou un autre script
 * inclut ce fichier.
 */
if (PHP_SAPI === 'cli' && isset($_SERVER['argv'][0]) && realpath((string) $_SERVER['argv'][0]) === __FILE__) {
    $command = $_SERVER['argv'][1] ?? 'validate';

    if ($command === 'required-fields') {
        echo json_encode(backup_manifest_required_fields(), JSON_PRETTY_PRINT).PHP_EOL;
        exit(0);
    }

    if ($command === 'summary') {
        $path = $_SERVER['argv'][2] ?? '';
        $key = $_SERVER['argv'][3] ?? '';

        if ($path === '' || $key === '') {
            fwrite(STDERR, "Usage : php manifest.php summary <fichier> <chemin.pointe>\n");
            exit(2);
        }

        $contents = is_file($path) ? file_get_contents($path) : false;

        if ($contents === false) {
            fwrite(STDERR, "Manifeste introuvable ou illisible : {$path}\n");
            exit(1);
        }

        $decoded = json_decode($contents, true);

        if (! is_array($decoded)) {
            fwrite(STDERR, "Manifeste JSON invalide : {$path}\n");
            exit(1);
        }

        $value = $decoded;

        foreach (explode('.', $key) as $segment) {
            if (! is_array($value) || ! array_key_exists($segment, $value)) {
                exit(1);
            }

            $value = $value[$segment];
        }

        if (is_bool($value)) {
            echo $value ? 'true' : 'false';
        } elseif (is_scalar($value) && $value !== null) {
            echo (string) $value;
        } else {
            echo json_encode($value);
        }

        echo PHP_EOL;
        exit(0);
    }

    if ($command !== 'validate') {
        fwrite(STDERR, "Usage : php manifest.php validate <fichier> | summary <fichier> <cle> | required-fields\n");
        exit(2);
    }

    $path = $_SERVER['argv'][2] ?? '';

    if ($path === '') {
        fwrite(STDERR, "Usage : php manifest.php validate <fichier>\n");
        exit(2);
    }

    $errors = backup_manifest_validate_file($path);

    if ($errors !== []) {
        foreach ($errors as $error) {
            fwrite(STDERR, "ÉCHEC: {$error}\n");
        }

        exit(1);
    }

    echo "Manifeste valide : {$path}\n";
    exit(0);
}
