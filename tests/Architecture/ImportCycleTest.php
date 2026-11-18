<?php

use Tests\Architecture\Support\ArchitectureFixture;
use Tests\Architecture\Support\PhpArchitectureAnalyzer;

it('ne détecte aucun cycle dans les sources Core et Domains', function (): void {
    $applicationRoot = dirname(__DIR__, 2);
    $analyzer = new PhpArchitectureAnalyzer;

    $result = $analyzer->dependencyGraph([
        $applicationRoot.'/app/Core' => 'App\\Core',
        $applicationRoot.'/app/Domains' => 'App\\Domains',
    ]);

    expect($result['errors'])->toBe([])
        ->and($analyzer->cycles($result['graph']))->toBe([]);
});

it('détecte un cycle simple et restitue son chemin', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Projects\B;

final class A
{
    public function __construct(private readonly B $b) {}
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Core\A;

final class B
{
    public function __construct(private readonly A $a) {}
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([$a.' -> '.$b.' -> '.$a]);
    } finally {
        $fixture->close();
    }
});

it('détecte un cycle à partir d’imports explicites sans usage', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Projects\B;

final class A
{
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Core\A;

final class B
{
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([$a.' -> '.$b.' -> '.$a]);
    } finally {
        $fixture->close();
    }
});

it('détecte un cycle à partir d’imports groupés', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\{Clients\C, Projects\B};

final class A
{
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Core\A;

final class B
{
}
PHP,
        'Domains/Clients/C.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients;

final class C
{
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([$a.' -> '.$b.' -> '.$a]);
    } finally {
        $fixture->close();
    }
});

it('détecte un cycle à partir de références non qualifiées du même namespace', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class A
{
    public function __construct(private readonly B $b) {}
}
PHP,
        'Core/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class B
{
    public function __construct(private readonly A $a) {}
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Core\\B';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([$a.' -> '.$b.' -> '.$a]);
    } finally {
        $fixture->close();
    }
});

it('détecte un cycle à partir d’un import avec alias', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Projects\B as ProjectB;

final class A
{
    public function __construct(private readonly ProjectB $b) {}
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Core\A;

final class B
{
    public function __construct(private readonly A $a) {}
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([$a.' -> '.$b.' -> '.$a]);
    } finally {
        $fixture->close();
    }
});

it('énumère les cycles qui se chevauchent', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Clients\C;
use __FIXTURE_NAMESPACE__\Domains\Projects\B;

final class A
{
    public function __construct(private readonly B $b, private readonly C $c) {}
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Domains\Clients\C;

final class B
{
    public function __construct(private readonly C $c) {}
}
PHP,
        'Domains/Clients/C.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients;

use __FIXTURE_NAMESPACE__\Core\A;

final class C
{
    public function __construct(private readonly A $a) {}
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';
        $c = $fixture->namespace.'\\Domains\\Clients\\C';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([
                $a.' -> '.$c.' -> '.$a,
                $a.' -> '.$b.' -> '.$c.' -> '.$a,
            ]);
    } finally {
        $fixture->close();
    }
});

it('produit des cycles déterministes quel que soit l’ordre du graphe', function (): void {
    $analyzer = new PhpArchitectureAnalyzer;

    $graph = [
        'C' => ['A'],
        'A' => ['C', 'B'],
        'B' => ['C'],
    ];

    $reordered = [
        'B' => ['C'],
        'C' => ['A'],
        'A' => ['B', 'C'],
    ];

    $expected = [
        'A -> B -> C -> A',
        'A -> C -> A',
    ];

    expect($analyzer->cycles($graph))->toBe($expected)
        ->and($analyzer->cycles($reordered))->toBe($expected)
        ->and($analyzer->cycles($graph))->toBe($expected);
});

it('détecte un cycle à trois classes et restitue un chemin explicite', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Projects\B;

final class A
{
    public function __construct(private readonly B $b) {}
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Domains\Clients\C;

final class B
{
    public function __construct(private readonly C $c) {}
}
PHP,
        'Domains/Clients/C.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients;

use __FIXTURE_NAMESPACE__\Core\A;

final class C
{
    public function __construct(private readonly A $a) {}
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';
        $c = $fixture->namespace.'\\Domains\\Clients\\C';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([$a.' -> '.$b.' -> '.$c.' -> '.$a]);
    } finally {
        $fixture->close();
    }
});

it('détecte plusieurs cycles distincts', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Projects\B;

final class A
{
    public function __construct(private readonly B $b) {}
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Core\A;

final class B
{
    public function __construct(private readonly A $a) {}
}
PHP,
        'Core/C.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Clients\D;

final class C
{
    public function __construct(private readonly D $d) {}
}
PHP,
        'Domains/Clients/D.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients;

use __FIXTURE_NAMESPACE__\Core\C;

final class D
{
    public function __construct(private readonly C $c) {}
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';
        $c = $fixture->namespace.'\\Core\\C';
        $d = $fixture->namespace.'\\Domains\\Clients\\D';

        $cycles = $analyzer->cycles($result['graph']);

        expect($result['errors'])->toBe([])
            ->and($cycles)->toHaveCount(2)
            ->and($cycles)->toContain($a.' -> '.$b.' -> '.$a)
            ->and($cycles)->toContain($c.' -> '.$d.' -> '.$c);
    } finally {
        $fixture->close();
    }
});

it('ne détecte aucun cycle dans un graphe acyclique hors périmètre ignoré', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

use __FIXTURE_NAMESPACE__\Domains\Projects\B;
use App\Models\User;

final class A
{
    public function __construct(private readonly B $b, private readonly User $user) {}
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

use __FIXTURE_NAMESPACE__\Domains\Clients\C;

final class B
{
    public function __construct(private readonly C $c) {}
}
PHP,
        'Domains/Clients/C.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Clients;

final class C
{
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([]);
    } finally {
        $fixture->close();
    }
});

it('détecte un cycle déclaré sans instruction use explicite', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/A.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class A
{
    public function make(): \__FIXTURE_NAMESPACE__\Domains\Projects\B
    {
        return new \__FIXTURE_NAMESPACE__\Domains\Projects\B();
    }
}
PHP,
        'Domains/Projects/B.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Domains\Projects;

final class B
{
    public function make(): \__FIXTURE_NAMESPACE__\Core\A
    {
        return new \__FIXTURE_NAMESPACE__\Core\A();
    }
}
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        $a = $fixture->namespace.'\\Core\\A';
        $b = $fixture->namespace.'\\Domains\\Projects\\B';

        expect($result['errors'])->toBe([])
            ->and($analyzer->cycles($result['graph']))->toBe([$a.' -> '.$b.' -> '.$a]);
    } finally {
        $fixture->close();
    }
});

it('signale une erreur de parsing au lieu de l’ignorer dans le graphe', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/Broken.php' => <<<'PHP'
<?php

namespace __FIXTURE_NAMESPACE__\Core;

final class Broken
{
PHP,
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
        ]);

        expect($result['errors'])->toHaveCount(1)
            ->and($result['errors'][0])->toContain('Core/Broken.php')
            ->and($result['errors'][0])->toContain('parse error')
            ->and($result['graph'])->toBe([]);
    } finally {
        $fixture->close();
    }
});

it('retourne un graphe vide pour des répertoires vides', function (): void {
    $fixture = ArchitectureFixture::create([
        'Core/.gitkeep' => '',
        'Domains/.gitkeep' => '',
    ]);

    try {
        $analyzer = new PhpArchitectureAnalyzer;
        $result = $analyzer->dependencyGraph([
            $fixture->root.'/Core' => $fixture->namespace.'\\Core',
            $fixture->root.'/Domains' => $fixture->namespace.'\\Domains',
        ]);

        expect($result)->toBe(['graph' => [], 'errors' => []])
            ->and($analyzer->cycles($result['graph']))->toBe([]);
    } finally {
        $fixture->close();
    }
});
