<?php

use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use SplFileInfo;

it('respecte le mapping PSR-4 App\\\\ vers app/ dans Core et Domains', function (): void {
    $applicationRoot = dirname(__DIR__, 2);
    $roots = [
        'Core' => $applicationRoot.'/app/Core',
        'Domains' => $applicationRoot.'/app/Domains',
    ];

    $violations = [];

    foreach ($roots as $area => $root) {
        expect(is_dir($root))->toBeTrue();

        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($root, RecursiveDirectoryIterator::SKIP_DOTS)
        );

        foreach ($iterator as $file) {
            if (! $file instanceof SplFileInfo || ! $file->isFile() || $file->getExtension() !== 'php') {
                continue;
            }

            $relativePath = substr($file->getPathname(), strlen($applicationRoot.'/app/') );
            $expectedClass = 'App\\'.str_replace(['/', '.php'], ['\\', ''], $relativePath);
            $tokens = token_get_all(file_get_contents($file->getPathname()));
            $namespace = '';
            $declaredClasses = [];

            for ($index = 0, $count = count($tokens); $index < $count; $index++) {
                $token = $tokens[$index];

                if (! is_array($token)) {
                    continue;
                }

                if ($token[0] === T_NAMESPACE) {
                    $namespaceParts = [];

                    for ($cursor = $index + 1; $cursor < $count; $cursor++) {
                        $part = $tokens[$cursor];

                        if ($part === ';' || $part === '{') {
                            break;
                        }

                        if (is_array($part) && in_array($part[0], [T_STRING, T_NAME_QUALIFIED, T_NS_SEPARATOR], true)) {
                            $namespaceParts[] = $part[1];
                        }
                    }

                    $namespace = implode('', $namespaceParts);
                }

                if (! in_array($token[0], [T_CLASS, T_INTERFACE, T_TRAIT, T_ENUM], true)) {
                    continue;
                }

                $previous = $index - 1;
                while ($previous >= 0 && is_array($tokens[$previous]) && in_array($tokens[$previous][0], [T_WHITESPACE, T_COMMENT, T_DOC_COMMENT], true)) {
                    $previous--;
                }

                if ($previous >= 0 && is_array($tokens[$previous]) && in_array($tokens[$previous][0], [T_NEW, T_DOUBLE_COLON], true)) {
                    continue;
                }

                for ($cursor = $index + 1; $cursor < $count; $cursor++) {
                    if (is_array($tokens[$cursor]) && $tokens[$cursor][0] === T_STRING) {
                        $declaredClasses[] = ($namespace !== '' ? $namespace.'\\' : '').$tokens[$cursor][1];
                        break;
                    }

                    if ($tokens[$cursor] === '{' || $tokens[$cursor] === ';') {
                        break;
                    }
                }
            }

            foreach ($declaredClasses as $declaredClass) {
                if ($declaredClass !== $expectedClass) {
                    $violations[] = sprintf(
                        '%s : namespace/classe %s, attendu %s',
                        str_replace($applicationRoot.'/', '', $file->getPathname()),
                        $declaredClass,
                        $expectedClass
                    );
                }
            }
        }
    }

    expect($violations)->toBe([]);
});

it('ne contient aucun cycle dans les imports PHP entre Core et domaines', function (): void {
    $applicationRoot = dirname(__DIR__, 2);
    $roots = [
        $applicationRoot.'/app/Core',
        $applicationRoot.'/app/Domains',
    ];

    $classesByFile = [];
    $classToFile = [];

    foreach ($roots as $root) {
        expect(is_dir($root))->toBeTrue();

        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($root, RecursiveDirectoryIterator::SKIP_DOTS)
        );

        foreach ($iterator as $file) {
            if (! $file instanceof SplFileInfo || ! $file->isFile() || $file->getExtension() !== 'php') {
                continue;
            }

            $source = file_get_contents($file->getPathname());
            $tokens = token_get_all($source);
            $namespace = '';
            $imports = [];
            $braceDepth = 0;
            $namespaceBraceDepth = 0;
            $declaredClasses = [];

            for ($index = 0, $count = count($tokens); $index < $count; $index++) {
                $token = $tokens[$index];

                if ($token === '{') {
                    $braceDepth++;
                    continue;
                }

                if ($token === '}') {
                    $braceDepth--;
                    continue;
                }

                if (! is_array($token)) {
                    continue;
                }

                if ($token[0] === T_NAMESPACE) {
                    $namespaceParts = [];

                    for ($cursor = $index + 1; $cursor < $count; $cursor++) {
                        $part = $tokens[$cursor];

                        if ($part === ';' || $part === '{') {
                            if ($part === '{') {
                                $namespaceBraceDepth = $braceDepth + 1;
                            } else {
                                $namespaceBraceDepth = 0;
                            }

                            break;
                        }

                        if (is_array($part) && in_array($part[0], [T_STRING, T_NAME_QUALIFIED, T_NS_SEPARATOR], true)) {
                            $namespaceParts[] = $part[1];
                        }
                    }

                    $namespace = implode('', $namespaceParts);
                    continue;
                }

                if ($token[0] === T_USE && $braceDepth === $namespaceBraceDepth) {
                    $statement = '';

                    for ($cursor = $index + 1; $cursor < $count; $cursor++) {
                        if ($tokens[$cursor] === ';') {
                            break;
                        }

                        $statement .= is_array($tokens[$cursor]) ? $tokens[$cursor][1] : $tokens[$cursor];
                    }

                    $statement = trim($statement);

                    if (str_starts_with($statement, 'function ') || str_starts_with($statement, 'const ')) {
                        continue;
                    }

                    // Les imports groupés sont normalisés en imports individuels.
                    if (preg_match('/^(.+)\\\\{(.+)}$/', $statement, $groupMatch) === 1) {
                        $prefix = rtrim(trim($groupMatch[1]), '\\\\').'\\\\';

                        foreach (explode(',', $groupMatch[2]) as $groupItem) {
                            $imports[] = $prefix.trim($groupItem);
                        }
                    } else {
                        foreach (explode(',', $statement) as $import) {
                            $imports[] = trim($import);
                        }
                    }

                    continue;
                }

                if (in_array($token[0], [T_CLASS, T_INTERFACE, T_TRAIT, T_ENUM], true)) {
                    $previous = $index - 1;
                    while ($previous >= 0 && is_array($tokens[$previous]) && in_array($tokens[$previous][0], [T_WHITESPACE, T_COMMENT, T_DOC_COMMENT], true)) {
                        $previous--;
                    }

                    if ($previous >= 0 && is_array($tokens[$previous]) && in_array($tokens[$previous][0], [T_NEW, T_DOUBLE_COLON], true)) {
                        continue;
                    }

                    for ($cursor = $index + 1; $cursor < $count; $cursor++) {
                        if (is_array($tokens[$cursor]) && $tokens[$cursor][0] === T_STRING) {
                            $declaredClasses[] = ($namespace !== '' ? $namespace.'\\' : '').$tokens[$cursor][1];
                            break;
                        }

                        if ($tokens[$cursor] === '{' || $tokens[$cursor] === ';') {
                            break;
                        }
                    }
                }
            }

            foreach ($declaredClasses as $class) {
                $classesByFile[$file->getPathname()] = [
                    'classes' => $declaredClasses,
                    'imports' => $imports,
                ];
                $classToFile[$class] = $file->getPathname();
            }
        }
    }

    $graph = [];

    foreach ($classesByFile as $file => $definition) {
        foreach ($definition['classes'] as $class) {
            $graph[$class] ??= [];

            foreach ($definition['imports'] as $import) {
                $import = preg_replace('/\\\\s+as\\\\s+.+$/i', '', $import);
                $import = ltrim(trim($import), '\\\\');

                if (isset($classToFile[$import]) && $classToFile[$import] !== $file) {
                    $graph[$class][] = $import;
                }
            }
        }
    }

    $visiting = [];
    $visited = [];
    $cycles = [];

    $visit = function (string $class, array $path = []) use (&$visit, &$visiting, &$visited, &$cycles, $graph): void {
        if (isset($visiting[$class])) {
            $start = array_search($class, $path, true);
            $cycles[] = implode(' -> ', array_slice($path, $start === false ? 0 : $start)).' -> '.$class;

            return;
        }

        if (isset($visited[$class])) {
            return;
        }

        $visiting[$class] = true;
        $path[] = $class;

        foreach ($graph[$class] ?? [] as $dependency) {
            $visit($dependency, $path);
        }

        unset($visiting[$class]);
        $visited[$class] = true;
    };

    foreach (array_keys($graph) as $class) {
        $visit($class);
    }

    expect($cycles)->toBe([]);
});
