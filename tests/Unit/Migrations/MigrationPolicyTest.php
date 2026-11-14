<?php

use Illuminate\Database\Migrations\Migration;
use Symfony\Component\Yaml\Yaml;

require_once dirname(__DIR__, 3).'/scripts/ci/lib/workflow-migrations.php';

/**
 * Politique de migrations CHAN-98, lot 1.
 *
 * Ces tests sont statiques : ils vérifient des conventions de rédaction et
 * l'absence de migration automatique. Ils ne prouvent pas le comportement
 * MariaDB 10.11 et ne remplacent pas une répétition en staging.
 */
$migrationsPath = dirname(__DIR__, 3).'/database/migrations';
$policyStartDate = '2026_11_13';

/**
 * @return list<string>
 */
function chan98MigrationFiles(string $path): array
{
    $files = glob($path.'/*.php');

    if ($files === false) {
        return [];
    }

    sort($files);

    return array_values($files);
}

function chan98MigrationBody(string $contents, string $method): string
{
    $pattern = '/public function '.preg_quote($method, '/').'\(\)\s*:\s*void\s*\{(.*?)\n    \}/s';

    if (preg_match($pattern, $contents, $matches) !== 1) {
        return '';
    }

    return trim($matches[1]);
}

/**
 * @return list<string>
 */
function chan98ProjectFiles(string $directory, array $extensions): array
{
    if (! is_dir($directory)) {
        return [];
    }

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS)
    );

    $files = [];

    foreach ($iterator as $file) {
        if ($file->isFile() && in_array($file->getExtension(), $extensions, true)) {
            $files[] = $file->getPathname();
        }
    }

    sort($files);

    return $files;
}

test('les migrations respectent le nommage et retournent une classe anonyme', function () use ($migrationsPath): void {
    $files = chan98MigrationFiles($migrationsPath);

    expect($files)->not->toBeEmpty();

    $violations = [];

    foreach ($files as $file) {
        $name = basename($file);
        $contents = (string) file_get_contents($file);

        if (preg_match('/^\d{4}_\d{2}_\d{2}_\d{6}_[a-z0-9_]+\.php$/', $name) !== 1) {
            $violations[] = "{$name} : nom de migration invalide.";
        }

        if (! str_contains($contents, 'return new class extends Migration')) {
            $violations[] = "{$name} : la migration doit retourner une classe anonyme étendant Migration.";
        }

        $migration = require $file;

        if (! $migration instanceof Migration) {
            $violations[] = "{$name} : le fichier ne retourne pas une instance de Migration.";
        }
    }

    expect($violations)->toBe([]);
});

test('chaque migration fournit up et down non vides', function () use ($migrationsPath): void {
    $violations = [];

    foreach (chan98MigrationFiles($migrationsPath) as $file) {
        $name = basename($file);
        $contents = (string) file_get_contents($file);

        if (preg_match('/public function up\(\)\s*:\s*void/', $contents) !== 1) {
            $violations[] = "{$name} : méthode up() absente.";
        } elseif (chan98MigrationBody($contents, 'up') === '') {
            $violations[] = "{$name} : méthode up() vide.";
        }

        if (preg_match('/public function down\(\)\s*:\s*void/', $contents) !== 1) {
            $violations[] = "{$name} : méthode down() absente.";
        } elseif (chan98MigrationBody($contents, 'down') === '') {
            $violations[] = "{$name} : méthode down() vide.";
        }
    }

    expect($violations)->toBe([]);
});

test('up ne contient aucune opération destructrice sans annotation contract', function () use ($migrationsPath): void {
    $destructivePatterns = [
        '/->\s*drop[A-Za-z]*\s*\(/' => 'suppression de colonne, index ou contrainte',
        '/Schema::drop(?:IfExists)?\s*\(/' => 'suppression de table',
        '/->\s*rename[A-Za-z]*\s*\(/' => 'renommage de colonne ou d\'index',
        '/Schema::rename\s*\(/' => 'renommage de table',
        '/->\s*truncate\s*\(/' => 'troncature de table',
        '/\bforeign_key_checks\b/i' => 'désactivation des contrôles de clé étrangère',
        '/\b(?:migrate:(?:fresh|refresh|reset|rollback)|db:wipe)\b/i' => 'réinitialisation de base',
    ];

    $dataDestructivePatterns = [
        '/->\s*(?:force)?delete\s*\(/' => 'suppression de lignes',
    ];

    $violations = [];

    foreach (chan98MigrationFiles($migrationsPath) as $file) {
        $name = basename($file);
        $contents = (string) file_get_contents($file);
        $up = chan98MigrationBody($contents, 'up');
        $hasContract = preg_match('/@contract\s+CHAN-\d+/', $contents) === 1;
        $hasDestructive = preg_match('/@destructive\s+CHAN-\d+/', $contents) === 1;

        if (! $hasContract) {
            foreach ($destructivePatterns as $pattern => $label) {
                if (preg_match($pattern, $up) === 1) {
                    $violations[] = "{$name} : {$label} dans up() sans annotation @contract CHAN-xxx.";
                }
            }
        }

        if (! $hasContract && ! $hasDestructive) {
            foreach ($dataDestructivePatterns as $pattern => $label) {
                if (preg_match($pattern, $up) === 1) {
                    $violations[] = "{$name} : {$label} dans up() sans annotation @destructive CHAN-xxx.";
                }
            }
        }

        if (! $hasContract && preg_match('/DB::(?:statement|unprepared)\s*\(.*?\b(?:DROP|TRUNCATE|RENAME)\b/is', $up) === 1) {
            $violations[] = "{$name} : SQL destructif dans up() sans annotation @contract CHAN-xxx.";
        }

        if (! $hasContract && ! $hasDestructive && preg_match('/DB::(?:statement|unprepared)\s*\(.*?\bDELETE\b/is', $up) === 1) {
            $violations[] = "{$name} : suppression de lignes en SQL dans up() sans annotation @destructive CHAN-xxx.";
        }
    }

    expect($violations)->toBe([]);
});

test('les nouvelles migrations déclarent leur phase et leur ticket', function () use ($migrationsPath, $policyStartDate): void {
    $violations = [];

    foreach (chan98MigrationFiles($migrationsPath) as $file) {
        $name = basename($file);

        if (strcmp(substr($name, 0, 10), $policyStartDate) < 0) {
            continue;
        }

        $contents = (string) file_get_contents($file);

        if (preg_match('/@phase\s+(expand|migrate|contract)\b/', $contents) !== 1) {
            $violations[] = "{$name} : annotation @phase expand, migrate ou contract absente.";
        }

        if (preg_match('/@ticket\s+CHAN-\d+/', $contents) !== 1) {
            $violations[] = "{$name} : annotation @ticket CHAN-xxx absente.";
        }

        if (preg_match('/@phase\s+contract\b/', $contents) === 1
            && preg_match('/@contract\s+CHAN-\d+/', $contents) !== 1) {
            $violations[] = "{$name} : une phase contract exige une annotation @contract CHAN-xxx.";
        }
    }

    expect($violations)->toBe([]);
});

test('les migrations restent autonomes et ne lisent pas la configuration d environnement', function () use ($migrationsPath): void {
    $violations = [];

    foreach (chan98MigrationFiles($migrationsPath) as $file) {
        $name = basename($file);
        $contents = (string) file_get_contents($file);

        if (preg_match('/use\s+App\\\\|App\\\\Models\\\\|\b[A-Z][A-Za-z0-9_]*::query\s*\(/', $contents) === 1) {
            $violations[] = "{$name} : un modèle ou une classe applicative ne doit pas être utilisé dans une migration.";
        }

        if (preg_match('/(?<![\w>])env\s*\(/', $contents) === 1) {
            $violations[] = "{$name} : env() est interdit dans une migration.";
        }
    }

    expect($violations)->toBe([]);
});

test('aucun script de deploiement ou de packaging n execute de migration', function (): void {
    $root = dirname(__DIR__, 3);

    $directories = [
        $root.'/.github/scripts/deploy',
        $root.'/.github/scripts/package',
        $root.'/.github/scripts/lib',
    ];

    $patterns = [
        '/\bartisan\s+(?:migrate(?::[a-z]+)?|db:wipe)\b/i' => 'commande de migration',
        '/\bmigrate:(?:fresh|refresh|reset|rollback)\b/i' => 'commande de migration destructive',
        '/\bdb:wipe\b/i' => 'suppression de base',
        '/\bmigrate\s+--force\b/i' => 'migration forcée',
    ];

    $violations = [];

    foreach ($directories as $directory) {
        foreach (chan98ProjectFiles($directory, ['yml', 'yaml', 'sh', 'php']) as $file) {
            $contents = (string) file_get_contents($file);
            $contents = (string) preg_replace('/^\s*#.*$/m', '', $contents);

            foreach ($patterns as $pattern => $label) {
                if (preg_match($pattern, $contents) === 1) {
                    $violations[] = str_replace($root.'/', '', $file)." : {$label} détectée.";
                }
            }
        }
    }

    expect($violations)->toBe([]);
});

test('les workflows ne contiennent que les migrations autorisees du job mariadb', function (): void {
    $root = dirname(__DIR__, 3);
    $violations = [];

    foreach (glob($root.'/.github/workflows/*.yml') ?: [] as $file) {
        $workflow = Yaml::parseFile($file);

        if (! is_array($workflow)) {
            $violations[] = basename($file).' : YAML invalide.';

            continue;
        }

        $allowedJob = basename($file) === 'tests.yml' ? 'mariadb' : null;

        foreach (c2me_workflow_migration_violations($workflow, $allowedJob) as $violation) {
            $violations[] = basename($file).' / '.$violation['job'].' : '.$violation['line'];
        }
    }

    expect($violations)->toBe([]);
});

/**
 * @return array<string, mixed>
 */
function chan21MigrationWorkflow(string $job, string $command): array
{
    return [
        'jobs' => [
            $job => [
                'steps' => [
                    ['run' => $command],
                ],
            ],
        ],
    ];
}

test('refuse les migrations non autorisees dans les jobs', function (string $job, string $command, ?string $allowedJob): void {
    $violations = c2me_workflow_migration_violations(
        chan21MigrationWorkflow($job, $command),
        $allowedJob
    );

    expect($violations)->toHaveCount(1)
        ->and($violations[0]['job'])->toBe($job)
        ->and($violations[0]['line'])->toBe($command);
})->with([
    'db:wipe dans ci' => ['ci', 'php artisan db:wipe', 'mariadb'],
    'migrate:fresh dans package-linux' => ['package-linux', 'php artisan migrate:fresh --force', 'mariadb'],
    'migrate:refresh dans mariadb' => ['mariadb', 'php artisan migrate:refresh', 'mariadb'],
    'migrate:reset dans mariadb' => ['mariadb', 'php artisan migrate:reset', 'mariadb'],
    'migrate:rollback dans mariadb' => ['mariadb', 'php artisan migrate:rollback', 'mariadb'],
    'artisan migrate dans ci' => ['ci', 'php artisan migrate', 'mariadb'],
    'commande autorisee suivie d une commande interdite' => [
        'mariadb',
        'php artisan migrate:fresh --force --no-interaction && php artisan migrate:reset',
        'mariadb',
    ],
    'migration dans un autre workflow' => ['deploy', 'php artisan migrate --force', null],
]);

test('accepte uniquement les trois commandes autorisees dans le job mariadb', function (): void {
    $workflow = [
        'jobs' => [
            'mariadb' => [
                'steps' => [
                    ['run' => 'php artisan migrate:fresh --force --no-interaction'],
                    ['run' => 'php artisan migrate:status --no-ansi'],
                    ['run' => 'php scripts/ci/verify-mariadb-migrations.php'],
                ],
            ],
        ],
    ];

    expect(c2me_workflow_migration_violations($workflow, 'mariadb'))->toBe([]);
});

test('refuse les commandes autorisees hors du job mariadb', function (): void {
    $workflow = [
        'jobs' => [
            'ci' => [
                'steps' => [
                    ['run' => 'php artisan migrate:fresh --force --no-interaction'],
                    ['run' => 'php artisan migrate:status --no-ansi'],
                    ['run' => 'php scripts/ci/verify-mariadb-migrations.php'],
                ],
            ],
        ],
    ];

    expect(c2me_workflow_migration_violations($workflow, 'mariadb'))->toHaveCount(3);
});
