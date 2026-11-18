<?php

use Tests\Architecture\Support\ArchitectureFixture;
use Tests\Architecture\Support\PhpFileInspector;

it('résout une référence non qualifiée dans le même namespace', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Reader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class Reader
{
    public function target(): Target
    {
        return new Target();
    }
}
PHP,
        'Core/Target.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class Target
{
}
PHP,
    ]);

    try {
        $structure = (new PhpFileInspector)->inspect($fixture->root.'/Core/Reader.php');

        expect($structure['error'])->toBeNull()
            ->and($structure['references'])->toContain($fixture->namespace.'\\Core\\Target')
            ->and($structure['references'])->not->toContain('Target');
    } finally {
        $fixture->close();
    }
});

it('résout une référence qualifiée relative au namespace courant', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Reader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class Reader
{
    public function target(): Sub\Target
    {
        return new Sub\Target();
    }
}
PHP,
        'Core/Sub/Target.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core\Sub;

final class Target
{
}
PHP,
    ]);

    try {
        $structure = (new PhpFileInspector)->inspect($fixture->root.'/Core/Reader.php');

        expect($structure['error'])->toBeNull()
            ->and($structure['references'])->toContain($fixture->namespace.'\\Core\\Sub\\Target');
    } finally {
        $fixture->close();
    }
});

it('résout un import avec alias', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Reader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Projects\Target as ProjectTarget;

final class Reader
{
    public function target(): ProjectTarget
    {
        return new ProjectTarget();
    }
}
PHP,
        'Domains/Projects/Target.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

final class Target
{
}
PHP,
    ]);

    try {
        $structure = (new PhpFileInspector)->inspect($fixture->root.'/Core/Reader.php');

        expect($structure['error'])->toBeNull()
            ->and($structure['references'])->toContain($fixture->namespace.'\\Domains\\Projects\\Target')
            ->and($structure['references'])->not->toContain('ProjectTarget');
    } finally {
        $fixture->close();
    }
});

it('résout les imports groupés', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Reader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\{Clients\First, Projects\Second as ProjectSecond};

final class Reader
{
    public function first(): First
    {
        return new First();
    }

    public function second(): ProjectSecond
    {
        return new ProjectSecond();
    }
}
PHP,
        'Domains/Clients/First.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients;

final class First
{
}
PHP,
        'Domains/Projects/Second.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

final class Second
{
}
PHP,
    ]);

    try {
        $structure = (new PhpFileInspector)->inspect($fixture->root.'/Core/Reader.php');

        expect($structure['error'])->toBeNull()
            ->and($structure['references'])->toContain($fixture->namespace.'\\Domains\\Clients\\First')
            ->and($structure['references'])->toContain($fixture->namespace.'\\Domains\\Projects\\Second')
            ->and($structure['references'])->not->toContain('ProjectSecond');
    } finally {
        $fixture->close();
    }
});

it('résout une référence pleinement qualifiée', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Reader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class Reader
{
    public function target(): \__FIXTURE_NAMESPACE__\Domains\Projects\Target
    {
        return new \__FIXTURE_NAMESPACE__\Domains\Projects\Target();
    }
}
PHP,
        'Domains/Projects/Target.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

final class Target
{
}
PHP,
    ]);

    try {
        $structure = (new PhpFileInspector)->inspect($fixture->root.'/Core/Reader.php');

        expect($structure['error'])->toBeNull()
            ->and($structure['references'])->toContain($fixture->namespace.'\\Domains\\Projects\\Target');
    } finally {
        $fixture->close();
    }
});

it('ignore les appels de fonctions et les constantes comme dépendances de classes', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Reader.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use function __FIXTURE_NAMESPACE__\Core\helper;
use const __FIXTURE_NAMESPACE__\Core\FLAG;

final class Reader
{
    public function run(): void
    {
        helper();
        $flag = FLAG;
    }
}
PHP,
        'Core/helper.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class helper
{
}
PHP,
        'Core/FLAG.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class FLAG
{
}
PHP,
    ]);

    try {
        $structure = (new PhpFileInspector)->inspect($fixture->root.'/Core/Reader.php');

        expect($structure['error'])->toBeNull()
            ->and($structure['references'])->not->toContain($fixture->namespace.'\\Core\\helper')
            ->and($structure['references'])->not->toContain($fixture->namespace.'\\Core\\FLAG');
    } finally {
        $fixture->close();
    }
});
