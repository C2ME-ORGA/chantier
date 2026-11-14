<?php

declare(strict_types=1);

/**
 * Règles communes de détection des commandes de migration dans les workflows.
 *
 * Seul le job `mariadb` de `.github/workflows/tests.yml` peut exécuter les
 * commandes retournées par c2me_allowed_migration_commands(). Toute autre
 * occurrence, y compris dans ce job, est refusée.
 */

/**
 * @return list<string>
 */
function c2me_allowed_migration_commands(): array
{
    return [
        'php artisan migrate:fresh --force --no-interaction',
        'php artisan migrate:status --no-ansi',
        'php scripts/ci/verify-mariadb-migrations.php',
    ];
}

/**
 * Indique si une ligne de script mentionne une commande de migration.
 *
 * La détection couvre les commandes artisan, les commandes migrate:* et
 * db:wipe, ainsi que le script de vérification des migrations. Une ligne
 * chaînée reste détectée : elle ne peut donc pas être assimilée à une
 * commande autorisée par simple présence d'un fragment attendu.
 */
function c2me_line_mentions_migration(string $line): bool
{
    return preg_match(
        '/\b(?:artisan\s+(?:migrate(?::[a-z]+)?|db:wipe)|migrate:(?:fresh|refresh|reset|rollback)|db:wipe|verify-mariadb-migrations\.php)\b/i',
        $line
    ) === 1;
}

/**
 * Analyse les scripts `run` de chaque job et retourne les violations.
 *
 * @param  array<string, mixed>  $workflow
 * @return list<array{job: string, line: string}>
 */
function c2me_workflow_migration_violations(array $workflow, ?string $allowedJob = null): array
{
    $allowedCommands = c2me_allowed_migration_commands();
    $jobs = is_array($workflow['jobs'] ?? null) ? $workflow['jobs'] : [];
    $violations = [];

    foreach ($jobs as $jobName => $job) {
        if (! is_array($job)) {
            continue;
        }

        $steps = is_array($job['steps'] ?? null) ? $job['steps'] : [];

        foreach ($steps as $step) {
            if (! is_array($step) || ! is_string($step['run'] ?? null)) {
                continue;
            }

            foreach (preg_split('/\R/', $step['run']) ?: [] as $line) {
                $line = trim($line);

                if ($line === '' || str_starts_with($line, '#')) {
                    continue;
                }

                if (! c2me_line_mentions_migration($line)) {
                    continue;
                }

                if ((string) $jobName === $allowedJob && in_array($line, $allowedCommands, true)) {
                    continue;
                }

                $violations[] = [
                    'job' => (string) $jobName,
                    'line' => $line,
                ];
            }
        }
    }

    return $violations;
}
