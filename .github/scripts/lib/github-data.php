<?php

declare(strict_types=1);

/**
 * Extrait les champs utiles des réponses JSON de l'API GitHub Actions.
 *
 * Ce script évite de dépendre de `jq` sur le runner et reste testable avec des
 * réponses figées. Il écrit des lignes TSV sur la sortie standard.
 *
 * Usage :
 *   php github-data.php runs <fichier-json> <branche-ou-tag>
 *   php github-data.php artifacts <fichier-json> <nom>
 *   php github-data.php count <fichier-json> <workflow_runs|artifacts>
 *
 * `runs` retourne : id, status, conclusion, head_sha, head_branch, event, path, created_at
 * `artifacts` retourne : id, expired, name, size_in_bytes
 * `count` retourne le nombre d'éléments de la page, utilisé pour la pagination.
 */

function fail(string $message): never
{
    fwrite(STDERR, $message."\n");

    exit(1);
}

/**
 * @return array<string, mixed>
 */
function read_json(string $file): array
{
    if (! is_file($file) || ! is_readable($file)) {
        fail("Fichier JSON introuvable ou illisible : {$file}");
    }

    try {
        $decoded = json_decode((string) file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        fail("Réponse JSON invalide ({$file}) : {$exception->getMessage()}");
    }

    if (! is_array($decoded)) {
        fail("La réponse {$file} doit contenir un objet JSON.");
    }

    return $decoded;
}

/**
 * @param  array<string, mixed>  $data
 * @return array<int, array<string, mixed>>
 */
function list_of(array $data, string $key): array
{
    $items = $data[$key] ?? [];

    if (! is_array($items)) {
        fail("Le champ {$key} doit être une liste.");
    }

    return array_values(array_filter($items, 'is_array'));
}

/**
 * @param  array<string, mixed>  $item
 */
function field(array $item, string $key): string
{
    $value = $item[$key] ?? '';

    if (is_bool($value)) {
        return $value ? 'true' : 'false';
    }

    return is_scalar($value) ? (string) $value : '';
}

$command = $argv[1] ?? '';
$file = $argv[2] ?? '';

if ($command === 'runs') {
    $branch = $argv[3] ?? '';

    if ($file === '' || $branch === '') {
        fail('Usage : github-data.php runs <fichier-json> <branche-ou-tag>');
    }

    foreach (list_of(read_json($file), 'workflow_runs') as $run) {
        if (field($run, 'head_branch') !== $branch) {
            continue;
        }

        printf(
            "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
            field($run, 'id'),
            field($run, 'status'),
            field($run, 'conclusion'),
            field($run, 'head_sha'),
            field($run, 'head_branch'),
            field($run, 'event'),
            field($run, 'path'),
            field($run, 'created_at')
        );
    }

    exit(0);
}

if ($command === 'artifacts') {
    $name = $argv[3] ?? '';

    if ($file === '' || $name === '') {
        fail('Usage : github-data.php artifacts <fichier-json> <nom>');
    }

    foreach (list_of(read_json($file), 'artifacts') as $artifact) {
        if (field($artifact, 'name') !== $name) {
            continue;
        }

        printf(
            "%s\t%s\t%s\t%s\n",
            field($artifact, 'id'),
            field($artifact, 'expired'),
            field($artifact, 'name'),
            field($artifact, 'size_in_bytes')
        );
    }

    exit(0);
}

if ($command === 'count') {
    $key = $argv[3] ?? '';

    if ($file === '' || ! in_array($key, ['workflow_runs', 'artifacts'], true)) {
        fail('Usage : github-data.php count <fichier-json> <workflow_runs|artifacts>');
    }

    echo count(list_of(read_json($file), $key))."\n";

    exit(0);
}

fail('Usage : github-data.php <runs|artifacts|count> ...');
