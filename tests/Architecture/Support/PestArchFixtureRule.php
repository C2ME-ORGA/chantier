<?php

namespace Tests\Architecture\Support;

use Pest\Arch\Repositories\ObjectsRepository;
use PHPUnit\Framework\ExpectationFailedException;
use ReflectionProperty;
use RuntimeException;

/**
 * Runs the real Pest Arch "not toUse" rule against an isolated fixture tree.
 *
 * Pest Arch normally reads the Composer PSR-4 prefixes of the application. The
 * object repository is temporarily replaced so the same rule implementation is
 * evaluated against the fixture namespace instead of the application code.
 */
final class PestArchFixtureRule
{
    /**
     * @param  list<string>  $ignoring
     */
    public static function assertAllows(
        string $fixtureRoot,
        string $fixtureNamespace,
        string $target,
        string $dependency,
        array $ignoring = [],
    ): void {
        self::evaluate($fixtureRoot, $fixtureNamespace, $target, $dependency, $ignoring);
    }

    /**
     * @param  list<string>  $ignoring
     * @return string the violation message
     */
    public static function assertRejects(
        string $fixtureRoot,
        string $fixtureNamespace,
        string $target,
        string $dependency,
        array $ignoring = [],
    ): string {
        try {
            self::evaluate($fixtureRoot, $fixtureNamespace, $target, $dependency, $ignoring);
        } catch (ExpectationFailedException $exception) {
            return $exception->getMessage();
        }

        throw new RuntimeException("Expected {$target} to use {$dependency}.");
    }

    /**
     * @param  list<string>  $ignoring
     */
    private static function evaluate(
        string $fixtureRoot,
        string $fixtureNamespace,
        string $target,
        string $dependency,
        array $ignoring,
    ): void {
        $repository = new ReflectionProperty(ObjectsRepository::class, 'instance');
        $previous = $repository->getValue();
        $repository->setValue(null, new ObjectsRepository([$fixtureNamespace => [$fixtureRoot]]));

        try {
            // The trailing expectation forces Pest Arch to evaluate its lazy assertion.
            expect($target)
                ->not
                ->toUse($dependency)
                ->ignoring($ignoring)
                ->toBeString();
        } finally {
            $repository->setValue(null, $previous);
        }
    }
}
