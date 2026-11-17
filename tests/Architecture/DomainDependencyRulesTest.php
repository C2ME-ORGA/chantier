<?php

it('interdit au Core toute dépendance vers les domaines métier', function (): void {
    expect('App\\Core')
        ->not
        ->toUse('App\\Domains');
});

it('limite les dépendances inter-domaines aux surfaces publiques CHAN-28', function (): void {
    $domains = [
        'Budgets',
        'Clients',
        'Costing',
        'Documents',
        'Equipment',
        'Handover',
        'Identity',
        'Inventory',
        'Logistics',
        'Planning',
        'Procurement',
        'Projects',
        'Quality',
        'Reporting',
        'Safety',
        'TimeTracking',
        'Workforce',
        'Workshop',
    ];

    foreach ($domains as $consumer) {
        foreach ($domains as $provider) {
            if ($consumer === $provider) {
                continue;
            }

            $providerNamespace = "App\\Domains\\{$provider}";

            expect("App\\Domains\\{$consumer}")
                ->not
                ->toUse($providerNamespace)
                ->ignoring([
                    "{$providerNamespace}\\Contracts",
                    "{$providerNamespace}\\Events\\Integration",
                ]);
        }
    }
});
