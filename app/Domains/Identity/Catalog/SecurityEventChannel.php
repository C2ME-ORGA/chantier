<?php

namespace App\Domains\Identity\Catalog;

/**
 * Canonical channels used by the Identity security journal.
 */
final class SecurityEventChannel
{
    public const WEB = 'web';

    public const API = 'api';

    public const FILAMENT = 'filament';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return [
            self::WEB,
            self::API,
            self::FILAMENT,
        ];
    }

    /**
     * @return array<string, string>
     */
    public static function options(): array
    {
        return [
            self::WEB => 'Web',
            self::API => 'API',
            self::FILAMENT => 'Filament',
        ];
    }
}
