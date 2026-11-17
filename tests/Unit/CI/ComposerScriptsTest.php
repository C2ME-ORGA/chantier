<?php

require_once dirname(__DIR__, 3).'/scripts/ci/lib/composer-scripts.php';

test('résout récursivement les scripts Composer imbriqués', function (): void {
    $scripts = [
        'ci:check' => ['@test'],
        'test' => ['@lint:check', '@types:check', '@php artisan test'],
        'lint:check' => ['pint --parallel --test'],
        'types:check' => ['phpstan analyse'],
    ];

    expect(c2me_composer_script_commands($scripts, 'ci:check'))->toBe([
        'pint --parallel --test',
        'phpstan analyse',
        '@php artisan test',
    ]);
});

test('ne résout qu une fois un script partagé par deux chemins', function (): void {
    $scripts = [
        'ci:check' => ['@test', '@audit'],
        'test' => ['@shared', '@php artisan test'],
        'audit' => ['@shared', 'composer audit'],
        'shared' => ['pint --parallel --test'],
    ];

    expect(c2me_composer_script_commands($scripts, 'ci:check'))->toBe([
        'pint --parallel --test',
        '@php artisan test',
        'composer audit',
    ]);
});

test('interrompt une référence circulaire entre scripts', function (): void {
    $scripts = [
        'a' => ['@b', 'commande a'],
        'b' => ['@a', 'commande b'],
    ];

    expect(c2me_composer_script_commands($scripts, 'a'))->toBe([
        'commande b',
        'commande a',
    ]);
});

test('gère une définition de script sous forme de chaîne', function (): void {
    $scripts = [
        'ci:check' => '@test',
        'test' => ['php artisan test'],
    ];

    expect(c2me_composer_script_commands($scripts, 'ci:check'))->toBe([
        'php artisan test',
    ]);
});

test('conserve une référence de script inconnue comme commande', function (): void {
    $scripts = [
        'ci:check' => ['@inconnu'],
    ];

    expect(c2me_composer_script_commands($scripts, 'ci:check'))->toBe([
        '@inconnu',
    ]);
});

test('distingue un script nommé phpstan de l alias php', function (): void {
    $scripts = [
        'ci:check' => ['@phpstan', '@php artisan test'],
        'phpstan' => ['phpstan analyse'],
    ];

    expect(c2me_composer_script_commands($scripts, 'ci:check'))->toBe([
        'phpstan analyse',
        '@php artisan test',
    ]);
});
