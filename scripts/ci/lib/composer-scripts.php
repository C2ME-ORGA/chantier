<?php

declare(strict_types=1);

/**
 * Résolution des commandes réellement exécutées par un script Composer.
 *
 * Les références `@script` sont suivies récursivement. Un script partagé par
 * plusieurs chemins n'est résolu qu'une fois et une référence circulaire ne
 * provoque pas de boucle infinie.
 */

/**
 * Retourne les commandes exécutées par un script Composer, dans l'ordre de
 * première découverte.
 *
 * @param  array<string, mixed>  $scripts
 * @return list<string>
 */
function c2me_composer_script_commands(array $scripts, string $script): array
{
    $commands = [];
    $visited = [];

    c2me_collect_composer_script_commands($scripts, $script, $commands, $visited);

    return $commands;
}

/**
 * Parcourt un script et accumule ses commandes.
 *
 * `$visited` est partagé entre tous les chemins : un script déjà résolu n'est
 * jamais parcouru une seconde fois, ce qui déduplique les chemins convergents
 * et interrompt les cycles.
 *
 * @param  array<string, mixed>  $scripts
 * @param  list<string>  $commands
 * @param  array<string, bool>  $visited
 */
function c2me_collect_composer_script_commands(
    array $scripts,
    string $script,
    array &$commands,
    array &$visited
): void {
    if (isset($visited[$script])) {
        return;
    }

    $visited[$script] = true;
    $entries = $scripts[$script] ?? [];

    if (is_string($entries)) {
        $entries = [$entries];
    }

    if (! is_array($entries)) {
        return;
    }

    foreach ($entries as $entry) {
        if (! is_string($entry) || trim($entry) === '') {
            continue;
        }

        $command = trim($entry);

        if ($command === '@php' || str_starts_with($command, '@php ')
            || $command === '@composer' || str_starts_with($command, '@composer ')) {
            $commands[] = $command;

            continue;
        }

        if (str_starts_with($command, '@')) {
            $reference = preg_replace('/\s+/', ' ', ltrim($command, '@')) ?? '';

            if (array_key_exists($reference, $scripts)) {
                c2me_collect_composer_script_commands($scripts, $reference, $commands, $visited);

                continue;
            }
        }

        $commands[] = $command;
    }
}
