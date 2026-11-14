<?php

function chantierViteManifest(): array
{
    $path = public_path('build/manifest.json');

    if (! is_file($path)) {
        test()->markTestSkipped('Manifest Vite absent : exécutez `npm run build` avant la suite de tests.');
    }

    $manifest = json_decode((string) file_get_contents($path), true);

    expect($manifest)->toBeArray();

    return $manifest;
}

test('le manifest Vite expose les entrées CSS et JavaScript avec des fichiers physiques', function () {
    $manifest = chantierViteManifest();

    expect($manifest)->toHaveKeys(['resources/css/app.css', 'resources/js/app.js']);

    $cssEntry = $manifest['resources/css/app.css'];
    $jsEntry = $manifest['resources/js/app.js'];

    $cssPath = public_path('build/'.$cssEntry['file']);
    $jsPath = public_path('build/'.$jsEntry['file']);

    expect($cssEntry['isEntry'] ?? false)->toBeTrue()
        ->and($jsEntry['isEntry'] ?? false)->toBeTrue()
        ->and($cssPath)->toBeFile()
        ->and($jsPath)->toBeFile()
        ->and(filesize($cssPath))->toBeGreaterThan(0);
});

test('la page d accueil charge les assets compilés par Vite sans CSS de repli', function () {
    $manifest = chantierViteManifest();

    if (is_file(public_path('hot'))) {
        test()->markTestSkipped('Serveur Vite actif (public/hot) : le scénario de production n’est pas applicable.');
    }

    $this->get('/')
        ->assertOk()
        ->assertSee('build/'.$manifest['resources/css/app.css']['file'], false)
        ->assertSee('build/'.$manifest['resources/js/app.js']['file'], false)
        ->assertSee('rel="stylesheet"', false)
        ->assertDontSee('@layer properties{', false);
});

test('les utilitaires Tailwind de la page d accueil sont présents dans le CSS compilé', function () {
    $manifest = chantierViteManifest();

    $css = (string) file_get_contents(public_path('build/'.$manifest['resources/css/app.css']['file']));

    expect($css)->toContain('max-width:335px')
        ->toContain('text-decoration-line:underline')
        ->toContain('#f53003')
        ->toContain('--font-sans:');

    expect(preg_match('/\.flex\{display:flex\}/', $css))->toBe(1);
});
