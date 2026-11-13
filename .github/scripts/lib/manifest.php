<?php

declare(strict_types=1);

/**
 * Lecture, écriture et validation des manifestes JSON de déploiement.
 *
 * Aucune dépendance externe n'est requise, ce qui permet de réutiliser ce
 * script dans les workflows et dans les tests locaux.
 *
 * Usage :
 *   php manifest.php create <fichier> [cle.pointee=valeur...]
 *   php manifest.php get <fichier> <cle.pointee>
 *   php manifest.php validate <fichier>
 *
 * `validate` applique le schéma strict des manifestes de déploiement. `create`
 * écrit un manifeste sans le valider : les workflows appellent `validate`
 * explicitement avant publication.
 */

const MANIFEST_SCHEMA_VERSION = '1';
const VERSION_STABLE_PATTERN = '/^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/';
const VERSION_RC_PATTERN = '/^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc\.([1-9][0-9]*)$/';

function fail(string $message): never
{
    fwrite(STDERR, $message."\n");

    exit(1);
}

/**
 * @return array<string, mixed>
 */
function read_manifest(string $file): array
{
    if (! is_file($file) || ! is_readable($file)) {
        fail("Manifeste introuvable ou illisible : {$file}");
    }

    try {
        $decoded = json_decode((string) file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        fail("Manifeste JSON invalide ({$file}) : {$exception->getMessage()}");
    }

    if (! is_array($decoded)) {
        fail("Le manifeste {$file} doit contenir un objet JSON.");
    }

    return $decoded;
}

/**
 * @param  array<string, mixed>  $data
 * @param  array<int, string>  $keys
 */
function write_path(array &$data, array $keys, string $value): void
{
    $last = array_pop($keys);
    $cursor = &$data;

    foreach ($keys as $key) {
        if (! isset($cursor[$key]) || ! is_array($cursor[$key])) {
            $cursor[$key] = [];
        }

        $cursor = &$cursor[$key];
    }

    $cursor[$last] = $value;
}

/**
 * @return array<int, string>
 */
function split_path(string $path): array
{
    if ($path === '') {
        fail('Clé de manifeste vide.');
    }

    $keys = explode('.', $path);

    foreach ($keys as $key) {
        if ($key === '') {
            fail("Clé de manifeste invalide : {$path}");
        }
    }

    return $keys;
}

/**
 * @param  array<string, mixed>  $data
 * @param  array<int, string>  $keys
 */
function read_path(array $data, array $keys): mixed
{
    $cursor = $data;

    foreach ($keys as $key) {
        if (! is_array($cursor) || ! array_key_exists($key, $cursor)) {
            fail('Clé de manifeste absente : '.implode('.', $keys));
        }

        $cursor = $cursor[$key];
    }

    return $cursor;
}

/**
 * @param  array<string, mixed>  $data
 * @return array{0: bool, 1: mixed}
 */
function lookup(array $data, string $path): array
{
    $cursor = $data;

    foreach (split_path($path) as $key) {
        if (! is_array($cursor) || ! array_key_exists($key, $cursor)) {
            return [false, null];
        }

        $cursor = $cursor[$key];
    }

    return [true, $cursor];
}

/**
 * @param  array<string, mixed>  $data
 */
function require_string(array $data, string $path): string
{
    [$found, $value] = lookup($data, $path);

    if (! $found) {
        fail("Champ obligatoire absent du manifeste : {$path}");
    }

    if (! is_string($value)) {
        fail("Type invalide pour {$path} : chaîne de caractères attendue");
    }

    if (trim($value) === '') {
        fail("Champ obligatoire vide dans le manifeste : {$path}");
    }

    return $value;
}

/**
 * @param  array<string, mixed>  $data
 */
function require_pattern(array $data, string $path, string $pattern, string $label): string
{
    $value = require_string($data, $path);

    if (! preg_match($pattern, $value)) {
        fail("Format invalide pour {$path} : {$label} attendu, reçu '{$value}'");
    }

    return $value;
}

/**
 * @param  array<string, mixed>  $data
 */
function require_digits(array $data, string $path): string
{
    return require_pattern($data, $path, '/^[0-9]+$/', 'identifiant numérique');
}

/**
 * @param  array<string, mixed>  $data
 * @param  array<int, string>  $allowed
 */
function require_enum(array $data, string $path, array $allowed): string
{
    $value = require_string($data, $path);

    if (! in_array($value, $allowed, true)) {
        fail("Valeur invalide pour {$path} : '{$value}' (attendu : ".implode(', ', $allowed).')');
    }

    return $value;
}

/**
 * @param  array<string, mixed>  $data
 */
function validate_manifest(array $data): void
{
    $schemaVersion = require_string($data, 'schema_version');

    if ($schemaVersion !== MANIFEST_SCHEMA_VERSION) {
        fail("Version de schéma non supportée : {$schemaVersion} (attendu : ".MANIFEST_SCHEMA_VERSION.')');
    }

    $environment = require_enum($data, 'environment', ['staging', 'production']);
    $channel = require_enum($data, 'channel', ['rc', 'stable']);
    $version = require_string($data, 'version');

    if ($channel === 'rc' && ! preg_match(VERSION_RC_PATTERN, $version)) {
        fail("Version de release candidate invalide : {$version}");
    }

    if ($channel === 'stable' && ! preg_match(VERSION_STABLE_PATTERN, $version)) {
        fail("Version stable invalide : {$version}");
    }

    if (($environment === 'staging') !== ($channel === 'rc')) {
        fail("Canal {$channel} incohérent pour l'environnement {$environment}");
    }

    $tag = require_string($data, 'tag');

    if ($tag !== $version) {
        fail("Tag incohérent : {$tag} ne correspond pas à la version {$version}");
    }

    require_pattern($data, 'commit_sha', '/^[0-9a-f]{40}$/', 'SHA Git de 40 caractères hexadécimaux');
    require_pattern($data, 'tree_sha', '/^[0-9a-f]{40}$/', 'SHA Git de 40 caractères hexadécimaux');

    $workflow = require_enum($data, 'workflow.name', ['deploy-staging', 'deploy-production']);

    if (($environment === 'staging') !== ($workflow === 'deploy-staging')) {
        fail("Workflow {$workflow} incohérent pour l'environnement {$environment}");
    }

    require_digits($data, 'workflow.run_id');
    require_digits($data, 'workflow.run_attempt');

    $artifactName = require_string($data, 'artifact.name');

    if (! preg_match('/^chantier-[A-Za-z0-9._-]+$/', $artifactName)) {
        fail("Nom d'artefact invalide : {$artifactName}");
    }

    require_digits($data, 'artifact.id');
    require_pattern($data, 'artifact.sha256', '/^[0-9a-f]{64}$/', 'empreinte SHA-256 de 64 caractères hexadécimaux');

    require_enum($data, 'staging_deployment.status', ['success', 'failure', 'pending']);
    require_digits($data, 'staging_deployment.run_id');

    $createdAt = require_string($data, 'created_at');
    $createdAtPattern = '/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/';

    if (! preg_match($createdAtPattern, $createdAt)) {
        fail("Date invalide pour created_at : {$createdAt} (format UTC ISO 8601 attendu)");
    }

    $parsedDate = DateTimeImmutable::createFromFormat('Y-m-d\TH:i:s\Z', $createdAt, new DateTimeZone('UTC'));

    if ($parsedDate === false || $parsedDate->format('Y-m-d\TH:i:s\Z') !== $createdAt) {
        fail("Date invalide pour created_at : {$createdAt}");
    }

    if ($environment === 'staging') {
        require_enum($data, 'staging_deployment.job', ['deploy']);

        return;
    }

    $candidate = require_pattern($data, 'staging.candidate_tag', VERSION_RC_PATTERN, 'tag de release candidate');
    $baseVersion = preg_replace('/-rc\.[0-9]+$/', '', $candidate);

    if ($baseVersion !== $version) {
        fail("La candidate {$candidate} ne correspond pas à la version stable {$version}");
    }

    require_digits($data, 'staging.run_id');
    require_digits($data, 'staging.manifest_artifact_id');
}

$command = $argv[1] ?? '';

if ($command === 'create') {
    $file = $argv[2] ?? '';

    if ($file === '') {
        fail('Usage : manifest.php create <fichier> [cle.pointee=valeur...]');
    }

    $data = [];

    foreach (array_slice($argv, 3) as $pair) {
        $parts = explode('=', $pair, 2);

        if (count($parts) !== 2) {
            fail("Entrée invalide, format attendu cle.pointee=valeur : {$pair}");
        }

        write_path($data, split_path($parts[0]), $parts[1]);
    }

    try {
        $json = json_encode(
            $data,
            JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR
        );
    } catch (JsonException $exception) {
        fail('Manifeste impossible à sérialiser : '.$exception->getMessage());
    }

    if (file_put_contents($file, $json."\n") === false) {
        fail("Écriture impossible : {$file}");
    }

    exit(0);
}

if ($command === 'get') {
    $file = $argv[2] ?? '';
    $path = $argv[3] ?? '';

    if ($file === '' || $path === '') {
        fail('Usage : manifest.php get <fichier> <cle.pointee>');
    }

    $value = read_path(read_manifest($file), split_path($path));

    if (is_array($value)) {
        echo json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR)."\n";

        exit(0);
    }

    echo (string) $value."\n";

    exit(0);
}

if ($command === 'validate') {
    $file = $argv[2] ?? '';

    if ($file === '') {
        fail('Usage : manifest.php validate <fichier>');
    }

    validate_manifest(read_manifest($file));

    exit(0);
}

fail('Usage : manifest.php <create|get|validate> ...');
