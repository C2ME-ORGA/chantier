<?php

namespace App\Domains\Identity\Console\Commands;

use App\Domains\Identity\Models\UserDevice;
use App\Domains\Identity\Models\UserSecurityEvent;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;

final class PurgeSecurityEvents extends Command
{
    protected $signature = 'identity:purge-security-events
        {--execute : Effectuer réellement la suppression (sans cette option, simulation uniquement)}
        {--chunk=500 : Nombre maximal de lignes traitées par lot}';

    protected $description = 'Purge les événements de sécurité et les appareils révoqués au-delà de leur durée de conservation.';

    public function handle(): int
    {
        $chunkSize = filter_var($this->option('chunk'), FILTER_VALIDATE_INT);

        if ($chunkSize === false || $chunkSize < 1 || $chunkSize > 10000) {
            throw new InvalidArgumentException('L’option --chunk doit être comprise entre 1 et 10000.');
        }

        $cutoff = now()->subMonths(12);
        $events = UserSecurityEvent::query()
            ->where('occurred_at', '<', $cutoff)
            ->whereNull('preserved_at');
        $devices = UserDevice::query()
            ->whereNotNull('revoked_at')
            ->where('revoked_at', '<', $cutoff);

        $eventCount = (clone $events)->count();
        $deviceCount = (clone $devices)->count();

        if (! $this->option('execute')) {
            $this->components->info('Simulation uniquement : aucune donnée supprimée.');
            $this->line("Événements éligibles : {$eventCount}");
            $this->line("Appareils révoqués éligibles : {$deviceCount}");
            $this->line('Date limite : '.$cutoff->toDateTimeString());

            return self::SUCCESS;
        }

        $deletedEvents = $this->deleteInChunks($events, $chunkSize);
        $deletedDevices = $this->deleteInChunks($devices, $chunkSize);

        $this->components->info('Purge terminée.');
        $this->line("Événements supprimés : {$deletedEvents}");
        $this->line("Appareils révoqués supprimés : {$deletedDevices}");
        $this->line('Date limite : '.$cutoff->toDateTimeString());

        return self::SUCCESS;
    }

    /**
     * Bulk deletion deliberately bypasses the append-only Eloquent model hooks.
     * Foreign keys preserve surviving event rows by nulling their device link.
     *
     * @param  Builder<UserSecurityEvent|UserDevice>  $query
     */
    private function deleteInChunks(Builder $query, int $chunkSize): int
    {
        $deleted = 0;

        $query->select('id')->chunkById($chunkSize, function ($records) use ($query, &$deleted): void {
            $ids = $records->modelKeys();

            $deleted += (clone $query)->whereKey($ids)->toBase()->delete();
        });

        return $deleted;
    }
}
