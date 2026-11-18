<?php

declare(strict_types=1);

/**
 * Adaptateur de simulation pour les règles de migration CHAN-98 / CHAN-99.
 *
 * Ce script n'est PAS le contrôle de production : les tests Pest réels
 * (tests/Unit/Migrations/MigrationPolicyTest.php) restent la référence pour le
 * dépôt. Il rejoue ici, sur des migrations fictives, les deux règles exigées
 * par le Lot 6 :
 *
 * - une opération destructrice dans up() exige @contract CHAN-xxx ou
 *
 *   @destructive CHAN-xxx ;
 * - l'ajout d'une colonne NOT NULL sans valeur par défaut sur une table
 *   existante rompt la compatibilité N/N-1 et est refusé.
 *
 * Usage : php migration-gate.php --dir <dossier> [--json]
 * Sortie : code 0 si GO, 1 si NO-GO.
 */
$arguments = $argv;
array_shift($arguments);
$directory = null;
$json = false;

while ($arguments !== []) {
    $argument = array_shift($arguments);

    if ($argument === '--dir') {
        $directory = array_shift($arguments);
    } elseif ($argument === '--json') {
        $json = true;
    } else {
        fwrite(STDERR, "Argument inconnu : {$argument}\n");
        exit(64);
    }
}

if (! is_string($directory) || ! is_dir($directory)) {
    fwrite(STDERR, "Usage : php migration-gate.php --dir <dossier> [--json]\n");
    exit(64);
}

$files = glob(rtrim($directory, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.'*.php') ?: [];
sort($files);

$violations = [];
$checked = [];

$destructivePatterns = [
    '/->dropColumn\s*\(/' => 'dropColumn',
    '/->dropIfExists\s*\(/' => 'dropIfExists',
    '/Schema::dropIfExists\s*\(/' => 'Schema::dropIfExists',
    '/Schema::drop\s*\(/' => 'Schema::drop',
    '/Schema::rename\s*\(/' => 'Schema::rename',
    '/->renameColumn\s*\(/' => 'renameColumn',
    '/->truncate\s*\(/' => 'truncate',
    '/->delete\s*\(/' => 'delete',
    '/DB::(?:statement|unprepared)\s*\([^;]*(?:DROP|TRUNCATE|RENAME)/is' => 'SQL destructif',
];

$columnTypes = 'string|char|text|mediumText|longText|integer|bigInteger|unsignedInteger|unsignedBigInteger|boolean|date|dateTime|timestamp|time|decimal|float|double|json|uuid|ulid';

foreach ($files as $file) {
    $name = basename($file);
    $code = (string) file_get_contents($file);
    $checked[] = $name;

    $upStart = strpos($code, 'function up');

    if ($upStart === false) {
        $violations[] = "{$name} : méthode up() absente.";

        continue;
    }

    $downStart = strpos($code, 'function down', $upStart);
    $up = $downStart === false
        ? substr($code, $upStart)
        : substr($code, $upStart, $downStart - $upStart);

    $protected = preg_match('/@(?:contract|destructive)\s+CHAN-\d+/', $code) === 1;

    if (! $protected) {
        foreach ($destructivePatterns as $pattern => $label) {
            if (preg_match($pattern, $up) === 1) {
                $violations[] = "{$name} : opération destructrice {$label} dans up() sans annotation @contract ou @destructive CHAN-xxx.";
            }
        }
    }

    if (preg_match_all('/Schema::table\s*\([^;]*?\{(.*?)\n\s*\}\);/s', $up, $blocks) !== false) {
        foreach ($blocks[1] as $block) {
            if (preg_match_all('/\$table\s*->[^;]+;/s', $block, $statements) === false) {
                continue;
            }

            foreach ($statements[0] as $statement) {
                if (preg_match('/\$table\s*->('.$columnTypes.')\s*\(/', $statement) !== 1) {
                    continue;
                }

                if (preg_match('/->nullable\s*\(|->default\s*\(/', $statement) === 1) {
                    continue;
                }

                $compact = preg_replace('/\s+/', ' ', trim($statement));
                $violations[] = "{$name} : colonne NOT NULL sans valeur par défaut sur une table existante (incompatible N/N-1) : {$compact}";
            }
        }
    }
}

$verdict = $violations === [] ? 'GO' : 'NO-GO';

if ($json) {
    echo json_encode([
        'verdict' => $verdict,
        'checked' => $checked,
        'violations' => $violations,
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), "\n";
} else {
    echo "MIGRATION_GATE={$verdict}\n";

    foreach ($checked as $name) {
        echo "CHECKED={$name}\n";
    }

    foreach ($violations as $violation) {
        echo "VIOLATION={$violation}\n";
    }
}

exit($verdict === 'GO' ? 0 : 1);
