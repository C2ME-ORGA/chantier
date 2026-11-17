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
require_once $projectRoot.'/scripts/ci/lib/workflow-migrations.php';
require_once $projectRoot.'/scripts/ci/lib/workflow-configuration.php';
require_once $projectRoot.'/scripts/ci/lib/composer-scripts.php';
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

/**
 * Retourne le nom affiché d'un job, ou null si sa déclaration est inexploitable.
 *
 * GitHub Actions affiche l'identifiant du job lorsqu'aucun `name` n'est déclaré.
 *
 * @param  array<string, mixed>  $jobs
 */
function job_display_name(array $jobs, string $jobId): ?string
{
    $job = $jobs[$jobId] ?? null;

    if (! is_array($job)) {
        return null;
    }

    if (! array_key_exists('name', $job)) {
        return $jobId;
    }

    return is_string($job['name']) && $job['name'] !== '' ? $job['name'] : null;
}

function workflow_paths(string $directory): array
{
    $paths = glob($directory.'/*.yml') ?: [];
    sort($paths);

    return $paths;
}

/**
 * Retourne les scripts `run` déclarés directement dans les étapes d'un job.
 *
 * @param  array<string, mixed>  $job
 * @return list<string>
 */
function job_run_scripts(array $job): array
{
    $steps = is_array($job['steps'] ?? null) ? $job['steps'] : [];
    $scripts = [];

    foreach ($steps as $step) {
        if (is_array($step) && is_string($step['run'] ?? null)) {
            $scripts[] = $step['run'];
        }
    }

    return $scripts;
}

/**
 * Vérifie qu'une commande est exécutée sur une ligne exacte d'un script `run`.
 *
 * Une ligne commentée ou une simple mention dans un autre texte ne compte pas.
 *
 * @param  list<string>  $scripts
 */
function runs_exact_command(array $scripts, string $command): bool
{
    foreach ($scripts as $script) {
        foreach (preg_split('/\R/', $script) ?: [] as $line) {
            if (trim($line) === $command) {
                return true;
            }
        }
    }

    return false;
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

    $migrationViolations = c2me_workflow_migration_violations(
        $documents[$name],
        $name === 'tests.yml' ? ['mariadb', 'sqlite'] : null
    );

    $migrationDetails = array_map(
        static fn (array $violation): string => "job {$violation['job']} : {$violation['line']}",
        $migrationViolations
    );

    check(
        $migrationViolations === [],
        "{$name} : commande de migration non autorisée (".implode(' | ', $migrationDetails).').'
    );

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
    $jobs = is_array($tests['jobs'] ?? null) ? $tests['jobs'] : [];
    $testsTriggers = triggers($tests);

    check(array_key_exists('push', $testsTriggers), 'tests.yml doit être déclenché par un push.');
    check(array_key_exists('pull_request', $testsTriggers), 'tests.yml doit être déclenché par une pull_request.');
    check(! array_key_exists('release', $testsTriggers), 'tests.yml ne doit pas être déclenché par une release.');
    check(! isset($testsTriggers['push']['tags']), 'tests.yml ne doit pas être déclenché par un tag de release.');

    $configuredEvents = c2me_workflow_event_names($testsTriggers);

    check(
        $configuredEvents !== null,
        'tests.yml : les noms d\'événements déclarés doivent être textuels.'
    );
    check(
        $configuredEvents === ['pull_request', 'push'],
        'tests.yml doit configurer exactement les événements push et pull_request (configuré : '.implode(', ', $configuredEvents ?? []).').'
    );

    $expectedBranches = ['develop', 'main'];
    sort($expectedBranches);

    foreach (['push', 'pull_request'] as $event) {
        $branches = c2me_workflow_trigger_branches($testsTriggers, $event);

        check(
            $branches !== null,
            "tests.yml : les branches de l'événement {$event} doivent être une liste de valeurs textuelles."
        );

        if ($branches === null) {
            continue;
        }

        $sortedBranches = $branches;
        sort($sortedBranches);

        check(
            $sortedBranches === $expectedBranches,
            "tests.yml doit cibler exactement les branches develop et main pour l'événement {$event} (configuré : ".implode(', ', $branches).').'
        );
    }

    check(
        ($tests['permissions'] ?? []) === ['contents' => 'read'],
        'tests.yml doit limiter les permissions à contents:read.'
    );

    $expectedJobs = [
        'ci' => 'ci',
        'sqlite' => 'sqlite',
        'mariadb' => 'mariadb-10.11',
        'package-linux' => 'package-linux',
    ];

    $declaredJobs = array_map(
        static fn (string|int $job): string => (string) $job,
        array_keys($jobs)
    );
    $expectedJobIds = array_keys($expectedJobs);
    sort($declaredJobs);
    sort($expectedJobIds);

    check(
        $declaredJobs === $expectedJobIds,
        'tests.yml doit déclarer exactement les jobs ci, sqlite, mariadb et package-linux (déclaré : '.implode(', ', $declaredJobs).').'
    );

    foreach ($expectedJobs as $jobId => $expectedJobName) {
        $jobName = job_display_name($jobs, $jobId);

        check(
            $jobName === $expectedJobName,
            "tests.yml : le job {$jobId} doit être affiché sous le nom {$expectedJobName} (configuré : ".($jobName ?? 'aucun').').'
        );
    }

    $deploymentJobs = array_values(array_filter(
        array_keys($jobs),
        static fn (string|int $job): bool => preg_match('/(?:release|deploy)/i', (string) $job) === 1
    ));

    check(
        $deploymentJobs === [],
        'tests.yml ne doit contenir aucun job de release ou de déploiement (trouvé : '.implode(', ', $deploymentJobs).').'
    );

    foreach ($jobs as $jobName => $job) {
        if (! is_array($job)) {
            continue;
        }

        check(
            ! array_key_exists('needs', $job),
            "tests.yml : le job {$jobName} ne doit pas déclarer de dépendance needs."
        );
        check(
            ! array_key_exists('environment', $job),
            "tests.yml : le job {$jobName} ne doit pas cibler un environnement de déploiement."
        );
        check(
            ($job['continue-on-error'] ?? false) !== true,
            "tests.yml : le job {$jobName} ne doit pas masquer ses échecs avec continue-on-error."
        );

        $steps = is_array($job['steps'] ?? null) ? $job['steps'] : [];

        foreach ($steps as $index => $step) {
            if (! is_array($step)) {
                continue;
            }

            check(
                ($step['continue-on-error'] ?? false) !== true,
                "tests.yml : l'étape {$index} du job {$jobName} ne doit pas masquer ses échecs avec continue-on-error."
            );

            $script = $step['run'] ?? null;

            check(
                ! is_string($script) || preg_match('/(?:^|\s)\|\|\s*true(?:\s|$)/', $script) !== 1,
                "tests.yml : l'étape {$index} du job {$jobName} ne doit pas masquer un échec avec || true."
            );
        }
    }

    check(! str_contains($rawTests, 'secrets.SSH_'), 'tests.yml ne doit référencer aucun secret SSH.');

    $packageLinuxJob = is_array($jobs['package-linux'] ?? null) ? $jobs['package-linux'] : [];
    $packageLinuxScripts = job_run_scripts($packageLinuxJob);

    check(
        runs_exact_command($packageLinuxScripts, 'bash .github/scripts/tests/test-assemble-linux.sh'),
        'Le job package-linux doit exécuter le test d\'assemblage Linux.'
    );

    $ciJob = is_array($jobs['ci'] ?? null) ? $jobs['ci'] : [];
    $ciScripts = job_run_scripts($ciJob);

    check($ciJob !== [], 'tests.yml doit définir le job ci.');
    check(runs_exact_command($ciScripts, 'composer ci:check'), 'Le job ci doit exécuter composer ci:check dans une étape run.');
    check(runs_exact_command($ciScripts, 'npm ci'), 'Le job ci doit installer les dépendances Node avec npm ci dans une étape run.');
    check(runs_exact_command($ciScripts, 'npm run build'), 'Le job ci doit exécuter npm run build dans une étape run.');
    check(
        runs_exact_command($ciScripts, 'php scripts/ci/verify-vite-build.php'),
        'Le job ci doit vérifier le manifest Vite et ses fichiers avec scripts/ci/verify-vite-build.php.'
    );
    check(runs_exact_command($ciScripts, 'touch database/database.sqlite'), 'Le job ci doit préparer database/database.sqlite dans une étape run.');
    check(
        runs_exact_command($ciScripts, 'php .github/scripts/tests/validate-workflows.php'),
        'Le job ci doit valider les workflows avec validate-workflows.php.'
    );
    check(
        runs_exact_command($ciScripts, 'bash .github/scripts/tests/test-deployment-automation.sh'),
        'Le job ci doit exécuter les tests de déploiement.'
    );

    $composerJsonPath = $projectRoot.'/composer.json';
    $composerJson = json_decode((string) file_get_contents($composerJsonPath), true);
    $composerData = is_array($composerJson) ? $composerJson : [];
    $composerScripts = is_array($composerData['scripts'] ?? null) ? $composerData['scripts'] : [];
    $ciCommands = c2me_composer_script_commands($composerScripts, 'ci:check');
    $requireDev = is_array($composerData['require-dev'] ?? null) ? $composerData['require-dev'] : [];

    check($composerData !== [], 'composer.json doit être un document JSON valide.');
    check($ciCommands !== [], 'composer.json doit définir un script ci:check exploitable.');
    check(
        in_array('pint --parallel --test', $ciCommands, true),
        'composer ci:check doit exécuter Laravel Pint en mode vérification.'
    );
    check(
        in_array('phpstan analyse', $ciCommands, true),
        'composer ci:check doit exécuter Larastan/PHPStan.'
    );
    check(
        array_filter(
            $ciCommands,
            static fn (string $command): bool => preg_match('/(?:^|\s)artisan test(?:\s|$)/', $command) === 1
        ) !== [],
        'composer ci:check doit exécuter Pest via php artisan test.'
    );
    check(isset($requireDev['laravel/pint']), 'composer.json doit déclarer Laravel Pint.');
    check(isset($requireDev['larastan/larastan']), 'composer.json doit déclarer Larastan.');
    check(isset($requireDev['pestphp/pest']), 'composer.json doit déclarer Pest.');

    $sqliteJob = is_array($jobs['sqlite'] ?? null) ? $jobs['sqlite'] : [];
    $sqliteJobEnv = is_array($sqliteJob['env'] ?? null) ? $sqliteJob['env'] : [];

    check($sqliteJob !== [], 'tests.yml doit définir un job sqlite dédié.');
    check(! array_key_exists('services', $sqliteJob), 'Le job sqlite ne doit dépendre d\'aucun service externe.');
    check(($sqliteJobEnv['DB_CONNECTION'] ?? null) === 'sqlite', 'Le job sqlite doit définir DB_CONNECTION=sqlite.');
    check(
        str_contains((string) ($sqliteJobEnv['DB_DATABASE'] ?? ''), 'database/testing.sqlite'),
        'Le job sqlite doit cibler le fichier dédié database/testing.sqlite.'
    );
    check(
        (string) ($sqliteJobEnv['DB_URL'] ?? '') === '',
        'Le job sqlite doit neutraliser DB_URL pour éviter une connexion externe.'
    );

    $sqliteSteps = is_array($sqliteJob['steps'] ?? null) ? $sqliteJob['steps'] : [];
    $sqlitePhpStep = [];

    foreach ($sqliteSteps as $step) {
        if (is_array($step) && str_starts_with((string) ($step['uses'] ?? ''), 'shivammathur/setup-php@')) {
            $sqlitePhpStep = $step;

            break;
        }
    }

    $sqlitePhpWith = is_array($sqlitePhpStep['with'] ?? null) ? $sqlitePhpStep['with'] : [];
    $sqliteExtensions = is_string($sqlitePhpWith['extensions'] ?? null)
        ? (preg_split('/[\s,]+/', trim($sqlitePhpWith['extensions']), -1, PREG_SPLIT_NO_EMPTY) ?: [])
        : [];

    check((string) ($sqlitePhpWith['php-version'] ?? '') === '8.4', 'Le job sqlite doit utiliser PHP 8.4.');
    check(in_array('pdo_sqlite', $sqliteExtensions, true), 'Le job sqlite doit installer l\'extension pdo_sqlite.');

    $sqliteScripts = job_run_scripts($sqliteJob);

    check(
        runs_exact_command($sqliteScripts, 'touch database/testing.sqlite'),
        'Le job sqlite doit préparer le fichier database/testing.sqlite dans une étape run.'
    );
    check(
        runs_exact_command($sqliteScripts, 'php scripts/ci/verify-sqlite.php'),
        'Le job sqlite doit vérifier la connexion SQLite avec scripts/ci/verify-sqlite.php.'
    );
    check(
        runs_exact_command($sqliteScripts, 'php artisan migrate --force --no-interaction'),
        'Le job sqlite doit exécuter les migrations sur le fichier dédié.'
    );
    check(
        runs_exact_command($sqliteScripts, 'php artisan migrate:status --no-ansi'),
        'Le job sqlite doit afficher l\'état des migrations.'
    );
    check(
        runs_exact_command($sqliteScripts, 'php scripts/ci/verify-sqlite-migrations.php'),
        'Le job sqlite doit vérifier que toutes les migrations sont appliquées.'
    );
    check(
        runs_exact_command($sqliteScripts, 'vendor/bin/pest --configuration=phpunit.sqlite.xml --colors=never'),
        'Le job sqlite doit exécuter la suite Pest avec phpunit.sqlite.xml.'
    );

    $sqlitePhpunitPath = $projectRoot.'/phpunit.sqlite.xml';
    check(is_file($sqlitePhpunitPath), 'phpunit.sqlite.xml doit exister pour la suite SQLite dédiée.');

    if (is_file($sqlitePhpunitPath)) {
        $sqlitePhpunit = (string) file_get_contents($sqlitePhpunitPath);
        $sqliteBootstrap = $projectRoot.'/tests/bootstrap-sqlite.php';

        check(
            str_contains($sqlitePhpunit, '<env name="DB_CONNECTION" value="sqlite" force="true"/>'),
            'phpunit.sqlite.xml doit forcer la connexion sqlite.'
        );
        check(
            str_contains($sqlitePhpunit, 'bootstrap="tests/bootstrap-sqlite.php"'),
            'phpunit.sqlite.xml doit utiliser le bootstrap SQLite dédié.'
        );

        foreach (['Unit', 'Feature', 'Architecture'] as $suite) {
            check(
                str_contains($sqlitePhpunit, "<directory>tests/{$suite}</directory>"),
                "phpunit.sqlite.xml doit déclarer la suite {$suite}."
            );
        }

        check(is_file($sqliteBootstrap), 'tests/bootstrap-sqlite.php doit exister.');

        if (is_file($sqliteBootstrap)) {
            $bootstrap = (string) file_get_contents($sqliteBootstrap);
            check(
                str_contains($bootstrap, "'DB_CONNECTION' => 'sqlite'"),
                'tests/bootstrap-sqlite.php doit forcer DB_CONNECTION=sqlite.'
            );
            check(
                str_contains($bootstrap, "'DB_DATABASE' => dirname(__DIR__).'/database/testing.sqlite'"),
                'tests/bootstrap-sqlite.php doit forcer le fichier database/testing.sqlite.'
            );
        }
    }

    $mariadbJob = is_array($jobs['mariadb'] ?? null) ? $jobs['mariadb'] : [];
    $mariadbService = is_array($mariadbJob['services']['mariadb'] ?? null) ? $mariadbJob['services']['mariadb'] : [];
    $serviceEnv = is_array($mariadbService['env'] ?? null) ? $mariadbService['env'] : [];
    $jobEnv = is_array($mariadbJob['env'] ?? null) ? $mariadbJob['env'] : [];

    check($mariadbJob !== [], 'tests.yml doit définir un job mariadb séparé du job SQLite.');
    check(($mariadbService['image'] ?? null) === 'mariadb:10.11', 'Le job mariadb doit utiliser l\'image mariadb:10.11.');

    $ports = [];

    if (is_array($mariadbService['ports'] ?? null)) {
        foreach ($mariadbService['ports'] as $port) {
            if (is_string($port) || is_int($port)) {
                $ports[] = (string) $port;
            }
        }
    }

    check(in_array('127.0.0.1:3306:3306', $ports, true), 'Le service mariadb doit exposer le port 3306 sur la boucle locale uniquement.');

    $healthcheck = (string) ($mariadbService['options'] ?? '');
    check(str_contains($healthcheck, '--health-cmd='), 'Le service mariadb doit définir un healthcheck.');
    check(str_contains($healthcheck, 'healthcheck.sh --connect --innodb_initialized'), 'Le healthcheck mariadb doit attendre la disponibilité effective du serveur.');
    check(str_contains($healthcheck, '--health-retries='), 'Le healthcheck mariadb doit définir un nombre de tentatives.');

    check(($serviceEnv['MARIADB_DATABASE'] ?? null) === 'chantier_test', 'Le service mariadb doit créer la base chantier_test.');
    check(($serviceEnv['MARIADB_USER'] ?? null) === 'chantier_test', 'Le service mariadb doit créer l\'utilisateur chantier_test.');

    $applicationPassword = (string) ($serviceEnv['MARIADB_PASSWORD'] ?? '');
    $rootPassword = (string) ($serviceEnv['MARIADB_ROOT_PASSWORD'] ?? '');

    check($applicationPassword !== '', 'Le service mariadb doit définir un mot de passe applicatif dédié à la CI.');
    check($rootPassword !== '', 'Le service mariadb doit définir un mot de passe root dédié à la CI.');
    check($applicationPassword !== $rootPassword, 'Les mots de passe applicatif et root du service mariadb doivent être distincts.');

    check(($jobEnv['DB_CONNECTION'] ?? null) === 'mariadb', 'Le job mariadb doit définir DB_CONNECTION=mariadb.');
    check(($jobEnv['DB_HOST'] ?? null) === '127.0.0.1', 'Le job mariadb doit définir DB_HOST=127.0.0.1.');
    check((string) ($jobEnv['DB_PORT'] ?? '') === '3306', 'Le job mariadb doit définir DB_PORT=3306.');
    check(($jobEnv['DB_DATABASE'] ?? null) === ($serviceEnv['MARIADB_DATABASE'] ?? null), 'La base du job mariadb doit correspondre à celle du service.');
    check(($jobEnv['DB_USERNAME'] ?? null) === ($serviceEnv['MARIADB_USER'] ?? null), 'L\'utilisateur du job mariadb doit correspondre à celui du service.');
    check(($jobEnv['DB_PASSWORD'] ?? null) === ($serviceEnv['MARIADB_PASSWORD'] ?? null), 'Le mot de passe du job mariadb doit correspondre à celui du service.');

    $mariadbSteps = is_array($mariadbJob['steps'] ?? null) ? $mariadbJob['steps'] : [];
    $phpStep = [];

    foreach ($mariadbSteps as $step) {
        if (is_array($step) && str_starts_with((string) ($step['uses'] ?? ''), 'shivammathur/setup-php@')) {
            $phpStep = $step;

            break;
        }
    }

    $phpWith = is_array($phpStep['with'] ?? null) ? $phpStep['with'] : [];
    $extensions = is_string($phpWith['extensions'] ?? null)
        ? (preg_split('/[\s,]+/', trim($phpWith['extensions']), -1, PREG_SPLIT_NO_EMPTY) ?: [])
        : [];

    check((string) ($phpWith['php-version'] ?? '') === '8.4', 'Le job mariadb doit utiliser PHP 8.4.');
    check(in_array('pdo_mysql', $extensions, true), 'Le job mariadb doit installer l\'extension pdo_mysql.');

    $mariadbScripts = job_run_scripts($mariadbJob);

    check(
        runs_exact_command($mariadbScripts, 'php scripts/ci/verify-mariadb.php'),
        'Le job mariadb doit exécuter scripts/ci/verify-mariadb.php dans une étape run.'
    );
    check(
        runs_exact_command($mariadbScripts, 'php artisan migrate:fresh --force --no-interaction'),
        'Le job mariadb doit exécuter les migrations sur la base isolée.'
    );
    check(
        runs_exact_command($mariadbScripts, 'php artisan migrate:status --no-ansi'),
        'Le job mariadb doit afficher l\'état des migrations.'
    );
    check(
        runs_exact_command($mariadbScripts, 'php scripts/ci/verify-mariadb-migrations.php'),
        'Le job mariadb doit vérifier que toutes les migrations sont appliquées.'
    );
    check(
        runs_exact_command($mariadbScripts, 'vendor/bin/pest --configuration=phpunit.mariadb.xml --colors=never'),
        'Le job mariadb doit exécuter la suite Pest MariaDB dédiée.'
    );

    $phpunitPath = $projectRoot.'/phpunit.xml';
    $phpunitXml = new DOMDocument();
    $phpunitXml->resolveExternals = false;
    $phpunitXml->substituteEntities = false;

    $phpunitLoaded = $phpunitXml->load($phpunitPath, LIBXML_NONET);
    check($phpunitLoaded, 'phpunit.xml doit être un document XML valide.');

    if ($phpunitLoaded) {
        $xpath = new DOMXPath($phpunitXml);
        $expectedEnvironment = [
            'APP_ENV' => 'testing',
            'DB_CONNECTION' => 'sqlite',
            'DB_DATABASE' => ':memory:',
            'DB_URL' => '',
        ];

        foreach ($expectedEnvironment as $name => $value) {
            $nodes = $xpath->query('/phpunit/php/env[@name="'.$name.'"]');
            $node = $nodes !== false && $nodes->length === 1 ? $nodes->item(0) : null;

            check(
                $node instanceof DOMElement && $node->getAttribute('value') === $value,
                "phpunit.xml doit définir {$name} avec la valeur attendue."
            );
            check(
                $node instanceof DOMElement && $node->getAttribute('force') === 'true',
                "phpunit.xml doit forcer {$name} pour isoler les tests SQLite."
            );
        }
    }

    $mariaDbConfigPath = $projectRoot.'/phpunit.mariadb.xml';
    check(is_file($mariaDbConfigPath), 'phpunit.mariadb.xml doit exister pour la suite MariaDB.');

    if (is_file($mariaDbConfigPath)) {
        $mariaDbConfig = (string) file_get_contents($mariaDbConfigPath);
        $mariaDbBootstrap = $projectRoot.'/tests/bootstrap-mariadb.php';

        check(
            str_contains($mariaDbConfig, '<env name="DB_CONNECTION" value="mariadb" force="true"/>'),
            'phpunit.mariadb.xml doit forcer la connexion mariadb.'
        );
        check(
            str_contains($mariaDbConfig, 'bootstrap="tests/bootstrap-mariadb.php"'),
            'phpunit.mariadb.xml doit utiliser le bootstrap MariaDB dédié.'
        );
        check(is_file($mariaDbBootstrap), 'tests/bootstrap-mariadb.php doit exister.');

        if (is_file($mariaDbBootstrap)) {
            $bootstrap = (string) file_get_contents($mariaDbBootstrap);
            check(
                str_contains($bootstrap, "'DB_CONNECTION' => 'mariadb'"),
                'tests/bootstrap-mariadb.php doit forcer DB_CONNECTION=mariadb.'
            );
        }
    }
}

foreach ($failures as $failure) {
    fwrite(STDERR, "ÉCHEC: {$failure}\n");
}

printf("%d contrôles exécutés, %d échec(s).\n", $checks, count($failures));

exit($failures === [] ? 0 : 1);
