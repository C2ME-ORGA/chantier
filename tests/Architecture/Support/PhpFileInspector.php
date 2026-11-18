<?php

namespace Tests\Architecture\Support;

use PhpParser\Error;
use PhpParser\Node;
use PhpParser\NodeFinder;
use PhpParser\NodeTraverser;
use PhpParser\NodeVisitor\NameResolver;
use PhpParser\Parser;
use PhpParser\ParserFactory;

/**
 * Inspects one PHP source file without loading its classes.
 *
 * @phpstan-type Declaration array{namespace: string, name: string, kind: string, fqcn: string}
 * @phpstan-type Structure array{declarations: list<Declaration>, references: list<string>, error: string|null}
 */
final class PhpFileInspector
{
    private Parser $parser;

    public function __construct(?Parser $parser = null)
    {
        $this->parser = $parser ?? (new ParserFactory)->createForNewestSupportedVersion();
    }

    /**
     * @return Structure
     */
    public function inspect(string $path): array
    {
        $source = @file_get_contents($path);

        if ($source === false) {
            return $this->failure('unable to read file');
        }

        try {
            $statements = $this->parser->parse($source) ?? [];
            $statements = (new NodeTraverser(new NameResolver(null, ['replaceNodes' => false])))->traverse($statements);
        } catch (Error $error) {
            return $this->failure($error->getMessage());
        }

        $collector = new PhpReferenceCollector;
        (new NodeTraverser($collector))->traverse($statements);

        return [
            'declarations' => $this->declarations($statements),
            'references' => array_keys($collector->references),
            'error' => null,
        ];
    }

    /**
     * @param  list<Node>  $statements
     * @return list<array{namespace: string, name: string, kind: string, fqcn: string}>
     */
    private function declarations(array $statements): array
    {
        $finder = new NodeFinder;
        $namespaces = $finder->findInstanceOf($statements, Node\Stmt\Namespace_::class);

        if ($namespaces === []) {
            return $this->declarationsWithin($statements, '');
        }

        $declarations = [];

        foreach ($namespaces as $namespace) {
            $prefix = $namespace->name instanceof Node\Name ? $namespace->name->toString() : '';

            $declarations = [
                ...$declarations,
                ...$this->declarationsWithin($namespace->stmts, $prefix),
            ];
        }

        return $declarations;
    }

    /**
     * @param  list<Node>  $statements
     * @return list<array{namespace: string, name: string, kind: string, fqcn: string}>
     */
    private function declarationsWithin(array $statements, string $namespace): array
    {
        $finder = new NodeFinder;
        $nodes = $finder->findInstanceOf($statements, Node\Stmt\ClassLike::class);

        usort($nodes, static fn (Node\Stmt\ClassLike $left, Node\Stmt\ClassLike $right): int => $left->getStartLine() <=> $right->getStartLine());

        $declarations = [];

        foreach ($nodes as $node) {
            if (! $node->name instanceof Node\Identifier) {
                continue;
            }

            $name = $node->name->toString();

            $declarations[] = [
                'namespace' => $namespace,
                'name' => $name,
                'kind' => match (true) {
                    $node instanceof Node\Stmt\Class_ => 'class',
                    $node instanceof Node\Stmt\Interface_ => 'interface',
                    $node instanceof Node\Stmt\Trait_ => 'trait',
                    $node instanceof Node\Stmt\Enum_ => 'enum',
                },
                'fqcn' => $namespace === '' ? $name : $namespace.'\\'.$name,
            ];
        }

        return $declarations;
    }

    /**
     * @return Structure
     */
    private function failure(string $message): array
    {
        return [
            'declarations' => [],
            'references' => [],
            'error' => $message,
        ];
    }
}
