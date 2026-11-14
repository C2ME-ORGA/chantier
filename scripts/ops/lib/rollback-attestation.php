<?php

declare(strict_types=1);

/**
 * Validateur de l'attestation de compatibilité de schéma pour le rollback
 * applicatif CHAN-98 (lot 3).
 *
 * Le rollback ne devine jamais la compatibilité N/N-1 : il exige une
 * attestation explicite, horodatée et vérifiable, produite après contrôle de
 * `migrate:status` et des décisions de la stratégie de migrations.
 *
 *   php rollback-attestation.php validate <fichier> \
 *       --environment staging --source <release> --target <release> \
 *       --database chantier_staging [--max-age 86400]
 *
 * Une attestation ne prouve pas à elle seule l'état du schéma : elle rend la
 * décision explicite, bornée dans le temps et traçable.
 */
const ROLLBACK_ATTESTATION_MAX_AGE_DEFAULT = 86400;
const ROLLBACK_ATTESTATION_FUTURE_TOLERANCE = 300;
const ROLLBACK_PROOF_MARKER = 'C2ME-MIGRATE-STATUS-PROOF';
const ROLLBACK_PROOF_VERSION = '1';
const ROLLBACK_PROOF_HEADERS = ['version', 'environment', 'release', 'database', 'captured_at'];

/**
 * @return list<string>
 */
function rollback_attestation_required_fields(): array
{
    return [
        'schema_version',
        'environment',
        'source_release',
        'target_release',
        'database',
        'checked_at',
        'checked_by',
        'migrate_status_sha256',
        'migrations',
    ];
}

/**
 * @return list<string>
 */
function rollback_attestation_required_migration_fields(): array
{
    return [
        'in_progress',
        'pending',
        'partial',
        'destructive_applied',
        'contract_applied',
        'compatible_with_target',
    ];
}

/**
 * @param  array<mixed>  $attestation
 * @param  array{environment:string,source:string,target:string,database:string,max_age:int}  $expected
 * @return list<string>
 */
function rollback_attestation_validate_array(array $attestation, array $expected): array
{
    $errors = [];

    if ($attestation === [] || array_is_list($attestation)) {
        return ['L attestation doit être un objet JSON non vide.'];
    }

    $allowedTopLevel = array_merge(rollback_attestation_required_fields(), ['notes']);
    $allowedMigrations = rollback_attestation_required_migration_fields();

    foreach (array_keys($attestation) as $key) {
        if (! in_array($key, $allowedTopLevel, true)) {
            $errors[] = "Champ inconnu dans l attestation : {$key}.";
        }

        if (is_string($key) && preg_match('/(password|secret|private|identity|passphrase|token|credential)/i', $key) === 1) {
            $errors[] = "Champ interdit dans l attestation : {$key}.";
        }
    }

    foreach (rollback_attestation_required_fields() as $field) {
        if (! array_key_exists($field, $attestation)) {
            $errors[] = "Champ obligatoire absent : {$field}.";
        }
    }

    if ($errors !== []) {
        return $errors;
    }

    if (($attestation['schema_version'] ?? null) !== 1) {
        $errors[] = 'schema_version doit valoir 1.';
    }

    if (($attestation['environment'] ?? null) !== $expected['environment']) {
        $errors[] = 'environment ne correspond pas à l environnement du rollback.';
    }

    if (($attestation['source_release'] ?? null) !== $expected['source']) {
        $errors[] = 'source_release ne correspond pas à la release active.';
    }

    if (($attestation['target_release'] ?? null) !== $expected['target']) {
        $errors[] = 'target_release ne correspond pas à la release cible.';
    }

    if (($attestation['database'] ?? null) !== $expected['database']) {
        $errors[] = 'database ne correspond pas à la base de l environnement.';
    }

    $checkedBy = $attestation['checked_by'] ?? null;

    if (! is_string($checkedBy) || trim($checkedBy) === '' || strlen($checkedBy) > 64) {
        $errors[] = 'checked_by doit être une chaîne non vide de 64 caractères au maximum.';
    }

    if (! is_string($attestation['migrate_status_sha256'] ?? null)
        || preg_match('/^[0-9a-f]{64}$/', (string) $attestation['migrate_status_sha256']) !== 1) {
        $errors[] = 'migrate_status_sha256 doit être un SHA-256 hexadécimal.';
    }

    $checkedAt = rollback_attestation_timestamp($attestation['checked_at'] ?? null, $errors);

    if ($checkedAt instanceof DateTimeImmutable) {
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
        $age = $now->getTimestamp() - $checkedAt->getTimestamp();

        if ($age < -ROLLBACK_ATTESTATION_FUTURE_TOLERANCE) {
            $errors[] = 'checked_at est dans le futur : attestation refusée.';
        }

        if ($age > $expected['max_age']) {
            $errors[] = "checked_at dépasse la durée de validité de {$expected['max_age']} secondes.";
        }
    }

    $migrations = $attestation['migrations'] ?? null;

    if (! is_array($migrations) || array_is_list($migrations)) {
        $errors[] = 'migrations doit être un objet.';

        return $errors;
    }

    foreach (array_keys($migrations) as $key) {
        if (! in_array($key, $allowedMigrations, true)) {
            $errors[] = "Champ migrations inconnu : {$key}.";
        }
    }

    foreach (rollback_attestation_required_migration_fields() as $field) {
        if (! array_key_exists($field, $migrations)) {
            $errors[] = "migrations.{$field} est obligatoire.";
        }
    }

    $mustBeFalse = ['in_progress', 'pending', 'partial', 'destructive_applied', 'contract_applied'];

    foreach ($mustBeFalse as $field) {
        if (($migrations[$field] ?? null) !== false) {
            $errors[] = "migrations.{$field} doit être false : rollback refusé.";
        }
    }

    if (($migrations['compatible_with_target'] ?? null) !== true) {
        $errors[] = 'migrations.compatible_with_target doit être true : rollback refusé.';
    }

    if (array_key_exists('notes', $attestation)) {
        $notes = $attestation['notes'];

        if (! is_string($notes) || strlen($notes) > 500) {
            $errors[] = 'notes doit être une chaîne de 500 caractères au maximum.';
        }
    }

    return $errors;
}

/**
 * @param  list<string>  $errors
 */
function rollback_attestation_timestamp(mixed $value, array &$errors): ?DateTimeImmutable
{
    if (! is_string($value)) {
        $errors[] = 'checked_at doit être une chaîne UTC ISO 8601.';

        return null;
    }

    $date = DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s\Z', $value, new DateTimeZone('UTC'));

    if ($date === false || $date->format('Y-m-d\TH:i:s\Z') !== $value) {
        $errors[] = 'checked_at doit respecter le format UTC YYYY-MM-DDTHH:MM:SSZ.';

        return null;
    }

    return $date;
}

function rollback_attestation_proof_path(string $attestationPath): string
{
    return $attestationPath.'.migrate-status.txt';
}

function rollback_attestation_modes_enforced(): bool
{
    $probe = tempnam(sys_get_temp_dir(), 'c2me-mode-');

    if ($probe === false) {
        return false;
    }

    $changed = chmod($probe, 0644);
    clearstatcache(true, $probe);
    $mode = fileperms($probe);

    unlink($probe);

    return $changed && $mode !== false && ($mode & 0777) === 0644;
}

/**
 * Vérifie la preuve conservée de `migrate:status` et son empreinte.
 *
 * @param  array<mixed>  $attestation
 * @param  array{environment:string,source:string,target:string,database:string,max_age:int}  $expected
 * @param  list<string>  $errors
 */
function rollback_attestation_validate_proof(
    string $path,
    array $attestation,
    array $expected,
    array &$errors
): void {
    if (is_link($path) || ! is_file($path)) {
        $errors[] = "Preuve migrate:status absente ou non régulière : {$path}.";

        return;
    }

    if (! is_readable($path)) {
        $errors[] = "Preuve migrate:status illisible : {$path}.";

        return;
    }

    if (rollback_attestation_modes_enforced()) {
        $mode = fileperms($path);

        if ($mode === false) {
            $errors[] = 'Permissions de la preuve migrate:status illisibles.';

            return;
        }

        if (($mode & 0022) !== 0) {
            $errors[] = 'Preuve migrate:status modifiable par le groupe ou les autres utilisateurs : refusée.';
        }

        if (($mode & 0400) === 0) {
            $errors[] = 'Preuve migrate:status non lisible par son propriétaire : refusée.';
        }
    }

    $contents = file_get_contents($path);

    if ($contents === false) {
        $errors[] = "Preuve migrate:status illisible : {$path}.";

        return;
    }

    $recorded = (string) ($attestation['migrate_status_sha256'] ?? '');
    $actual = hash('sha256', $contents);

    if (! hash_equals($recorded, $actual)) {
        $errors[] = 'migrate_status_sha256 ne correspond pas à la preuve conservée.';
    }

    $normalized = str_replace("\r\n", "\n", $contents);
    $lines = explode("\n", $normalized);

    if (($lines[0] ?? '') !== ROLLBACK_PROOF_MARKER) {
        $errors[] = 'Preuve migrate:status : en-tête de format absent.';

        return;
    }

    $headers = [];
    $bodyStart = null;

    for ($index = 1; $index < count($lines); $index++) {
        $line = $lines[$index];

        if ($line === '---') {
            $bodyStart = $index + 1;
            break;
        }

        if (preg_match('/^([a-z_]+): (.+)$/', $line, $matches) !== 1) {
            $errors[] = 'Preuve migrate:status : ligne d en-tête invalide.';

            return;
        }

        $key = $matches[1];

        if (! in_array($key, ROLLBACK_PROOF_HEADERS, true)) {
            $errors[] = "Preuve migrate:status : en-tête inconnu {$key}.";
        }

        if (array_key_exists($key, $headers)) {
            $errors[] = "Preuve migrate:status : en-tête dupliqué {$key}.";
        }

        $headers[$key] = $matches[2];
    }

    if ($bodyStart === null) {
        $errors[] = 'Preuve migrate:status : séparateur de sortie absent.';

        return;
    }

    foreach (ROLLBACK_PROOF_HEADERS as $required) {
        if (! array_key_exists($required, $headers)) {
            $errors[] = "Preuve migrate:status : en-tête {$required} absent.";
        }
    }

    $body = trim(implode("\n", array_slice($lines, $bodyStart)));

    if ($body === '') {
        $errors[] = 'Preuve migrate:status : sortie vide.';
    }

    if (($headers['version'] ?? '') !== ROLLBACK_PROOF_VERSION) {
        $errors[] = 'Preuve migrate:status : version non prise en charge.';
    }

    if (($headers['environment'] ?? '') !== $expected['environment']
        || ($headers['environment'] ?? '') !== ($attestation['environment'] ?? '')) {
        $errors[] = 'Preuve migrate:status : environnement incohérent.';
    }

    if (($headers['release'] ?? '') !== $expected['source']
        || ($headers['release'] ?? '') !== ($attestation['source_release'] ?? '')) {
        $errors[] = 'Preuve migrate:status : release incohérente.';
    }

    if (($headers['database'] ?? '') !== $expected['database']
        || ($headers['database'] ?? '') !== ($attestation['database'] ?? '')) {
        $errors[] = 'Preuve migrate:status : base incohérente.';
    }

    $capturedAt = rollback_attestation_parse_timestamp($headers['captured_at'] ?? null);

    if ($capturedAt === null) {
        $errors[] = 'Preuve migrate:status : captured_at invalide.';
    } else {
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));

        if ($capturedAt->getTimestamp() - $now->getTimestamp() > ROLLBACK_ATTESTATION_FUTURE_TOLERANCE) {
            $errors[] = 'Preuve migrate:status : captured_at est dans le futur.';
        }

        $checkedAt = rollback_attestation_parse_timestamp($attestation['checked_at'] ?? null);

        if ($checkedAt instanceof DateTimeImmutable) {
            $delta = $checkedAt->getTimestamp() - $capturedAt->getTimestamp();

            if ($delta < -ROLLBACK_ATTESTATION_FUTURE_TOLERANCE) {
                $errors[] = 'Preuve migrate:status : capturée après checked_at.';
            }

            if ($delta > $expected['max_age']) {
                $errors[] = 'Preuve migrate:status : trop ancienne par rapport à l attestation.';
            }
        }
    }
}

function rollback_attestation_parse_timestamp(mixed $value): ?DateTimeImmutable
{
    if (! is_string($value)) {
        return null;
    }

    $date = DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s\Z', $value, new DateTimeZone('UTC'));

    if ($date === false || $date->format('Y-m-d\TH:i:s\Z') !== $value) {
        return null;
    }

    return $date;
}

/**
 * @return list<string>
 */
function rollback_attestation_validate_file(string $path, array $expected): array
{
    if (! is_file($path)) {
        return ["Attestation introuvable : {$path}."];
    }

    $contents = file_get_contents($path);

    if ($contents === false) {
        return ["Attestation illisible : {$path}."];
    }

    try {
        $decoded = json_decode($contents, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        return ['Attestation JSON invalide : '.$exception->getMessage().'.'];
    }

    if (! is_array($decoded)) {
        return ['L attestation doit être un objet JSON.'];
    }

    $errors = rollback_attestation_validate_array($decoded, $expected);

    if ($errors !== []) {
        return $errors;
    }

    rollback_attestation_validate_proof(
        rollback_attestation_proof_path($path),
        $decoded,
        $expected,
        $errors
    );

    return $errors;
}

if (PHP_SAPI === 'cli' && isset($_SERVER['argv'][0]) && realpath((string) $_SERVER['argv'][0]) === __FILE__) {
    $command = $_SERVER['argv'][1] ?? '';

    if ($command !== 'validate') {
        fwrite(STDERR, "Usage : php rollback-attestation.php validate <fichier> --environment <env> --source <release> --target <release> --database <base> [--max-age <secondes>]\n");
        exit(2);
    }

    $path = $_SERVER['argv'][2] ?? '';
    $options = [
        'environment' => '',
        'source' => '',
        'target' => '',
        'database' => '',
        'max-age' => (string) ROLLBACK_ATTESTATION_MAX_AGE_DEFAULT,
    ];

    for ($index = 3; $index < count($_SERVER['argv']); $index += 2) {
        $option = $_SERVER['argv'][$index] ?? '';
        $value = $_SERVER['argv'][$index + 1] ?? '';

        if (! array_key_exists(ltrim($option, '-'), $options)) {
            fwrite(STDERR, "Option inconnue : {$option}\n");
            exit(2);
        }

        $options[ltrim($option, '-')] = $value;
    }

    if ($path === '' || $options['environment'] === '' || $options['source'] === ''
        || $options['target'] === '' || $options['database'] === '') {
        fwrite(STDERR, "Arguments obligatoires manquants.\n");
        exit(2);
    }

    if (preg_match('/^[0-9]+$/', $options['max-age']) !== 1 || (int) $options['max-age'] < 1) {
        fwrite(STDERR, "max-age invalide.\n");
        exit(2);
    }

    $errors = rollback_attestation_validate_file($path, [
        'environment' => $options['environment'],
        'source' => $options['source'],
        'target' => $options['target'],
        'database' => $options['database'],
        'max_age' => (int) $options['max-age'],
    ]);

    if ($errors !== []) {
        foreach ($errors as $error) {
            fwrite(STDERR, "ÉCHEC: {$error}\n");
        }

        exit(1);
    }

    echo "Attestation valide : {$path}\n";
    exit(0);
}
