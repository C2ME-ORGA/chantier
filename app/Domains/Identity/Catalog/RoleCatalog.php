<?php

namespace App\Domains\Identity\Catalog;

/**
 * Référentiel des rôles initiaux CHAN-40.
 *
 * Les codes sont les identifiants stables utilisés par Spatie.
 */
final class RoleCatalog
{
    public const CATALOG_VERSION = '0.1.0';

    /**
     * @return array<string, string>
     */
    public static function all(): array
    {
        return [
            'SA' => 'Super administrateur',
            'DIR' => 'Direction',
            'ADM' => 'Administratif',
            'CT' => 'Conducteur de travaux',
            'CC' => 'Chef de chantier',
            'RA' => 'Responsable atelier',
            'SAL' => 'Salarié',
            'GAF' => 'Gestionnaire administratif et financier opérationnel',
        ];
    }
}
