<?php

namespace App\Filament\Pages;

use App\Domains\Identity\Actions\RevokeUserDevice;
use App\Domains\Identity\Models\UserDevice;
use App\Models\User;
use Filament\Actions\Action;
use Filament\Pages\Page;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

class MyDevicesPage extends Page implements HasTable
{
    use InteractsWithTable;

    protected string $view = 'filament.pages.identity.table-page';

    protected static string|\BackedEnum|null $navigationIcon = 'heroicon-o-device-tablet';

    protected static ?string $navigationLabel = 'Mes appareils';

    protected static ?string $navigationGroup = 'Sécurité';

    protected static ?int $navigationSort = 90;

    public static function canAccess(): bool
    {
        return Auth::check();
    }

    public function table(Table $table): Table
    {
        $user = Auth::user();

        abort_unless($user instanceof User, 403);

        return $table
            ->query(UserDevice::query()->where('user_id', $user->getKey()))
            ->columns([
                TextColumn::make('name')->label('Appareil')->searchable()->placeholder('Appareil inconnu'),
                TextColumn::make('platform')->label('Plateforme')->placeholder('Non renseignée'),
                TextColumn::make('device_type')->label('Type')->placeholder('Non renseigné'),
                TextColumn::make('trusted_at')->label('Enregistré le')->dateTime('d/m/Y H:i')->sortable(),
                TextColumn::make('last_seen_at')->label('Dernière activité')->dateTime('d/m/Y H:i')->sortable(),
                TextColumn::make('revoked_at')
                    ->label('État')
                    ->badge()
                    ->formatStateUsing(fn (?string $state): string => $state === null ? 'Actif' : 'Révoqué')
                    ->color(fn (?string $state): string => $state === null ? 'success' : 'danger'),
            ])
            ->filters([
                Filter::make('active')
                    ->label('Appareils actifs')
                    ->query(fn (Builder $query): Builder => $query->whereNull('revoked_at')),
                Filter::make('revoked')
                    ->label('Appareils révoqués')
                    ->query(fn (Builder $query): Builder => $query->whereNotNull('revoked_at')),
            ])
            ->recordActions([
                Action::make('revoke')
                    ->label('Révoquer')
                    ->icon('heroicon-o-no-symbol')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('Révoquer cet appareil ?')
                    ->modalDescription('Ses sessions Web et ses tokens API associés seront invalidés.')
                    ->visible(fn (UserDevice $record): bool => $record->revoked_at === null)
                    ->action(function (UserDevice $record): void {
                        $actor = Auth::user();

                        abort_unless($actor instanceof User, 403);

                        app(RevokeUserDevice::class)->handle($actor, $record);
                    })
                    ->successNotificationTitle('Appareil révoqué'),
            ])
            ->defaultSort('last_seen_at', 'desc')
            ->paginated([10, 25, 50]);
    }
}
