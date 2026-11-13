<?php

declare(strict_types=1);

/**
 * Inspecteur d'archive TAR pour la restauration CHAN-98 (lot 2).
 *
 * Analyse les en-têtes TAR (format ustar/GNU) sans extraire l'archive et
 * refuse toute entrée qui n'est pas un fichier régulier ou un répertoire
 * situé sous app/private ou app/public : liens symboliques, liens physiques,
 * FIFO, sockets, périphériques, chemins absolus, traversées `..` et entrées
 * hors périmètre.
 *
 *   php scripts/ops/lib/tar-inspect.php /chemin/vers/archive.tar
 *
 * Sortie en cas de succès :
 *   OK files=<n> dirs=<n> bytes=<n> entries=<n>
 *
 * Sortie en cas d'échec : lignes `ERREUR: ...` sur STDERR, code 1.
 */
const TAR_BLOCK_SIZE = 512;
const TAR_MAX_ENTRIES = 1_000_000;
const TAR_MAX_ENTRY_BYTES = 109_951_162_777_600; // 100 Tio
const TAR_MAX_TOTAL_BYTES = 1_099_511_627_776_000; // 1 Pio
const TAR_METADATA_TYPES = ['L', 'K', 'x', 'g'];

/**
 * @return array{files:int,dirs:int,bytes:int,entries:int}
 *
 * @throws RuntimeException
 */
function tar_inspect(string $path): array
{
    if (! is_file($path)) {
        throw new RuntimeException("archive introuvable : {$path}");
    }

    $size = filesize($path);

    if ($size === false || $size < TAR_BLOCK_SIZE) {
        throw new RuntimeException('archive vide ou trop petite pour contenir un en-tête TAR.');
    }

    $handle = fopen($path, 'rb');

    if ($handle === false) {
        throw new RuntimeException("archive illisible : {$path}");
    }

    $files = 0;
    $dirs = 0;
    $bytes = 0;
    $entries = 0;
    $longName = null;
    $longLink = null;
    $paxPath = null;
    $paxLink = null;
    $position = 0;
    $sawEnd = false;

    try {
        while (true) {
            if ($position + TAR_BLOCK_SIZE > $size) {
                if ($position === $size) {
                    throw new RuntimeException('archive tronquée : aucun bloc de fin.');
                }

                throw new RuntimeException('en-tête TAR tronqué.');
            }

            fseek($handle, $position);
            $header = fread($handle, TAR_BLOCK_SIZE);

            if ($header === false || strlen($header) !== TAR_BLOCK_SIZE) {
                throw new RuntimeException('lecture d en-tête TAR impossible.');
            }

            $position += TAR_BLOCK_SIZE;

            if (trim($header, "\0") === '') {
                $sawEnd = true;
                $remainder = $size - $position;

                if ($remainder > 0) {
                    fseek($handle, $position);
                    $tail = fread($handle, (int) min($remainder, TAR_BLOCK_SIZE * 1024));

                    if ($tail === false || trim($tail, "\0") !== '') {
                        throw new RuntimeException('données non nulles après le bloc de fin TAR.');
                    }
                }

                break;
            }

            tar_verify_checksum($header);
            $type = tar_type($header);
            $name = tar_name($header);
            $linkname = tar_linkname($header);
            $declaredSize = tar_size($header);

            if ($declaredSize < 0 || $declaredSize > TAR_MAX_ENTRY_BYTES) {
                throw new RuntimeException("taille d entrée TAR invalide ({$declaredSize}) pour {$name}.");
            }

            $padded = (int) (ceil($declaredSize / TAR_BLOCK_SIZE) * TAR_BLOCK_SIZE);
            $dataPosition = $position;

            if ($dataPosition + $padded > $size) {
                throw new RuntimeException("données tronquées pour l entrée {$name}.");
            }

            if (in_array($type, TAR_METADATA_TYPES, true)) {
                fseek($handle, $dataPosition);
                $data = $declaredSize > 0 ? fread($handle, $declaredSize) : '';
                $data = $data === false ? '' : $data;

                if ($type === 'L') {
                    $longName = rtrim($data, "\0\n");
                } elseif ($type === 'K') {
                    $longLink = rtrim($data, "\0\n");
                } elseif ($type === 'x') {
                    $pax = tar_parse_pax($data);

                    if (isset($pax['path'])) {
                        $paxPath = $pax['path'];
                    }

                    if (isset($pax['linkpath'])) {
                        $paxLink = $pax['linkpath'];
                    }
                }

                $position = $dataPosition + $padded;

                continue;
            }

            $entries++;

            if ($entries > TAR_MAX_ENTRIES) {
                throw new RuntimeException('nombre d entrées TAR excessif.');
            }

            $effectiveName = $paxPath ?? $longName ?? $name;
            $effectiveLink = $paxLink ?? $longLink ?? $linkname;

            $longName = null;
            $longLink = null;
            $paxPath = null;
            $paxLink = null;

            if (! in_array($type, ['0', "\0", '5'], true)) {
                throw new RuntimeException(sprintf(
                    'type d entrée TAR interdit (%s) pour %s : seuls les fichiers réguliers et répertoires sont autorisés.',
                    tar_type_label($type),
                    tar_printable($effectiveName)
                ));
            }

            tar_assert_safe_name($effectiveName, $type === '5');

            if ($type === '5') {
                $dirs++;
            } else {
                $files++;
                $bytes += $declaredSize;

                if ($bytes > TAR_MAX_TOTAL_BYTES) {
                    throw new RuntimeException('taille totale de l archive excessive.');
                }
            }

            if ($effectiveLink !== '') {
                throw new RuntimeException(
                    'lien ou cible de lien inattendu pour '.tar_printable($effectiveName).' : refusé.'
                );
            }

            $position = $dataPosition + $padded;
        }
    } finally {
        fclose($handle);
    }

    if (! $sawEnd) {
        throw new RuntimeException('archive sans bloc de fin.');
    }

    if ($entries === 0 && $files === 0 && $dirs === 0) {
        return ['files' => 0, 'dirs' => 0, 'bytes' => 0, 'entries' => 0];
    }

    return ['files' => $files, 'dirs' => $dirs, 'bytes' => $bytes, 'entries' => $entries];
}

function tar_printable(string $value): string
{
    $clean = preg_replace('/[^\x20-\x7E]/', '?', $value);

    return $clean === null || $clean === '' ? '<vide>' : $clean;
}

function tar_type(string $header): string
{
    return $header[156] ?? "\0";
}

function tar_type_label(string $type): string
{
    return match ($type) {
        '1' => 'lien physique',
        '2' => 'lien symbolique',
        '3' => 'périphérique caractère',
        '4' => 'périphérique bloc',
        '6' => 'FIFO',
        '7' => 'fichier contigu',
        'S' => 'fichier sparse',
        default => 'type '.tar_printable($type),
    };
}

function tar_name(string $header): string
{
    $name = rtrim(substr($header, 0, 100), "\0");
    $prefix = rtrim(substr($header, 345, 155), "\0");

    if ($prefix !== '') {
        $name = $prefix.'/'.$name;
    }

    return $name;
}

function tar_linkname(string $header): string
{
    return rtrim(substr($header, 157, 100), "\0");
}

function tar_size(string $header): int
{
    return tar_parse_numeric(substr($header, 124, 12));
}

function tar_parse_numeric(string $field): int
{
    if ($field === '') {
        return 0;
    }

    $first = ord($field[0]);

    if (($first & 0x80) !== 0) {
        $value = $first & 0x7F;
        $length = strlen($field);

        for ($index = 1; $index < $length; $index++) {
            $value = ($value * 256) + ord($field[$index]);

            if ($value > PHP_INT_MAX / 256) {
                throw new RuntimeException('valeur numérique TAR hors limites.');
            }
        }

        return $value;
    }

    $trimmed = trim($field, "\0 ");

    if ($trimmed === '') {
        return 0;
    }

    if (preg_match('/^[0-7]+$/', $trimmed) !== 1) {
        throw new RuntimeException('champ numérique TAR invalide.');
    }

    return (int) octdec($trimmed);
}

function tar_verify_checksum(string $header): void
{
    $recorded = tar_parse_numeric(substr($header, 148, 8));
    $normalized = substr($header, 0, 148).'        '.substr($header, 156);

    $unsigned = 0;
    $signed = 0;
    $length = strlen($normalized);

    for ($index = 0; $index < $length; $index++) {
        $byte = ord($normalized[$index]);
        $unsigned += $byte;
        $signed += $byte > 127 ? $byte - 256 : $byte;
    }

    if ($recorded !== $unsigned && $recorded !== $signed) {
        throw new RuntimeException('checksum d en-tête TAR invalide : archive corrompue.');
    }
}

/**
 * @return array<string, string>
 */
function tar_parse_pax(string $data): array
{
    $records = [];
    $offset = 0;
    $length = strlen($data);

    while ($offset < $length) {
        $space = strpos($data, ' ', $offset);

        if ($space === false) {
            break;
        }

        $recordLength = (int) substr($data, $offset, $space - $offset);

        if ($recordLength <= 0 || $offset + $recordLength > $length) {
            throw new RuntimeException('en-tête PAX invalide.');
        }

        $record = substr($data, $space + 1, $recordLength - ($space - $offset) - 2);
        $separator = strpos($record, '=');

        if ($separator !== false) {
            $key = substr($record, 0, $separator);
            $records[$key] = substr($record, $separator + 1);
        }

        $offset += $recordLength;
    }

    return $records;
}

function tar_assert_safe_name(string $name, bool $isDirectory): void
{
    if ($name === '') {
        throw new RuntimeException('nom d entrée TAR vide.');
    }

    if (str_contains($name, "\0")) {
        throw new RuntimeException('nom d entrée TAR contenant un octet nul.');
    }

    if (str_contains($name, '\\')) {
        throw new RuntimeException('nom d entrée TAR contenant une barre oblique inverse : '.tar_printable($name));
    }

    if (str_starts_with($name, '/') || preg_match('#^[A-Za-z]:#', $name) === 1) {
        throw new RuntimeException('chemin absolu interdit dans l archive : '.tar_printable($name));
    }

    $candidate = $name;

    if ($isDirectory) {
        $candidate = rtrim($candidate, '/');

        if ($candidate === '') {
            throw new RuntimeException('répertoire racine interdit dans l archive.');
        }
    } elseif (str_ends_with($candidate, '/')) {
        throw new RuntimeException('fichier régulier avec un nom de répertoire : '.tar_printable($name));
    }

    foreach (explode('/', $candidate) as $segment) {
        if ($segment === '' || $segment === '.' || $segment === '..') {
            throw new RuntimeException('traversée ou composant de chemin invalide dans l archive : '.tar_printable($name));
        }
    }

    if (preg_match('#^app/(private|public)(/|$)#', $candidate) !== 1) {
        throw new RuntimeException('entrée hors du périmètre app/private ou app/public : '.tar_printable($name));
    }
}

if (PHP_SAPI === 'cli' && isset($_SERVER['argv'][0]) && realpath((string) $_SERVER['argv'][0]) === __FILE__) {
    $archive = $_SERVER['argv'][1] ?? '';

    if ($archive === '') {
        fwrite(STDERR, "Usage : php tar-inspect.php <archive.tar>\n");
        exit(2);
    }

    try {
        $result = tar_inspect($archive);
    } catch (RuntimeException $exception) {
        fwrite(STDERR, 'ERREUR: '.$exception->getMessage().PHP_EOL);
        exit(1);
    }

    printf(
        "OK files=%d dirs=%d bytes=%d entries=%d\n",
        $result['files'],
        $result['dirs'],
        $result['bytes'],
        $result['entries']
    );
    exit(0);
}
