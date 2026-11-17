<?php

it('dispose des racines Core et Domains pour les contrôles d’architecture', function (): void {
    $applicationRoot = dirname(__DIR__, 2);

    expect(is_dir($applicationRoot.'/app/Core'))->toBeTrue()
        ->and(is_dir($applicationRoot.'/app/Domains'))->toBeTrue();
});
