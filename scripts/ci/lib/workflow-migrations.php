<?php

declare(strict_types=1);

/**
 * Règles communes de détection des commandes de migration dans les workflows.
 *
 * Seuls les jobs `mariadb` et `sqlite` de `.github/workflows/tests.yml` peuvent
 * exécuter leurs commandes de migration respectives. Toute autre occurrence,
 * y compris dans ces jobs, est refusée.
 */

/**
 * Retourne les commandes autorisées, par job de `.github/workflows/tests.yml`.
 *
 * @return array<string, list<string>>
 */
function c2me_allowed_migration_commands_by_job(): array
{
    return [
        'mariadb' => [
            'php artisan migrate:fresh --force --no-interaction',
            'php artisan migrate:status --no-ansi',
            'php scripts/ci/verify-mariadb-migrations.php',
        ],
        'sqlite' => [
            'php artisan migrate --force --no-interaction',
            'php artisan migrate:status --no-ansi',
            'php scripts/ci/verify-sqlite-migrations.php',
        ],
    ];
}

/**
 * Retourne les commandes autorisées pour un job, ou pour tous les jobs.
 *
 * @return list<string>
 */
function c2me_allowed_migration_commands(?string $job = null): array
{
    $commandsByJob = c2me_allowed_migration_commands_by_job();

    if ($job !== null) {
        return $commandsByJob[$job] ?? [];
    }

    return array_values(array_unique(array_merge(...array_values($commandsByJob))));
}

/**
 * Reconstitue les lignes logiques d'un script shell.
 *
 * Une barre oblique inverse en fin de ligne poursuit la commande sur la ligne
 * suivante. Les deux lignes sont fusionnées avant l'analyse afin qu'une
 * commande fractionnée ne puisse pas échapper au contrôle.
 *
 * @return list<string>
 */
function c2me_logical_lines(string $script): array
{
    $lines = preg_split('/\R/', $script) ?: [];
    $logicalLines = [];
    $buffer = '';
    $continuing = false;

    foreach ($lines as $line) {
        $buffer = $continuing ? $buffer.' '.$line : $line;
        $trimmed = rtrim($buffer);
        $backslashes = strlen($trimmed) - strlen(rtrim($trimmed, '\\'));
        $continuing = $backslashes % 2 === 1;

        if ($continuing) {
            $buffer = substr($trimmed, 0, -1);

            continue;
        }

        $logicalLines[] = $buffer;
        $buffer = '';
    }

    if ($buffer !== '') {
        $logicalLines[] = $buffer;
    }

    return $logicalLines;
}

/**
 * Supprime un commentaire shell non quoté.
 *
 * Un dièse n'ouvre un commentaire que s'il commence un mot. Les dièses
 * présents dans une valeur ou entre guillemets sont conservés.
 */
function c2me_strip_shell_comment(string $line): string
{
    $singleQuoted = false;
    $doubleQuoted = false;
    $length = strlen($line);

    for ($index = 0; $index < $length; $index++) {
        $character = $line[$index];

        if ($character === '\\' && ! $singleQuoted) {
            $index++;

            continue;
        }

        if ($character === "'" && ! $doubleQuoted) {
            $singleQuoted = ! $singleQuoted;

            continue;
        }

        if ($character === '"' && ! $singleQuoted) {
            $doubleQuoted = ! $doubleQuoted;

            continue;
        }

        if ($character === '#' && ! $singleQuoted && ! $doubleQuoted
            && ($index === 0 || ctype_space($line[$index - 1]))) {
            return rtrim(substr($line, 0, $index));
        }
    }

    return $line;
}

/**
 * Prépare une ligne pour la détection : retire les échappements et les
 * guillemets simples ou doubles, puis normalise les espaces.
 *
 * Cette forme sert uniquement à détecter les commandes. L'autorisation exige
 * toujours une correspondance exacte avec la ligne d'origine normalisée.
 */
function c2me_dequote_for_analysis(string $line): string
{
    $line = preg_replace('/\\\\(.)/s', '$1', $line) ?? $line;
    $line = str_replace(["'", '"'], '', $line);

    return preg_replace('/\s+/', ' ', trim($line)) ?? $line;
}

/**
 * Indique si une ligne déquotée mentionne une commande de migration.
 *
 * La détection couvre les commandes artisan, les commandes migrate:* et
 * db:wipe, ainsi que le script de vérification des migrations. La recherche
 * n'est pas ancrée : les affectations d'environnement et les commandes
 * chaînées restent donc détectées.
 */
function c2me_line_mentions_migration(string $line): bool
{
    return preg_match(
        '/\b(?:artisan\s+(?:migrate(?::[a-z]+)?|db:wipe)|migrate:(?:fresh|refresh|reset|rollback)|db:wipe|verify-(?:mariadb|sqlite)-migrations\.php)\b/i',
        $line
    ) === 1;
}

/**
 * Analyse les scripts `run` de chaque job et retourne les violations.
 *
 * Une ligne logique n'est autorisée que si sa forme normalisée correspond
 * exactement à une commande autorisée pour le job courant. Toute autre ligne
 * contenant une migration est refusée, y compris les commandes préfixées,
 * chaînées, piped, quotées ou reconstituées.
 *
 * @param  array<string, mixed>  $workflow
 * @param  string|list<string>|null  $allowedJobs
 * @return list<array{job: string, line: string}>
 */
function c2me_workflow_migration_violations(array $workflow, array|string|null $allowedJobs = null): array
{
    $allowedJobs = $allowedJobs === null ? [] : (array) $allowedJobs;
    $jobs = is_array($workflow['jobs'] ?? null) ? $workflow['jobs'] : [];
    $violations = [];

    foreach ($jobs as $jobName => $job) {
        if (! is_array($job)) {
            continue;
        }

        $jobName = (string) $jobName;
        $allowedCommands = in_array($jobName, $allowedJobs, true)
            ? c2me_allowed_migration_commands($jobName)
            : [];

        $steps = is_array($job['steps'] ?? null) ? $job['steps'] : [];

        foreach ($steps as $step) {
            if (! is_array($step) || ! is_string($step['run'] ?? null)) {
                continue;
            }

            foreach (c2me_logical_lines($step['run']) as $logicalLine) {
                $line = c2me_strip_shell_comment($logicalLine);
                $line = preg_replace('/\s+/', ' ', trim($line)) ?? $line;

                if ($line === '') {
                    continue;
                }

                if (in_array($line, $allowedCommands, true)) {
                    continue;
                }

                if (! c2me_line_mentions_migration(c2me_dequote_for_analysis($line))) {
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
