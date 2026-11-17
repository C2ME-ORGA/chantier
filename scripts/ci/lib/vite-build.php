<?php

declare(strict_types=1);

/**
 * Contrôles du manifest Vite et des fichiers qu'il référence.
 *
 * Ces fonctions sont utilisées par scripts/ci/verify-vite-build.php et
 * couvertes par tests/Unit/CI/ViteBuildVerificationTest.php.
 */

/**
 * Retourne la liste des erreurs détectées dans le manifest Vite.
 *
 * Une liste vide signifie que le manifest est valide, que les entrées
 * obligatoires existent et que tous les fichiers référencés sont présents
 * dans le répertoire de build.
 *
 * @param  list<string>  $requiredEntries
 * @return list<string>
 */
function c2me_vite_manifest_errors(string $manifestPath, string $buildDirectory, array $requiredEntries = []): array
{
    if (! is_file($manifestPath)) {
        return ["Manifest Vite absent : {$manifestPath}."];
    }

    $contents = file_get_contents($manifestPath);

    if ($contents === false || trim($contents) === '') {
        return ["Manifest Vite illisible ou vide : {$manifestPath}."];
    }

    try {
        $manifest = json_decode($contents, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        return ["Manifest Vite JSON invalide : {$exception->getMessage()}."];
    }

    if (! is_array($manifest) || $manifest === [] || array_is_list($manifest)) {
        return ['Le manifest Vite doit être un objet JSON non vide.'];
    }

    $errors = [];
    $realBuildDirectory = realpath($buildDirectory);

    if ($realBuildDirectory === false || ! is_dir($realBuildDirectory)) {
        return ["Répertoire de build Vite absent : {$buildDirectory}."];
    }

    foreach ($requiredEntries as $entry) {
        if (! array_key_exists($entry, $manifest)) {
            $errors[] = "Entrée Vite obligatoire absente du manifest : {$entry}.";

            continue;
        }

        $definition = $manifest[$entry];

        if (! is_array($definition)) {
            $errors[] = "Entrée Vite invalide dans le manifest : {$entry}.";

            continue;
        }

        if (($definition['isEntry'] ?? false) !== true) {
            $errors[] = "L'entrée Vite {$entry} doit être déclarée comme entrée.";
        }

        if (! is_string($definition['file'] ?? null) || $definition['file'] === '') {
            $errors[] = "L'entrée Vite {$entry} doit référencer un fichier.";
        }
    }

    $checkedReferences = [];

    foreach ($manifest as $entry => $definition) {
        if (! is_array($definition)) {
            $errors[] = "Définition Vite invalide pour l'entrée {$entry}.";

            continue;
        }

        $references = [];

        if (array_key_exists('file', $definition)) {
            if (! is_string($definition['file']) || $definition['file'] === '') {
                $errors[] = "Fichier Vite invalide pour l'entrée {$entry}.";
            } else {
                $references[] = $definition['file'];
            }
        }

        foreach (['css', 'assets'] as $referenceKey) {
            if (! array_key_exists($referenceKey, $definition)) {
                continue;
            }

            if (! is_array($definition[$referenceKey])) {
                $errors[] = "Liste « {$referenceKey} » invalide pour l'entrée {$entry}.";

                continue;
            }

            foreach ($definition[$referenceKey] as $reference) {
                if (! is_string($reference) || $reference === '') {
                    $errors[] = "Référence « {$referenceKey} » invalide pour l'entrée {$entry}.";

                    continue;
                }

                $references[] = $reference;
            }
        }

        foreach ($references as $reference) {
            if (isset($checkedReferences[$reference])) {
                continue;
            }

            $checkedReferences[$reference] = true;
            $candidate = $buildDirectory.'/'.$reference;
            $realCandidate = realpath($candidate);

            if ($realCandidate === false || ! is_file($realCandidate)) {
                $errors[] = "Fichier Vite référencé absent : {$reference}.";

                continue;
            }

            $buildPrefix = rtrim($realBuildDirectory, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR;

            if (! str_starts_with($realCandidate, $buildPrefix)) {
                $errors[] = "Fichier Vite hors du répertoire de build : {$reference}.";
            }
        }
    }

    return $errors;
}
