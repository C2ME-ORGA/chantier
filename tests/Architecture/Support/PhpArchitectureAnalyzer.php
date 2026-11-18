<?php

namespace Tests\Architecture\Support;

use FilesystemIterator;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use SplFileInfo;

/**
 * Analyses PSR-4 consistency and static PHP dependencies for test fixtures and
 * for the application roots.
 */
final class PhpArchitectureAnalyzer
{
    private PhpFileInspector $inspector;

    public function __construct(?PhpFileInspector $inspector = null)
    {
        $this->inspector = $inspector ?? new PhpFileInspector;
    }

    /**
     * Checks that every named declaration matches the PSR-4 path it lives in.
     *
     * @param  array<string, string>  $roots  root directory => expected namespace prefix
     * @return list<string>
     */
    public function psr4Violations(array $roots): array
    {
        $violations = [];

        foreach ($roots as $root => $namespacePrefix) {
            foreach ($this->phpFiles($root) as $file) {
                $displayPath = $this->displayPath($file);
                $structure = $this->inspector->inspect($file);

                if ($structure['error'] !== null) {
                    $violations[] = $displayPath.': parse error: '.$structure['error'];

                    continue;
                }

                if ($structure['declarations'] === []) {
                    continue;
                }

                $expected = $this->expectedFqcn($root, $file, $namespacePrefix);
                $declared = array_column($structure['declarations'], 'fqcn');

                if (count($declared) !== 1) {
                    $violations[] = sprintf(
                        '%s: expected exactly one declaration matching %s, found %d (%s)',
                        $displayPath,
                        $expected,
                        count($declared),
                        implode(', ', $declared),
                    );

                    continue;
                }

                if ($declared[0] !== $expected) {
                    $violations[] = sprintf(
                        '%s: declared %s, expected %s',
                        $displayPath,
                        $declared[0],
                        $expected,
                    );
                }
            }
        }

        sort($violations);

        return $violations;
    }

    /**
     * Builds the class dependency graph for the given roots.
     *
     * Only references to classes declared in the scanned roots are kept. The
     * graph is a map of fully qualified class names to sorted dependency lists.
     *
     * @param  array<string, string>  $roots  root directory => expected namespace prefix
     * @return array{graph: array<string, list<string>>, errors: list<string>}
     */
    public function dependencyGraph(array $roots): array
    {
        $classToFile = [];
        $structures = [];
        $errors = [];

        foreach ($roots as $root => $namespacePrefix) {
            foreach ($this->phpFiles($root) as $file) {
                $structure = $this->inspector->inspect($file);

                if ($structure['error'] !== null) {
                    $errors[] = $this->displayPath($file).': parse error: '.$structure['error'];

                    continue;
                }

                foreach ($structure['declarations'] as $declaration) {
                    if ($declaration['fqcn'] !== $this->expectedFqcn($root, $file, $namespacePrefix)) {
                        continue;
                    }

                    $classToFile[$declaration['fqcn']] = $file;
                }

                $structures[$file] = $structure;
            }
        }

        $graph = [];

        foreach ($classToFile as $class => $file) {
            $graph[$class] = [];

            foreach ($structures[$file]['references'] as $reference) {
                if ($reference === $class || ! isset($classToFile[$reference])) {
                    continue;
                }

                $graph[$class][$reference] = true;
            }

            $graph[$class] = array_keys($graph[$class]);
            sort($graph[$class]);
        }

        ksort($graph);
        sort($errors);

        return [
            'graph' => $graph,
            'errors' => $errors,
        ];
    }

    /**
     * Returns every elementary directed cycle as an explicit "A -> B -> A" path.
     *
     * Johnson's algorithm enumerates all elementary circuits of a directed
     * graph. Its complexity is O((V + E) * (C + 1)) when the graph has C simple
     * cycles, so the output itself can be exponential in the worst case.
     *
     * @param  array<string, list<string>>  $graph
     * @return list<string>
     */
    public function cycles(array $graph): array
    {
        $nodes = array_keys($graph);
        sort($nodes);

        $nodeIndexes = array_flip($nodes);
        $adjacency = [];

        foreach ($nodes as $node) {
            $dependencies = [];

            foreach ($graph[$node] as $dependency) {
                if (isset($nodeIndexes[$dependency])) {
                    $dependencies[$dependency] = true;
                }
            }

            $dependencies = array_keys($dependencies);
            sort($dependencies);
            $adjacency[$node] = $dependencies;
        }

        $cycles = [];
        $count = count($nodes);

        for ($startIndex = 0; $startIndex < $count; $startIndex++) {
            $start = $nodes[$startIndex];
            $stack = [];
            $blocked = [];
            $blockedBy = [];

            foreach ($nodes as $node) {
                $blocked[$node] = false;
                $blockedBy[$node] = [];
            }

            $unblock = function (string $node) use (&$unblock, &$blocked, &$blockedBy): void {
                $blocked[$node] = false;

                foreach (array_keys($blockedBy[$node]) as $blockingNode) {
                    unset($blockedBy[$node][$blockingNode]);

                    if ($blocked[$blockingNode]) {
                        $unblock($blockingNode);
                    }
                }
            };

            $circuit = function (string $node) use (&$circuit, &$unblock, &$blocked, &$blockedBy, &$stack, &$cycles, $adjacency, $nodeIndexes, $start, $startIndex): bool {
                $found = false;

                $stack[] = $node;
                $blocked[$node] = true;

                foreach ($adjacency[$node] as $dependency) {
                    if ($nodeIndexes[$dependency] < $startIndex) {
                        continue;
                    }

                    if ($dependency === $start) {
                        $cycle = [...$stack, $start];
                        $cycles[$this->canonicalCycle($cycle)] = true;
                        $found = true;

                        continue;
                    }

                    if (! $blocked[$dependency] && $circuit($dependency)) {
                        $found = true;
                    }
                }

                if ($found) {
                    $unblock($node);
                } else {
                    foreach ($adjacency[$node] as $dependency) {
                        if ($nodeIndexes[$dependency] >= $startIndex) {
                            $blockedBy[$dependency][$node] = true;
                        }
                    }
                }

                array_pop($stack);

                return $found;
            };

            $circuit($start);
        }

        $paths = array_keys($cycles);
        sort($paths);

        return $paths;
    }

    /**
     * @return list<string>
     */
    private function phpFiles(string $root): array
    {
        if (! is_dir($root)) {
            return [];
        }

        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
        );

        $files = [];

        foreach ($iterator as $file) {
            if ($file instanceof SplFileInfo && $file->isFile() && strtolower($file->getExtension()) === 'php') {
                $files[] = $file->getPathname();
            }
        }

        sort($files);

        return $files;
    }

    private function expectedFqcn(string $root, string $file, string $namespacePrefix): string
    {
        $normalizedRoot = rtrim(str_replace('\\', '/', $root), '/');
        $normalizedFile = str_replace('\\', '/', $file);
        $relativePath = substr($normalizedFile, strlen($normalizedRoot) + 1);
        $relativeClass = substr($relativePath, 0, -4);

        return rtrim($namespacePrefix, '\\').'\\'.str_replace('/', '\\', $relativeClass);
    }

    private function displayPath(string $file): string
    {
        return str_replace('\\', '/', $file);
    }

    /**
     * @param  list<string>  $cycle
     */
    private function canonicalCycle(array $cycle): string
    {
        array_pop($cycle);

        if ($cycle === []) {
            return '';
        }

        $smallest = 0;

        foreach ($cycle as $index => $class) {
            if (strcmp($class, $cycle[$smallest]) < 0) {
                $smallest = $index;
            }
        }

        $rotated = [
            ...array_slice($cycle, $smallest),
            ...array_slice($cycle, 0, $smallest),
        ];
        $rotated[] = $rotated[0];

        return implode(' -> ', $rotated);
    }
}
