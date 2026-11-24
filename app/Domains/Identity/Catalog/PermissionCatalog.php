<?php

namespace App\Domains\Identity\Catalog;

/**
 * Catalogue initial strict des permissions CHAN-40.
 *
 * Seules les actions et associations explicitement justifiées par la matrice
 * fonctionnelle sont incluses. Les scopes restent gérés par CHAN-42.
 */
final class PermissionCatalog
{
    public const CATALOG_VERSION = '0.1.0';

    /**
     * @return array<string, list<string>>
     */
    public static function all(): array
    {
        return [
            'identity.admin_panel.access' => ['SA', 'DIR', 'ADM', 'CT', 'CC', 'RA', 'GAF'],

            'clients.prospects.view' => ['DIR', 'ADM'],
            'clients.prospects.create' => ['DIR', 'ADM'],
            'clients.prospects.update' => ['DIR', 'ADM'],

            'clients.clients.view' => ['DIR', 'ADM'],
            'clients.clients.create' => ['DIR', 'ADM'],
            'clients.clients.update' => ['DIR', 'ADM'],

            'clients.contacts.view' => ['DIR', 'ADM'],
            'clients.contacts.create' => ['DIR', 'ADM'],
            'clients.contacts.update' => ['DIR', 'ADM'],

            'clients.relations_commerciales.view' => ['DIR', 'ADM'],
            'clients.relations_commerciales.create' => ['DIR', 'ADM'],
            'clients.relations_commerciales.update' => ['DIR', 'ADM'],

            'clients.conditions_commerciales.view' => ['DIR', 'ADM'],
            'clients.conditions_commerciales.create' => ['DIR', 'ADM'],
            'clients.conditions_commerciales.update' => ['DIR', 'ADM'],
            'clients.conditions_commerciales.approve' => ['DIR', 'SA'],

            'clients.devis_commerciaux.view' => ['DIR', 'ADM'],
            'clients.devis_commerciaux.create' => ['DIR', 'ADM'],
            'clients.devis_commerciaux.update' => ['DIR', 'ADM'],
            'clients.devis_commerciaux.submit' => ['DIR', 'ADM'],
            'clients.devis_commerciaux.approve' => ['DIR', 'SA'],

            'clients.factures_clients.view' => ['DIR', 'GAF'],
            'clients.factures_clients.create' => ['DIR', 'GAF'],
            'clients.factures_clients.update' => ['DIR', 'GAF'],
            'clients.factures_clients.issue' => ['DIR', 'GAF'],

            'clients.avoirs.view' => ['DIR', 'GAF'],
            'clients.avoirs.create' => ['DIR', 'GAF'],
            'clients.avoirs.update' => ['DIR', 'GAF'],
            'clients.avoirs.issue' => ['DIR', 'GAF'],

            'clients.relances.view' => ['DIR', 'GAF'],
            'clients.relances.create' => ['DIR', 'GAF'],
            'clients.relances.update' => ['DIR', 'GAF'],

            'clients.echeanciers.view' => ['DIR', 'GAF'],
            'clients.echeanciers.create' => ['DIR', 'GAF'],
            'clients.echeanciers.update' => ['DIR', 'GAF'],

            'clients.litiges_facturation.view' => ['DIR', 'GAF'],
            'clients.litiges_facturation.create' => ['DIR', 'GAF'],
            'clients.litiges_facturation.update' => ['DIR', 'GAF'],
            'clients.litiges_facturation.process' => ['DIR', 'GAF'],
            'clients.litiges_facturation.arbitrate' => ['DIR'],

            'clients.reglements.view' => ['DIR', 'GAF'],
            'clients.reglements.create' => ['DIR'],
            'clients.reglements.update' => ['DIR'],
            'clients.reglements.validate' => ['DIR'],
            'clients.reglements.reconcile' => ['DIR', 'GAF'],
            'clients.reglements.close' => ['DIR'],

            'projects.affaires.view' => ['DIR', 'CT', 'ADM', 'CC', 'GAF'],
            'projects.affaires.create' => ['DIR', 'CT'],
            'projects.affaires.update' => ['DIR', 'CT'],

            'projects.chantiers.view' => ['DIR', 'CT', 'ADM', 'CC', 'GAF'],
            'projects.chantiers.create' => ['DIR', 'CT'],
            'projects.chantiers.update' => ['DIR', 'CT'],

            'projects.etudes.view' => ['DIR', 'CT'],
            'projects.etudes.create' => ['DIR', 'CT'],
            'projects.etudes.update' => ['DIR', 'CT'],

            'projects.jalons.view' => ['DIR', 'CT', 'CC'],
            'projects.jalons.update' => ['DIR', 'CT'],

            'projects.rapports_operationnels.view' => ['DIR', 'CT', 'CC'],
            'projects.rapports_operationnels.create' => ['DIR', 'CT', 'CC'],
            'projects.rapports_operationnels.update' => ['DIR', 'CT', 'CC'],
        ];
    }
}
