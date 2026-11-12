<?php

declare(strict_types=1);

/**
 * Génère une archive tar.gz de test avec des entrées contrôlées.
 *
 * Usage :
 *   php create-archive-fixture.php <sortie.tar.gz> <spec>...
 *
 * Spécifications :
 *   file:<nom>                 fichier vide
 *   symlink:<nom>:<cible>      lien symbolique
 *   hardlink:<nom>:<cible>     lien physique
 *
 * Ce script est réservé aux tests de sécurité de l'extraction.
 */

function archive_header(string $name, string $type, string $link = ''): string
{
    $header = str_pad($name, 100, "\0")
        .sprintf('%07o', 0644)."\0"
        .sprintf('%07o', 0)."\0"
        .sprintf('%07o', 0)."\0"
        .sprintf('%011o', 0)."\0"
        .sprintf('%011o', time())."\0"
        .str_repeat(' ', 8)
        .$type
        .str_pad($link, 100, "\0")
        .'ustar'."\0".'00'
        .str_repeat("\0", 32)
        .str_repeat("\0", 32)
        .str_repeat("\0", 8)
        .str_repeat("\0", 8)
        .str_repeat("\0", 155)
        .str_repeat("\0", 12);

    if (strlen($header) !== 512) {
        throw new RuntimeException('En-tête tar invalide.');
    }

    $checksum = array_sum(unpack('C*', $header));

    return substr_replace($header, sprintf('%06o', $checksum)."\0 ", 148, 8);
}

$output = $argv[1] ?? '';
$specs = array_slice($argv, 2);

if ($output === '' || $specs === []) {
    fwrite(STDERR, "Usage : create-archive-fixture.php <sortie.tar.gz> <spec>...\n");
    exit(64);
}

$archive = '';

foreach ($specs as $spec) {
    $parts = explode(':', $spec, 3);
    $type = $parts[0] ?? '';
    $name = $parts[1] ?? '';

    if ($name === '') {
        fwrite(STDERR, "Spécification invalide : {$spec}\n");
        exit(64);
    }

    switch ($type) {
        case 'file':
            $archive .= archive_header($name, '0');
            break;
        case 'symlink':
            $archive .= archive_header($name, '2', $parts[2] ?? '');
            break;
        case 'hardlink':
            $archive .= archive_header($name, '1', $parts[2] ?? '');
            break;
        default:
            fwrite(STDERR, "Type d'entrée inconnu : {$type}\n");
            exit(64);
    }
}

$archive .= str_repeat("\0", 1024);

if (file_put_contents($output, gzencode($archive)) === false) {
    fwrite(STDERR, "Écriture impossible : {$output}\n");
    exit(1);
}
