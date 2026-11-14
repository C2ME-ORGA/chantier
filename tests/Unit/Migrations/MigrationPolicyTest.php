<?php

use Illuminate\Database\Migrations\Migration;

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

test('aucun workflow de deploiement ni script de deploiement n execute de migration', function (): void {
    $root = dirname(__DIR__, 3);

    $directories = [
        $root.'/.github/workflows',
        $root.'/.github/scripts/deploy',
        $root.'/.github/scripts/package',
        $root.'/.github/scripts/lib',
    ];

    $patterns = [
        '/\bartisan\s+migrate\b/i' => 'commande artisan migrate',
        '/\bmigrate\s+--force\b/i' => 'migration forcée',
        '/\bmigrate:(?:fresh|refresh|reset|rollback)\b/i' => 'réinitialisation ou rollback de base',
        '/\bdb:wipe\b/i' => 'suppression de base',
    ];

    $violations = [];

    foreach ($directories as $directory) {
        foreach (chan98ProjectFiles($directory, ['yml', 'yaml', 'sh', 'php']) as $file) {
            $contents = (string) file_get_contents($file);

            if (basename($file) === 'tests.yml') {
                // CHAN-21 lot 2 autorise ces commandes dans le seul job
                // MariaDB éphémère. Les autres workflows et scripts restent
                // soumis à l'interdiction, y compris le job SQLite.
                $contents = (string) preg_replace(
                    '/^.*(?:php artisan migrate:fresh --force --no-interaction|php artisan migrate:status --no-ansi|php scripts\/ci\/verify-mariadb-migrations\.php).*$/m',
                    '',
                    $contents
                );
            }

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
