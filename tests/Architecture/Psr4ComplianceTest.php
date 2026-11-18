<?php

use Tests\Architecture\Support\ArchitectureFixture;
use Tests\Architecture\Support\PhpArchitectureAnalyzer;

it('respecte le mapping PSR-4 des racines Core et Domains', function (): void {
    $applicationRoot = dirname(__DIR__, 2);
    $analyzer = new PhpArchitectureAnalyzer;

    $violations = $analyzer->psr4Violations([
        $applicationRoot.'/app/Core' => 'App\\Core',
        $applicationRoot.'/app/Domains' => 'App\\Domains',
    ]);

    expect($violations)->toBe([]);
});

it('accepte une arborescence PSR-4 valide pour classes, interfaces, traits et enums', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/ValidClass.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class ValidClass
{
}
PHP,
        'Domains/Projects/Contracts/ValidContract.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects\Contracts;

interface ValidContract
{
}
PHP,
        'Domains/Projects/Concerns/ValidTrait.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects\Concerns;

trait ValidTrait
{
}
PHP,
        'Domains/Projects/Enums/ValidEnum.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects\Enums;

enum ValidEnum
{
    case One;
}
PHP,
        'Domains/Projects/README.md' => 'Not a PHP file.',
    ]);

    try {
        $violations = (new PhpArchitectureAnalyzer)->psr4Violations([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        expect($violations)->toBe([]);
    } finally {
        $fixture->close();
    }
});

it('signale un namespace qui ne correspond pas au chemin du fichier', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/WrongNamespace.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Wrong;

final class WrongNamespace
{
}
PHP,
    ]);

    try {
        $violations = (new PhpArchitectureAnalyzer)->psr4Violations([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
        ]);

        expect($violations)->toHaveCount(1)
            ->and($violations[0])->toContain('Core/WrongNamespace.php')
            ->and($violations[0])->toContain('declared '.$fixture->namespace.'\\Wrong\\WrongNamespace')
            ->and($violations[0])->toContain('expected '.$fixture->namespace.'\\Core\\WrongNamespace');
    } finally {
        $fixture->close();
    }
});

it('signale un nom de classe qui ne correspond pas au fichier', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/ExpectedName.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class OtherName
{
}
PHP,
    ]);

    try {
        $violations = (new PhpArchitectureAnalyzer)->psr4Violations([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
        ]);

        expect($violations)->toHaveCount(1)
            ->and($violations[0])->toContain('Core/ExpectedName.php')
            ->and($violations[0])->toContain('declared '.$fixture->namespace.'\\Core\\OtherName')
            ->and($violations[0])->toContain('expected '.$fixture->namespace.'\\Core\\ExpectedName');
    } finally {
        $fixture->close();
    }
});

it('signale toutes les déclarations d’un fichier qui en contient plusieurs', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/First.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class First
{
}

final class Second
{
}
PHP,
    ]);

    try {
        $violations = (new PhpArchitectureAnalyzer)->psr4Violations([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
        ]);

        expect($violations)->toHaveCount(1)
            ->and($violations[0])->toContain('Core/First.php')
            ->and($violations[0])->toContain('found 2')
            ->and($violations[0])->toContain($fixture->namespace.'\\Core\\First')
            ->and($violations[0])->toContain($fixture->namespace.'\\Core\\Second');
    } finally {
        $fixture->close();
    }
});

it('ignore les fichiers non PHP et les répertoires vides', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/README.md' => 'Documentation.',
        'Domains/Projects/.gitkeep' => '',
        'Domains/Projects/Empty/README.txt' => 'Empty section.',
    ]);

    try {
        $violations = (new PhpArchitectureAnalyzer)->psr4Violations([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
            $fixture->root.'/Missing' => $fixture->namespace.'\\Missing',
        ]);

        expect($violations)->toBe([]);
    } finally {
        $fixture->close();
    }
});

it('signale une erreur de parsing PHP avec le fichier concerné', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Broken.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class Broken
{
PHP,
    ]);

    try {
        $violations = (new PhpArchitectureAnalyzer)->psr4Violations([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
        ]);

        expect($violations)->toHaveCount(1)
            ->and($violations[0])->toContain('Core/Broken.php')
            ->and($violations[0])->toContain('parse error');
    } finally {
        $fixture->close();
    }
});

it('produit des violations déterministes', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Zeta.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Wrong;

final class Zeta
{
}
PHP,
        'Core/Alpha.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Wrong;

final class Alpha
{
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $roots = [$fixture->root.'/Core' => $fixture->namespace.'\\Core'];

        expect($analyzer->psr4Violations($roots))->toBe($analyzer->psr4Violations($roots));
    } finally {
        $fixture->close();
    }
});
