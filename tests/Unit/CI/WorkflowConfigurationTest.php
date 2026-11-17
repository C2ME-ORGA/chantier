<?php

require_once dirname(__DIR__, 3).'/scripts/ci/lib/workflow-configuration.php';

test('retourne les événements configurés indépendamment de leur ordre', function (): void {
    $trigger = [
        'push' => ['branches' => ['main', 'develop']],
        'pull_request' => ['branches' => ['main', 'develop']],
    ];

    expect(c2me_workflow_event_names($trigger))->toBe(['pull_request', 'push']);
});

test('signale un événement supplémentaire sans le masquer', function (): void {
    $trigger = [
        'push' => [],
        'pull_request' => [],
        'workflow_dispatch' => [],
    ];

    expect(c2me_workflow_event_names($trigger))->toBe(['pull_request', 'push', 'workflow_dispatch']);
});

test('accepte la forme liste des événements', function (): void {
    expect(c2me_workflow_event_names(['pull_request', 'push']))->toBe(['pull_request', 'push']);
});

test('refuse un nom d événement non textuel', function (): void {
    expect(c2me_workflow_event_names([42]))->toBeNull();
});

test('retourne les branches dans leur ordre de déclaration', function (): void {
    $trigger = [
        'push' => ['branches' => ['develop', 'main']],
        'pull_request' => ['branches' => ['main', 'develop']],
    ];

    expect(c2me_workflow_trigger_branches($trigger, 'push'))->toBe(['develop', 'main'])
        ->and(c2me_workflow_trigger_branches($trigger, 'pull_request'))->toBe(['main', 'develop']);
});

test('accepte une branche unique sous forme de chaîne', function (): void {
    $trigger = ['push' => ['branches' => 'develop']];

    expect(c2me_workflow_trigger_branches($trigger, 'push'))->toBe(['develop']);
});

test('refuse une entrée de branche non textuelle', function (): void {
    $trigger = ['push' => ['branches' => ['develop', 42]]];

    expect(c2me_workflow_trigger_branches($trigger, 'push'))->toBeNull();
});

test('refuse une configuration de branches non tabulaire', function (): void {
    $trigger = ['push' => ['branches' => 42]];

    expect(c2me_workflow_trigger_branches($trigger, 'push'))->toBeNull();
});

test('refuse une configuration d événement non tabulaire', function (): void {
    $trigger = ['push' => 'develop'];

    expect(c2me_workflow_trigger_branches($trigger, 'push'))->toBeNull();
});

test('distingue un événement absent d un événement sans filtre', function (): void {
    expect(c2me_workflow_trigger_branches([], 'push'))->toBeNull()
        ->and(c2me_workflow_trigger_branches(['push' => null], 'push'))->toBe([]);
});

test('distingue une clé branches absente d une clé définie à null', function (): void {
    expect(c2me_workflow_trigger_branches(['push' => []], 'push'))->toBe([])
        ->and(c2me_workflow_trigger_branches(['push' => ['branches' => null]], 'push'))->toBeNull();
});
