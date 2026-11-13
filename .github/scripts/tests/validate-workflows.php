<?php

declare(strict_types=1);

/**
 * Valide la syntaxe et les invariants des workflows GitHub Actions.
 *
 * Ce script s'exécute dans le contrôle `ci` et peut être lancé localement :
 *   php .github/scripts/tests/validate-workflows.php
 */

use Symfony\Component\Yaml\Exception\ParseException;
use Symfony\Component\Yaml\Yaml;

require dirname(__DIR__, 3).'/vendor/autoload.php';

$projectRoot = dirname(__DIR__, 3);
$failures = [];
$checks = 0;

function check(bool $condition, string $message): void
{
    global $checks, $failures;

    $checks++;

    if (! $condition) {
        $failures[] = $message;
    }
}

/**
 * @return array<string, mixed>
 */
function parse_workflow(string $path, array &$failures): array
{
    try {
        $document = Yaml::parseFile($path);
    } catch (ParseException $exception) {
        $failures[] = "YAML invalide dans {$path} : {$exception->getMessage()}";

        return [];
    }

    if (! is_array($document)) {
        $failures[] = "Le workflow {$path} doit contenir une mapping YAML.";

        return [];
    }

    return $document;
}

/**
 * @param  array<string, mixed>  $workflow
 * @return array<string, mixed>
 */
function triggers(array $workflow): array
{
    $on = $workflow['on'] ?? $workflow[true] ?? $workflow['true'] ?? [];

    return is_array($on) ? $on : [];
}

function job_environment(mixed $environment): string
{
    if (is_array($environment)) {
        return (string) ($environment['name'] ?? '');
    }

    return is_string($environment) ? $environment : '';
}

function workflow_paths(string $directory): array
{
    $paths = glob($directory.'/*.yml') ?: [];
    sort($paths);

    return $paths;
}

$workflowDirectory = $projectRoot.'/.github/workflows';
$workflowPaths = workflow_paths($workflowDirectory);

check(count($workflowPaths) >= 4, 'Les workflows de tests, de release et de déploiement doivent être présents.');

$documents = [];

foreach ($workflowPaths as $path) {
    $name = basename($path);
    $documents[$name] = parse_workflow($path, $failures);

    if ($documents[$name] === []) {
        continue;
    }

    check(isset($documents[$name]['jobs']) && is_array($documents[$name]['jobs']), "{$name} doit déclarer des jobs.");

    $raw = (string) file_get_contents($path);
    check(! str_contains($raw, 'StrictHostKeyChecking=no'), "{$name} ne doit jamais désactiver la vérification de l'hôte SSH.");

    preg_match_all('/^\s*uses:\s+(\S+)(?:\s+#\s*(\S+))?\s*$/m', $raw, $matches, PREG_SET_ORDER);

    foreach ($matches as $match) {
        $reference = $match[1];
        $comment = $match[2] ?? '';

        check(
            (bool) preg_match('/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+@[0-9a-f]{40}$/', $reference),
            "{$name} : l'action {$reference} doit être épinglée sur un SHA complet."
        );

        check(
            (bool) preg_match('/^v[0-9]/', $comment),
            "{$name} : l'action {$reference} doit documenter sa version en commentaire."
        );
    }
}

$staging = $documents['deploy-staging.yml'] ?? [];

if ($staging !== []) {
    $stagingTriggers = triggers($staging);
    $rawStaging = (string) file_get_contents($workflowDirectory.'/deploy-staging.yml');

    check(isset($stagingTriggers['push']['tags']) && $stagingTriggers['push']['tags'] === ['v*-rc.*'], 'deploy-staging doit être déclenché par les tags v*-rc.*.');
    check(! isset($stagingTriggers['release']), 'deploy-staging ne doit pas être déclenché par une release.');
    check(($staging['permissions'] ?? []) === ['contents' => 'read', 'actions' => 'read'], 'deploy-staging doit limiter les permissions à contents:read et actions:read.');
    check(($staging['concurrency']['group'] ?? '') === 'deploy-staging', 'deploy-staging doit utiliser une concurrence dédiée.');
    check(($staging['concurrency']['cancel-in-progress'] ?? null) === false, 'deploy-staging ne doit jamais annuler un déploiement en cours.');
    check(job_environment($staging['jobs']['deploy']['environment'] ?? null) === 'staging', 'deploy-staging doit déclarer l\'environnement staging.');
    check(str_contains($rawStaging, 'remote-deploy.sh'), 'deploy-staging doit utiliser le script de déploiement serveur.');
    check(str_contains($rawStaging, 'remote-check.sh'), 'deploy-staging doit exécuter les contrôles post-déploiement.');
    check(str_contains($rawStaging, 'retention-days: 90'), 'deploy-staging doit conserver les artefacts 90 jours.');
    check(! str_contains($rawStaging, 'artisan migrate'), 'deploy-staging ne doit exécuter aucune migration.');
}

$production = $documents['deploy-production.yml'] ?? [];

if ($production !== []) {
    $productionTriggers = triggers($production);
    $rawProduction = (string) file_get_contents($workflowDirectory.'/deploy-production.yml');
    $productionJobs = $production['jobs'] ?? [];

    check(($productionTriggers['release']['types'] ?? []) === ['published'], 'deploy-production doit être déclenché par release.published.');
    check(isset($productionJobs['validate-promotion']), 'deploy-production doit déclarer un job validate-promotion.');
    check(! array_key_exists('environment', $productionJobs['validate-promotion'] ?? []), 'validate-promotion ne doit pas être protégé par un environnement GitHub.');
    check(str_contains((string) ($productionJobs['validate-promotion']['if'] ?? ''), 'prerelease'), 'validate-promotion doit exclure les préreleases.');
    check(str_contains((string) ($productionJobs['validate-promotion']['outputs']['candidate_tag'] ?? ''), 'promotion'), 'validate-promotion doit transmettre la candidate validée.');
    check(($production['permissions'] ?? []) === ['contents' => 'read', 'actions' => 'read'], 'deploy-production doit limiter les permissions à contents:read et actions:read.');
    check(($production['concurrency']['group'] ?? '') === 'deploy-production', 'deploy-production doit utiliser une concurrence dédiée.');
    check(($production['concurrency']['cancel-in-progress'] ?? null) === false, 'deploy-production ne doit jamais annuler un déploiement en cours.');
    check(job_environment($productionJobs['deploy']['environment'] ?? null) === 'production', 'deploy-production doit déclarer l\'environnement production.');
    check(($productionJobs['deploy']['needs'] ?? null) === 'validate-promotion', 'deploy-production doit dépendre de validate-promotion.');
    check(str_contains((string) ($productionJobs['deploy']['if'] ?? ''), 'prerelease'), 'deploy-production doit exclure les préreleases.');
    check(str_contains($rawProduction, 'resolve-promotion.sh'), 'deploy-production doit vérifier la promotion staging.');
    check(str_contains($rawProduction, 'Revalidate stable tag'), 'deploy-production doit revalider le tag stable dans le job protégé.');
    check(str_contains($rawProduction, 'validate-tag.sh'), 'deploy-production doit recalculer le commit et l\'arbre du tag.');
    check(str_contains($rawProduction, 'RELEASE_COMMIT'), 'deploy-production doit comparer le commit recalculé aux outputs validés.');
    check(str_contains($rawProduction, 'RELEASE_TREE'), 'deploy-production doit comparer l\'arbre recalculé aux outputs validés.');
    check(str_contains($rawProduction, 'gh run download'), 'deploy-production doit télécharger l\'artefact de staging.');
    check(str_contains($rawProduction, 'PACKAGE_SHA256'), 'deploy-production doit vérifier l\'empreinte de l\'artefact téléchargé.');
    check(str_contains($rawProduction, 'remote-deploy.sh'), 'deploy-production doit utiliser le script de déploiement serveur.');
    check(str_contains($rawProduction, 'retention-days: 90'), 'deploy-production doit conserver son manifeste 90 jours.');
    check(! str_contains($rawProduction, 'artisan migrate'), 'deploy-production ne doit exécuter aucune migration.');
    check(! str_contains($rawProduction, 'npm run build'), 'deploy-production ne doit jamais reconstruire l\'application.');

    $deployOffset = strpos($rawProduction, '  deploy:');

    if ($deployOffset !== false) {
        $unprotectedSection = substr($rawProduction, 0, $deployOffset);
        check(! str_contains($unprotectedSection, 'secrets.SSH_'), 'Aucun secret SSH ne doit être accessible au job de validation.');
    } else {
        check(false, 'Le job deploy-production doit être identifiable dans le workflow.');
    }
}

$release = $documents['release.yml'] ?? [];

if ($release !== []) {
    $releaseTriggers = triggers($release);
    $rawRelease = (string) file_get_contents($workflowDirectory.'/release.yml');

    check(($releaseTriggers['push']['tags'] ?? []) === ['v*'], 'release doit rester déclenché par les tags v*.');
    check(str_contains($rawRelease, '--prerelease'), 'release doit continuer à publier les candidates en prérelease.');
    check(str_contains($rawRelease, '--draft'), 'release doit continuer à créer les versions stables en brouillon.');
    check(str_contains($rawRelease, 'stable-candidate.sh'), 'release doit référencer la candidate staging des versions stables.');
    check(
        strpos($rawRelease, 'stable-candidate.sh') < strpos($rawRelease, 'name: Create or update GitHub release'),
        'La référence de candidate doit être ajoutée avant la création de la release.'
    );
}

$tests = $documents['tests.yml'] ?? [];

if ($tests !== []) {
    $rawTests = (string) file_get_contents($workflowDirectory.'/tests.yml');

    check(str_contains($rawTests, 'test-deployment-automation.sh'), 'tests.yml doit exécuter les tests de déploiement.');
    check(str_contains($rawTests, 'validate-workflows.php'), 'tests.yml doit valider les workflows.');
    check(str_contains($rawTests, 'test-assemble-linux.sh'), 'tests.yml doit exécuter le test d\'assemblage Linux.');
    check(isset(($tests['jobs'] ?? [])['package-linux']), 'tests.yml doit définir le job package-linux.');
}

foreach ($failures as $failure) {
    fwrite(STDERR, "ÉCHEC: {$failure}\n");
}

printf("%d contrôles exécutés, %d échec(s).\n", $checks, count($failures));

exit($failures === [] ? 0 : 1);
