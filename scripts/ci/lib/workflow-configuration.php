<?php

declare(strict_types=1);

/**
 * Lecture stricte de la configuration déclencheuse d'un workflow.
 *
 * Ces fonctions ne valident pas la sémantique GitHub Actions : elles exposent
 * la configuration sous une forme testable afin que le script de validation
 * puisse refuser explicitement une valeur non textuelle au lieu de l'ignorer.
 */

/**
 * Retourne les branches filtrées pour un événement de déclenchement.
 *
 * Retourne `null` lorsque la configuration est invalide : événement absent,
 * configuration non tabulaire, `branches` non textuel ou entrée de branche non
 * textuelle. Une liste vide n'est pas considérée comme invalide : elle ne
 * satisfait simplement pas la comparaison attendue par l'appelant.
 *
 * @param  array<string, mixed>  $trigger
 * @return list<string>|null
 */
function c2me_workflow_trigger_branches(array $trigger, string $event): ?array
{
    if (! array_key_exists($event, $trigger)) {
        return null;
    }

    $configuration = $trigger[$event];

    if ($configuration === null) {
        return [];
    }

    if (! is_array($configuration)) {
        return null;
    }

    $branches = $configuration['branches'] ?? [];

    if (is_string($branches)) {
        return [$branches];
    }

    if (! is_array($branches)) {
        return null;
    }

    $normalized = [];

    foreach ($branches as $branch) {
        if (! is_string($branch)) {
            return null;
        }

        $normalized[] = $branch;
    }

    return $normalized;
}

/**
 * Retourne les noms d'événements configurés, triés.
 *
 * Accepte la forme mapping (`push:`, `pull_request:`) et la forme liste
 * (`[push, pull_request]`). Retourne `null` si un nom d'événement n'est pas
 * textuel.
 *
 * @param  array<string, mixed>  $trigger
 * @return list<string>|null
 */
function c2me_workflow_event_names(array $trigger): ?array
{
    $events = array_is_list($trigger) ? array_values($trigger) : array_keys($trigger);
    $names = [];

    foreach ($events as $event) {
        if (! is_string($event) || $event === '') {
            return null;
        }

        $names[] = $event;
    }

    sort($names);

    return $names;
}
