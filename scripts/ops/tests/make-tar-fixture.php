<?php

declare(strict_types=1);

/**
 * Générateur de fixtures TAR pour les tests de sécurité CHAN-98 (lot 2).
 *
 * Ce fichier produit volontairement des archives malveillantes ou invalides
 * afin de vérifier que scripts/ops/lib/tar-inspect.php les refuse. Il n'est
 * jamais exécuté par les scripts d'exploitation.
 *
 *   php make-tar-fixture.php <sortie.tar> <type>
 *
 * Types : valid, valid-multi, symlink, hardlink, fifo, chardev, blockdev,
 *         traversal, absolute, outside, dotdot, corrupt-checksum, truncated,
 *         special-type.
 */
const BLOCK = 512;

/**
 * @param  array<string, mixed>  $options
 */
function write_header(string $name, string $type, int $size = 0, string $linkname = '', string $mode = '0000644', bool $corrupt = false): string
{
    $header = str_pad($name, 100, "\0");
    $header .= str_pad($mode, 8, "\0");
    $header .= str_pad('0000000', 8, "\0");
    $header .= str_pad('0000000', 8, "\0");
    $header .= str_pad(decoct($size), 12, '0', STR_PAD_LEFT);
    $header .= str_pad(decoct(time()), 12, '0', STR_PAD_LEFT);
    $header .= '        ';
    $header .= $type;
    $header .= str_pad($linkname, 100, "\0");
    $header .= "ustar\0".'00';
    $header .= str_pad('root', 32, "\0");
    $header .= str_pad('root', 32, "\0");
    $header .= str_pad('0000000', 8, "\0");
    $header .= str_pad('0000000', 8, "\0");
    $header .= str_pad('', 155, "\0");
    $header .= str_pad('', 12, "\0");

    if (strlen($header) !== BLOCK) {
        throw new RuntimeException('En-tête TAR de longueur invalide.');
    }

    if ($corrupt) {
        return substr_replace($header, '0000000', 148, 7).' ';
    }

    $checksum = 0;

    for ($index = 0; $index < BLOCK; $index++) {
        $checksum += ord($header[$index]);
    }

    return substr_replace($header, sprintf('%06o', $checksum)."\0 ", 148, 8);
}

function write_data(string $data): string
{
    $padded = (int) (ceil(strlen($data) / BLOCK) * BLOCK);

    return str_pad($data, $padded, "\0");
}

function end_of_archive(): string
{
    return str_repeat("\0", BLOCK * 2);
}

function pax_record(string $key, string $value): string
{
    $body = ' '.$key.'='.$value."\n";
    $length = strlen($body) + 1;

    while (true) {
        $record = $length.$body;

        if (strlen($record) === $length) {
            return $record;
        }

        $length = strlen($record);
    }
}

function meta_entry(string $type, string $data): string
{
    return write_header('././@Metadata', $type, strlen($data)).write_data($data);
}

$output = $argv[1] ?? '';
$type = $argv[2] ?? '';

if ($output === '' || $type === '') {
    fwrite(STDERR, "Usage : php make-tar-fixture.php <sortie.tar> <type>\n");
    exit(2);
}

$content = "contenu de test\n";

$archive = match ($type) {
    'valid' => write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'valid-multi' => write_header('app/private/', '5', 0, mode: '0000755')
        .write_header('app/private/a.txt', '0', strlen($content))
        .write_data($content)
        .write_header('app/public/', '5', 0, mode: '0000755')
        .write_header('app/public/b.txt', '0', 4)
        .write_data('abcd')
        .end_of_archive(),

    'symlink' => write_header('app/private/lien', '2', 0, '/etc')
        .end_of_archive(),

    'hardlink' => write_header('app/private/dur', '1', 0, 'app/private/fichier.txt')
        .end_of_archive(),

    'fifo' => write_header('app/private/tube', '6')
        .end_of_archive(),

    'chardev' => write_header('app/private/peripherique', '3')
        .end_of_archive(),

    'blockdev' => write_header('app/private/bloc', '4')
        .end_of_archive(),

    'traversal' => write_header('../evil.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'absolute' => write_header('/etc/passwd', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'outside' => write_header('other/evil.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'dotdot' => write_header('app/private/../../evil.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'corrupt-checksum' => write_header('app/private/fichier.txt', '0', strlen($content), corrupt: true)
        .write_data($content)
        .end_of_archive(),

    'truncated' => write_header('app/private/fichier.txt', '0', 64),

    'special-type' => write_header('app/private/fichier.txt', 'S', 0)
        .end_of_archive(),

    'pax-global' => meta_entry('g', pax_record('path', 'app/private/global.txt'))
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'pax-size' => meta_entry('x', pax_record('size', '999999'))
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'pax-sparse' => meta_entry('x', pax_record('GNU.sparse.offset', '0').pax_record('GNU.sparse.numbytes', '16'))
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'pax-xattr' => meta_entry('x', pax_record('SCHILY.xattr.user.test', 'valeur'))
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'pax-malformed' => meta_entry('x', '999 path=app/private/fichier.txt'."\n")
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'pax-empty' => meta_entry('x', '')
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'pax-contradictory' => meta_entry('L', 'app/private/premier.txt'."\0")
        .meta_entry('x', pax_record('path', 'app/private/second.txt'))
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'pax-valid' => meta_entry('x', pax_record('path', 'app/private/pax.txt'))
        .write_header('app/private/original.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'gnu-longname-malformed' => meta_entry('L', 'app/private/a.txt'."\0".'app/private/b.txt'."\0")
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'gnu-longlink-malformed' => meta_entry('K', 'cible'."\0")
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    'gnu-longname-valid' => meta_entry('L', 'app/private/'.str_repeat('a', 120).'.txt'."\0")
        .write_header('app/private/fichier.txt', '0', strlen($content))
        .write_data($content)
        .end_of_archive(),

    default => null,
};

if ($archive === null) {
    fwrite(STDERR, "Type de fixture inconnu : {$type}\n");
    exit(2);
}

if (file_put_contents($output, $archive) === false) {
    fwrite(STDERR, "Écriture impossible : {$output}\n");
    exit(1);
}

echo $output.PHP_EOL;
