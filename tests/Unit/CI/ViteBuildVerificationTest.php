<?php

require_once dirname(__DIR__, 3).'/scripts/ci/lib/vite-build.php';

function chan36ViteRoot(): string
{
    $root = sys_get_temp_dir().'/chan36-vite-'.bin2hex(random_bytes(6));
    mkdir($root.'/build/assets', 0777, true);

    return $root;
}

function chan36ViteBuild(string $root): string
{
    return $root.'/build';
}

function chan36ViteManifest(): array
{
    return [
        'resources/css/app.css' => [
            'file' => 'assets/app.css',
            'src' => 'resources/css/app.css',
            'isEntry' => true,
        ],
        'resources/js/app.js' => [
            'file' => 'assets/app.js',
            'src' => 'resources/js/app.js',
            'isEntry' => true,
        ],
    ];
}

function chan36WriteViteFile(string $root, string $relativePath, string $contents = ''): void
{
    $path = chan36ViteBuild($root).'/'.$relativePath;

    if (! is_dir(dirname($path))) {
        mkdir(dirname($path), 0777, true);
    }

    file_put_contents($path, $contents);
}

function chan36WriteViteManifest(string $root, array $manifest): void
{
    file_put_contents(
        chan36ViteBuild($root).'/manifest.json',
        json_encode($manifest, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR),
    );
}

function chan36RemoveDirectory(string $directory): void
{
    if (! is_dir($directory)) {
        return;
    }

    $items = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST,
    );

    foreach ($items as $item) {
        if ($item->isDir()) {
            rmdir($item->getPathname());
        } else {
            unlink($item->getPathname());
        }
    }

    rmdir($directory);
}

test('accepte un manifest Vite complet et des fichiers référencés présents', function (): void {
    $root = chan36ViteRoot();

    try {
        chan36WriteViteFile($root, 'assets/app.css', 'body {}');
        chan36WriteViteFile($root, 'assets/app.js');
        chan36WriteViteManifest($root, chan36ViteManifest());

        expect(c2me_vite_manifest_errors(
            chan36ViteBuild($root).'/manifest.json',
            chan36ViteBuild($root),
            ['resources/css/app.css', 'resources/js/app.js'],
        ))->toBe([]);
    } finally {
        chan36RemoveDirectory($root);
    }
});

test('refuse un manifest Vite absent', function (): void {
    $root = chan36ViteRoot();

    try {
        $errors = c2me_vite_manifest_errors(
            chan36ViteBuild($root).'/manifest.json',
            chan36ViteBuild($root),
            ['resources/css/app.css'],
        );

        expect($errors)->toHaveCount(1)
            ->and($errors[0])->toContain('Manifest Vite absent');
    } finally {
        chan36RemoveDirectory($root);
    }
});

test('refuse un manifest Vite JSON invalide', function (): void {
    $root = chan36ViteRoot();

    try {
        file_put_contents(chan36ViteBuild($root).'/manifest.json', '{invalide');

        $errors = c2me_vite_manifest_errors(
            chan36ViteBuild($root).'/manifest.json',
            chan36ViteBuild($root),
            ['resources/css/app.css'],
        );

        expect($errors)->toHaveCount(1)
            ->and($errors[0])->toContain('JSON invalide');
    } finally {
        chan36RemoveDirectory($root);
    }
});

test('refuse une entrée Vite obligatoire absente', function (): void {
    $root = chan36ViteRoot();

    try {
        chan36WriteViteFile($root, 'assets/app.css', 'body {}');
        $manifest = chan36ViteManifest();
        unset($manifest['resources/js/app.js']);
        chan36WriteViteManifest($root, $manifest);

        $errors = c2me_vite_manifest_errors(
            chan36ViteBuild($root).'/manifest.json',
            chan36ViteBuild($root),
            ['resources/css/app.css', 'resources/js/app.js'],
        );

        expect($errors)->toContain('Entrée Vite obligatoire absente du manifest : resources/js/app.js.');
    } finally {
        chan36RemoveDirectory($root);
    }
});

test('refuse un fichier référencé par le manifest absent du build', function (): void {
    $root = chan36ViteRoot();

    try {
        chan36WriteViteFile($root, 'assets/app.js');
        $manifest = chan36ViteManifest();
        $manifest['resources/css/app.css']['file'] = 'assets/app-absent.css';
        chan36WriteViteManifest($root, $manifest);

        $errors = c2me_vite_manifest_errors(
            chan36ViteBuild($root).'/manifest.json',
            chan36ViteBuild($root),
            ['resources/css/app.css', 'resources/js/app.js'],
        );

        expect($errors)->toContain('Fichier Vite référencé absent : assets/app-absent.css.');
    } finally {
        chan36RemoveDirectory($root);
    }
});

test('refuse un fichier Vite référencé hors du répertoire de build', function (): void {
    $root = chan36ViteRoot();

    try {
        chan36WriteViteFile($root, 'assets/app.css', 'body {}');
        chan36WriteViteFile($root, 'assets/app.js');
        file_put_contents($root.'/hors-build.css', 'body {}');

        $manifest = chan36ViteManifest();
        $manifest['_hors_build'] = ['file' => '../hors-build.css'];
        chan36WriteViteManifest($root, $manifest);

        $errors = c2me_vite_manifest_errors(
            chan36ViteBuild($root).'/manifest.json',
            chan36ViteBuild($root),
            ['resources/css/app.css', 'resources/js/app.js'],
        );

        expect($errors)->toContain('Fichier Vite hors du répertoire de build : ../hors-build.css.');
    } finally {
        chan36RemoveDirectory($root);
    }
});
