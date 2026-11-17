#!/usr/bin/env php
<?php

declare(strict_types=1);

use Symfony\Component\Yaml\Exception\ParseException;
use Symfony\Component\Yaml\Yaml;

/**
 * Vérifie les commandes de migration d'un workflow GitHub Actions.
 *
 *   php scripts/ci/check-workflow-migrations.php <workflow.yml> [jobs-autorisés]
 *
 * Sans second argument, aucune commande de migration n'est autorisée.
 * Avec `mariadb` ou `sqlite`, seules les commandes déclarées pour ce job par
 * c2me_allowed_migration_commands_by_job() sont tolérées, à l'identique et
 * sans chaînage. Plusieurs jobs peuvent être séparés par des virgules.
 */
$projectRoot = dirname(__DIR__, 2);

require $projectRoot.'/vendor/autoload.php';
require_once __DIR__.'/lib/workflow-migrations.php';

$path = $argv[1] ?? null;
$allowedJobArgument = trim((string) ($argv[2] ?? ''));
$allowedJobs = $allowedJobArgument === ''
    ? null
    : array_values(array_filter(array_map('trim', explode(',', $allowedJobArgument))));

if ($path === null) {
    fwrite(STDERR, "Usage : php scripts/ci/check-workflow-migrations.php <workflow.yml> [jobs-autorisés]\n");

    exit(2);
}

try {
    $workflow = Yaml::parseFile($path);
} catch (ParseException $exception) {
    fwrite(STDERR, sprintf("YAML invalide dans %s : %s\n", $path, $exception->getMessage()));

    exit(2);
}

if (! is_array($workflow)) {
    fwrite(STDERR, sprintf("Le workflow %s doit contenir une mapping YAML.\n", $path));

    exit(2);
}

$violations = c2me_workflow_migration_violations($workflow, $allowedJobs);

if ($violations === []) {
    fwrite(STDOUT, sprintf("OK : aucune migration non autorisée dans %s.\n", basename($path)));

    exit(0);
}

foreach ($violations as $violation) {
    fwrite(STDERR, sprintf(
        "%s : job %s : commande de migration non autorisée : %s\n",
        basename($path),
        $violation['job'],
        $violation['line'],
    ));
}

exit(1);
