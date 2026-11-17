#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Vérifie le manifest Vite et l'existence des fichiers qu'il référence.
 *
 * Ce script est exécuté par le job `ci` de .github/workflows/tests.yml après
 * `npm ci` et `npm run build`. Il échoue si le manifest est absent, invalide ou
 * si un asset référencé manque dans public/build.
 *
 *   php scripts/ci/verify-vite-build.php
 */
$projectRoot = dirname(__DIR__, 2);

require_once __DIR__.'/lib/vite-build.php';

$buildDirectory = $projectRoot.'/public/build';
$manifestPath = $buildDirectory.'/manifest.json';
$requiredEntries = [
    'resources/css/app.css',
    'resources/js/app.js',
];

$errors = c2me_vite_manifest_errors($manifestPath, $buildDirectory, $requiredEntries);

if ($errors !== []) {
    foreach ($errors as $error) {
        fwrite(STDERR, "ÉCHEC : {$error}\n");
    }

    exit(1);
}

fwrite(STDOUT, "Manifest Vite valide : {$manifestPath}\n");

foreach ($requiredEntries as $entry) {
    fwrite(STDOUT, "  - entrée : {$entry}\n");
}

fwrite(STDOUT, "Tous les fichiers référencés sont présents dans public/build.\n");

exit(0);
