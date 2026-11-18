<?php

use Tests\Architecture\Support\ArchitectureFixture;
use Tests\Architecture\Support\PestArchFixtureRule;

it('rejette une dépendance du Core vers un domaine métier dans une fixture isolée', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Kernel.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Clients\Models\Client;

final class Kernel
{
    public function client(): Client
    {
        return new Client();
    }
}
PHP,
        'Domains/Clients/Models/Client.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients\Models;

final class Client
{
}
PHP,
    ]);

    try {
        $message = PestArchFixtureRule::assertRejects(
            $fixture->root,
            $fixture->namespace,
            $fixture->namespace.'\\Core',
            $fixture->namespace.'\\Domains',
        );

        expect($message)->toContain($fixture->namespace.'\\Domains');
    } finally {
        $fixture->close();
    }
});

it('rejette l’import d’un Model interne d’un autre domaine', function (): void {
    $fixture = ArchitectureFixture::create([
        'Domains/Projects/ProjectReader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Domains\Clients\Models\Client;

final class ProjectReader
{
    public function client(): Client
    {
        return new Client();
    }
}
PHP,
        'Domains/Clients/Models/Client.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients\Models;

final class Client
{
}
PHP,
        'Domains/Clients/Contracts/ClientLookup.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients\Contracts;

interface ClientLookup
{
}
PHP,
        'Domains/Clients/Events/Integration/ClientRegistered.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients\Events\Integration;

final class ClientRegistered
{
}
PHP,
    ]);

    try {
        $clients = $fixture->namespace.'\\Domains\\Clients';

        $message = PestArchFixtureRule::assertRejects(
            $fixture->root,
            $fixture->namespace,
            $fixture->namespace.'\\Domains\\Projects',
            $clients,
            [
                $clients.'\\Contracts',
                $clients.'\\Events\\Integration',
            ],
        );

        expect($message)->toContain($clients);
    } finally {
        $fixture->close();
    }
});

it('accepte un import inter-domaines vers Contracts', function (): void {
    $fixture = ArchitectureFixture::create([
        'Domains/Projects/ProjectReader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Domains\Clients\Contracts\ClientLookup;

final class ProjectReader
{
    public function __construct(private readonly ClientLookup $clients) {}
}
PHP,
        'Domains/Clients/Contracts/ClientLookup.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients\Contracts;

interface ClientLookup
{
}
PHP,
    ]);

    try {
        $clients = $fixture->namespace.'\\Domains\\Clients';
        $ignoring = [
            $clients.'\\Contracts',
            $clients.'\\Events\\Integration',
        ];

        $message = PestArchFixtureRule::assertRejects(
            $fixture->root,
            $fixture->namespace,
            $fixture->namespace.'\\Domains\\Projects',
            $clients,
        );

        expect($message)->toContain($clients);

        PestArchFixtureRule::assertAllows(
            $fixture->root,
            $fixture->namespace,
            $fixture->namespace.'\\Domains\\Projects',
            $clients,
            $ignoring,
        );
    } finally {
        $fixture->close();
    }
});

it('accepte un import inter-domaines vers Events\\Integration', function (): void {
    $fixture = ArchitectureFixture::create([
        'Domains/Projects/ProjectListener.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Domains\Clients\Events\Integration\ClientRegistered;

final class ProjectListener
{
    public function __invoke(ClientRegistered $event): void {}
}
PHP,
        'Domains/Clients/Events/Integration/ClientRegistered.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients\Events\Integration;

final class ClientRegistered
{
}
PHP,
    ]);

    try {
        $clients = $fixture->namespace.'\\Domains\\Clients';
        $ignoring = [
            $clients.'\\Contracts',
            $clients.'\\Events\\Integration',
        ];

        $message = PestArchFixtureRule::assertRejects(
            $fixture->root,
            $fixture->namespace,
            $fixture->namespace.'\\Domains\\Projects',
            $clients,
        );

        expect($message)->toContain($clients);

        PestArchFixtureRule::assertAllows(
            $fixture->root,
            $fixture->namespace,
            $fixture->namespace.'\\Domains\\Projects',
            $clients,
            $ignoring,
        );
    } finally {
        $fixture->close();
    }
});
