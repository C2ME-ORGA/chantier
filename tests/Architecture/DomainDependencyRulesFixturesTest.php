<?php

use Closure;
use Composer\Autoload\ClassLoader;
use FilesystemIterator;
use Pest\Arch\Repositories\ObjectsRepository;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use ReflectionProperty;
use RuntimeException;
use Throwable;

/**
 * Runs architecture assertions against a temporary PSR-4 namespace.
 *
 * Pest Arch discovers source files from Composer's active PSR-4 loader. The
 * temporary prefix is registered on that loader and its object repository is
 * reset before and after the assertion so no fixture can leak into other tests.
 */
function withArchitectureFixture(array $files, Closure $callback): mixed
{
    $root = sys_get_temp_dir().'/c2me-architecture-'.bin2hex(random_bytes(8));
    $namespacePrefix = 'App\ArchitectureFixtures\Fixture'.bin2hex(random_bytes(8)).'\';
    $loader = require base_path('vendor/autoload.php');

    if (! $loader instanceof ClassLoader) {
        throw new RuntimeException('Unable to retrieve the Composer class loader.');
    }

    mkdir($root, 0777, true);

    try {
        foreach ($files as $relativePath => $contents) {
            $path = $root.'/'.$relativePath;
            $directory = dirname($path);

            if (! is_dir($directory)) {
                mkdir($directory, 0777, true);
            }

            $contents = str_replace('FixtureNamespace', rtrim($namespacePrefix, '\\'), $contents);
            file_put_contents($path, $contents);
        }

        $loader->addPsr4($namespacePrefix, $root.'/app');
        resetArchitectureObjectsRepository();

        return $callback($root, $namespacePrefix);
    } finally {
        $loader->unregisterPsr4Prefix($namespacePrefix);
        resetArchitectureObjectsRepository();

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

function resetArchitectureObjectsRepository(): void
{
    (new ReflectionProperty(ObjectsRepository::class, 'instance'))->setValue(null, null);
}

function expectArchitectureViolation(Closure $assertion, string $forbiddenNamespace): void
{
    try {
        $assertion();
    } catch (Throwable $exception) {
        expect($exception->getMessage())->toContain($forbiddenNamespace);

        return;
    }

    throw new RuntimeException("Expected an architecture violation for {$forbiddenNamespace}.");
}

it('détecte une dépendance interdite de Core vers un domaine dans une fixture PSR-4 isolée', function (): void {
    withArchitectureFixture([
        'app/Core/Kernel.php' => <<<'PHP'
<?php

namespace FixtureNamespace\Core;

use FixtureNamespace\Domains\Clients\Models\Client;

final class Kernel
{
    public function client(): Client
    {
        return new Client();
    }
}
PHP,
        'app/Domains/Clients/Models/Client.php' => <<<'PHP'
<?php

namespace FixtureNamespace\Domains\Clients\Models;

final class Client {}
PHP,
    ], function (string $root, string $namespacePrefix): void {
        $namespace = rtrim($namespacePrefix, '\\');
        $coreNamespace = $namespace.'\Core';
        $domainsNamespace = $namespace.'\Domains';

        expectArchitectureViolation(
            fn () => arch('fixture Core to Domains')
                ->expect($coreNamespace)
                ->not
                ->toUse($domainsNamespace),
            $domainsNamespace,
        );
    });
});

it('détecte une dépendance inter-domaines vers une implémentation interne', function (): void {
    withArchitectureFixture([
        'app/Domains/Projects/ProjectReader.php' => <<<'PHP'
<?php

namespace FixtureNamespace\Domains\Projects;

use FixtureNamespace\Domains\Clients\Models\Client;

final class ProjectReader
{
    public function client(): Client
    {
        return new Client();
    }
}
PHP,
        'app/Domains/Clients/Models/Client.php' => <<<'PHP'
<?php

namespace FixtureNamespace\Domains\Clients\Models;

final class Client {}
PHP,
        'app/Domains/Clients/Contracts/ClientLookup.php' => <<<'PHP'
<?php

namespace FixtureNamespace\Domains\Clients\Contracts;

interface ClientLookup {}
PHP,
    ], function (string $root, string $namespacePrefix): void {
        $namespace = rtrim($namespacePrefix, '\\');
        $projectsNamespace = $namespace.'\Domains\Projects';
        $clientsNamespace = $namespace.'\Domains\Clients';

        expectArchitectureViolation(
            fn () => arch('fixture domain internal dependency')
                ->expect($projectsNamespace)
                ->not
                ->toUse($clientsNamespace)
                ->ignoring([
                    $clientsNamespace.'\Contracts',
                    $clientsNamespace.'\Events\Integration',
                ]),
            $clientsNamespace,
        );
    });
});

it('accepte une dépendance inter-domaines vers une surface publique CHAN-28', function (): void {
    withArchitectureFixture([
        'app/Domains/Projects/ProjectReader.php' => <<<'PHP'
<?php

namespace FixtureNamespace\Domains\Projects;

use FixtureNamespace\Domains\Clients\Contracts\ClientLookup;

final class ProjectReader
{
    public function __construct(private ClientLookup $clients) {}
}
PHP,
        'app/Domains/Clients/Contracts/ClientLookup.php' => <<<'PHP'
<?php

namespace FixtureNamespace\Domains\Clients\Contracts;

interface ClientLookup {}
PHP,
    ], function (string $root, string $namespacePrefix): void {
        $namespace = rtrim($namespacePrefix, '\\');
        $projectsNamespace = $namespace.'\Domains\Projects';
        $clientsNamespace = $namespace.'\Domains\Clients';

        expect(fn () => arch('fixture public contract dependency')
            ->expect($projectsNamespace)
            ->not
            ->toUse($clientsNamespace)
            ->ignoring([
                $clientsNamespace.'\Contracts',
                $clientsNamespace.'\Events\Integration',
            ]))
            ->not->toThrow(Throwable::class);
    });
});
