<?php

namespace Tests\Architecture\Support;

use FilesystemIterator;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use RuntimeException;
use SplFileInfo;
use Throwable;

/**
 * Creates an isolated temporary PHP fixture tree outside the application.
 *
 * Files may contain the __FIXTURE_NAMESPACE__ placeholder, replaced by a
 * unique namespace for the fixture. The fixture must be closed in a finally
 * block so its directory and autoloader never leak into another test.
 */
final class ArchitectureFixture
{
    private bool $closed = false;

    /**
     * @param  \Closure(string): void  $autoloader
     */
    private function __construct(
        public readonly string $root,
        public readonly string $namespace,
        private readonly \Closure $autoloader,
    ) {}

    /**
     * @param  array<string, string>  $files  relative path => PHP source
     */
    public static function create(array $files): self
    {
        $root = sys_get_temp_dir().DIRECTORY_SEPARATOR.'c2me-chan31-'.bin2hex(random_bytes(8));
        $namespace = 'Chan31Fixture'.bin2hex(random_bytes(8));
        $created = false;

        $autoloader = static function (string $class) use ($root, $namespace): void {
            $prefix = $namespace.'\\';

            if (! str_starts_with($class, $prefix)) {
                return;
            }

            $relative = str_replace('\\', DIRECTORY_SEPARATOR, substr($class, strlen($prefix)));
            $path = $root.DIRECTORY_SEPARATOR.$relative.'.php';

            if (is_file($path)) {
                require $path;
            }
        };

        try {
            if (! mkdir($root, 0777, true) && ! is_dir($root)) {
                throw new RuntimeException("Unable to create fixture directory: {$root}");
            }

            $created = true;

            foreach ($files as $relativePath => $contents) {
                $path = $root.DIRECTORY_SEPARATOR.ltrim(str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $relativePath), DIRECTORY_SEPARATOR);

                if (! is_dir(dirname($path)) && ! mkdir(dirname($path), 0777, true) && ! is_dir(dirname($path))) {
                    throw new RuntimeException('Unable to create fixture directory: '.dirname($path));
                }

                $contents = str_replace('__FIXTURE_NAMESPACE__', $namespace, $contents);

                if (file_put_contents($path, $contents) === false) {
                    throw new RuntimeException("Unable to write fixture file: {$path}");
                }
            }

            spl_autoload_register($autoloader);
        } catch (Throwable $exception) {
            if ($created) {
                self::deleteDirectory($root);
            }

            throw $exception;
        }

        return new self($root, $namespace, $autoloader);
    }

    public function close(): void
    {
        if ($this->closed) {
            return;
        }

        $this->closed = true;
        spl_autoload_unregister($this->autoloader);
        self::deleteDirectory($this->root);
    }

    private static function deleteDirectory(string $root): void
    {
        if (! is_dir($root)) {
            return;
        }

        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST,
        );

        foreach ($iterator as $item) {
            if (! $item instanceof SplFileInfo) {
                continue;
            }

            $item->isDir() ? @rmdir($item->getPathname()) : @unlink($item->getPathname());
        }

        @rmdir($root);
    }
}
