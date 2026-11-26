<?php

use App\Domains\Identity\Support\AuthenticationChannelResolver;

it('resolves Sanctum and API guards to the API channel', function (): void {
    $resolver = app(AuthenticationChannelResolver::class);

    expect($resolver->resolve('sanctum'))->toBe('api')
        ->and($resolver->resolve('api'))->toBe('api');
});

it('resolves API request paths to the API channel independently of the guard name', function (): void {
    request()->server->set('REQUEST_URI', '/api/integrations/status');

    expect(app(AuthenticationChannelResolver::class)->resolve('web'))->toBe('api');
});

it('defaults non API and non Filament requests to the Web channel', function (): void {
    request()->server->set('REQUEST_URI', '/account/profile');

    expect(app(AuthenticationChannelResolver::class)->resolve('web'))->toBe('web');
});
