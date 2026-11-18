<?php

declare(strict_types=1);

/**
 * Vérification documentaire de la simulation CHAN-99 (Lot 6).
 *
 * - contrôle que les liens Markdown relatifs pointent vers un fichier existant ;
 * - contrôle l'équilibre des blocs de code clôturés ;
 * - vérifie la syntaxe des blocs Bash avec `bash -n` ;
 * - émet les blocs PowerShell pour validation par check-docs.ps1.
 *
 * Usage :
 *   php docs-check.php --root <racine> --emit <dossier> <fichier.md> [...]
 *
 * Sortie : JSON sur stdout, code 1 en cas d'erreur.
 */
$arguments = $argv;
array_shift($arguments);
$root = null;
$emit = null;
$files = [];

while ($arguments !== []) {
    $argument = array_shift($arguments);

    if ($argument === '--root') {
        $root = array_shift($arguments);
    } elseif ($argument === '--emit') {
        $emit = array_shift($arguments);
    } else {
        $files[] = $argument;
    }
}

if (! is_string($root) || ! is_dir($root) || ! is_string($emit) || $files === []) {
    fwrite(STDERR, "Usage : php docs-check.php --root <racine> --emit <dossier> <fichier.md> [...]\n");
    exit(64);
}

@mkdir($emit, 0775, true);

$errors = [];
$stats = [
    'files' => 0,
    'links' => 0,
    'bash_blocks' => 0,
    'powershell_blocks' => 0,
];
$powershellFiles = [];

function strip_bom(string $contents): string
{
    return str_starts_with($contents, "\xEF\xBB\xBF") ? substr($contents, 3) : $contents;
}

function resolve_link(string $sourceFile, string $target): ?string
{
    $target = trim($target);

    if ($target === '' || str_starts_with($target, '#')
        || preg_match('#^(https?:|mailto:|tel:|ftp:)#i', $target) === 1) {
        return null;
    }

    $target = preg_replace('/\s+"[^"]*"$/', '', $target) ?? $target;
    $target = preg_replace('/#.*$/', '', $target) ?? $target;
    $target = rawurldecode($target);

    if ($target === '') {
        return null;
    }

    if (str_starts_with($target, '/')) {
        return null;
    }

    return dirname($sourceFile).DIRECTORY_SEPARATOR.$target;
}

foreach ($files as $relativeFile) {
    $file = str_starts_with($relativeFile, DIRECTORY_SEPARATOR)
        ? $relativeFile
        : rtrim($root, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.$relativeFile;

    if (! is_file($file)) {
        $errors[] = "Fichier documentaire introuvable : {$relativeFile}";

        continue;
    }

    $stats['files']++;
    $lines = preg_split('/\R/', strip_bom((string) file_get_contents($file))) ?: [];
    $inFence = false;
    $fenceLanguage = '';
    $fenceStart = 0;
    $fence = [];
    $outside = [];
    $linkScan = [];
    $fenceIndex = 0;

    foreach ($lines as $index => $line) {
        $lineNumber = $index + 1;

        if (preg_match('/^```([A-Za-z0-9_+.-]*)\s*$/', $line, $matches) === 1) {
            if (! $inFence) {
                $inFence = true;
                $fenceLanguage = strtolower($matches[1]);
                $fenceStart = $lineNumber;
                $fence = [];
            } else {
                $inFence = false;

                if ($fenceLanguage === 'bash' || $fenceLanguage === 'sh' || $fenceLanguage === 'shell') {
                    $stats['bash_blocks']++;
                    $descriptors = [
                        0 => ['pipe', 'r'],
                        1 => ['pipe', 'w'],
                        2 => ['pipe', 'w'],
                    ];
                    $process = proc_open('bash -n', $descriptors, $pipes);

                    if (! is_resource($process)) {
                        $errors[] = "{$relativeFile}:{$fenceStart} : impossible de lancer bash -n.";
                    } else {
                        fwrite($pipes[0], implode("\n", $fence)."\n");
                        fclose($pipes[0]);
                        $stdout = stream_get_contents($pipes[1]);
                        fclose($pipes[1]);
                        $stderr = stream_get_contents($pipes[2]);
                        fclose($pipes[2]);
                        $status = proc_close($process);

                        if ($status !== 0) {
                            $errors[] = "{$relativeFile}:{$fenceStart} : bloc Bash invalide : ".trim($stderr.' '.$stdout);
                        }
                    }
                } elseif ($fenceLanguage === 'powershell' || $fenceLanguage === 'pwsh') {
                    $stats['powershell_blocks']++;
                    $fenceIndex++;
                    $target = rtrim($emit, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR
                        .basename($relativeFile, '.md').'-'.$fenceIndex.'-line-'.$fenceStart.'.ps1';
                    // BOM UTF-8 : Windows PowerShell 5.1 lit sinon les tirets
                    // typographiques comme des guillemets et casse le bloc.
                    file_put_contents($target, "\xEF\xBB\xBF".implode("\n", $fence)."\n");
                    $powershellFiles[] = $target;
                }
            }

            continue;
        }

        if ($inFence) {
            $fence[] = $line;
        } else {
            $outside[] = $line;
            $linkScan[] = [$lineNumber, $line];
        }
    }

    if ($inFence) {
        $errors[] = "{$relativeFile}:{$fenceStart} : bloc de code non clôturé.";
    }

    foreach ($linkScan as [$lineNumber, $line]) {
        if (preg_match_all('/\[[^\]]*\]\(([^)]+)\)/', $line, $matches) === false) {
            continue;
        }

        foreach ($matches[1] as $target) {
            $stats['links']++;
            $resolved = resolve_link($file, $target);

            if ($resolved === null) {
                continue;
            }

            if (! is_file($resolved) && ! is_dir($resolved)) {
                $errors[] = "{$relativeFile}:{$lineNumber} : lien relatif cassé : {$target}";
            }
        }
    }
}

$result = [
    'verdict' => $errors === [] ? 'PASS' : 'FAIL',
    'stats' => $stats,
    'powershell_files' => $powershellFiles,
    'errors' => $errors,
];

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), "\n";

exit($errors === [] ? 0 : 1);
