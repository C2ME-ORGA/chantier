<?php

function withArchitectureFixture(array $files, Closure $callback): mixed
{
    $root = sys_get_temp_dir().'/c2me-architecture-'.bin2hex(random_bytes(8));

    mkdir($root, 0777, true);

    try {
        foreach ($files as $relativePath => $contents) {
            $path = $root.'/'.$relativePath;
            $directory = dirname($path);

            if (! is_dir($directory)) {
                mkdir($directory, 0777, true);
            }

            file_put_contents($path, $contents);
        }

        return $callback($root);
    } finally {
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST,
        );

        foreach ($iterator as $item) {
            $item->isDir() ? rmdir($item->getPathname()) : unlink($item->getPathname());
        }

        rmdir($root);
    }
}

it('détecte une dépendance interdite de Core vers un domaine dans une fixture isolée', function (): void {
    withArchitectureFixture([
        'Core/Kernel.php' => <<<'PHP'
<?php

namespace App\Core;

use App\Domains\Clients\Models\Client;

final class Kernel
{
    public function client(): Client
    {
        return new Client();
    }
}
PHP,
    ], function (string $root): void {
        expect(fn () => arch($root)
            ->expect('App\Core')
            ->not
            ->toUse('App\Domains'))
            ->toThrow(\\Throwable::class);
    });
});

it('détecte une dépendance inter-domaines vers une implémentation interne', function (): void {
    withArchitectureFixture([
        'Domains/Projects/ProjectReader.php' => <<<'PHP'
<?php

namespace App\Domains\Projects;

use App\Domains\Clients\Models\Client;

final class ProjectReader
{
    public function client(): Client
    {
        return new Client();
    }
}
PHP,
    ], function (string $root): void {
        expect(fn () => arch($root)
            ->expect('App\Domains\Projects')
            ->not
            ->toUse('App\Domains\Clients')
            ->ignoring([
                'App\Domains\Clients\Contracts',
                'App\Domains\Clients\Events\Integration',
            ]))
            ->toThrow(\\Throwable::class);
    });
});

it('accepte une dépendance inter-domaines vers une surface publique CHAN-28', function (): void {
    withArchitectureFixture([
        'Domains/Projects/ProjectReader.php' => <<<'PHP'
<?php

namespace App\Domains\Projects;

use App\Domains\Clients\Contracts\ClientLookup;

final class ProjectReader
{
    public function __construct(private ClientLookup $clients) {}
}
PHP,
    ], function (string $root): void {
        expect(fn () => arch($root)
            ->expect('App\Domains\Projects')
            ->not
            ->toUse('App\Domains\Clients')
            ->ignoring([
                'App\Domains\Clients\Contracts',
                'App\Domains\Clients\Events\Integration',
            ]))
            ->not->toThrow(\\Throwable::class);
    });
});
