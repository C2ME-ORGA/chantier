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
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;

class DeviceManagementPage extends Page implements HasTable
{
    use InteractsWithTable;

    protected string $view = 'filament.pages.identity.table-page';

    protected static string|\BackedEnum|null $navigationIcon = 'heroicon-o-computer-desktop';

    protected static ?string $navigationLabel = 'Gestion des appareils';

    protected static ?string $navigationGroup = 'Administration sécurité';

    protected static ?int $navigationSort = 2;

    public static function canAccess(): bool
    {
        return Auth::user()?->can('identity.devices.manage') ?? false;
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(UserDevice::query()->with('user'))
            ->columns([
                TextColumn::make('user.name')->label('Utilisateur')->searchable()->sortable(),
                TextColumn::make('user.email')->label('Adresse e-mail')->searchable()->toggleable(),
                TextColumn::make('name')->label('Appareil')->searchable()->placeholder('Appareil inconnu'),
                TextColumn::make('platform')->label('Plateforme')->placeholder('Non renseignée'),
                TextColumn::make('device_type')->label('Type')->placeholder('Non renseigné'),
                TextColumn::make('last_seen_at')->label('Dernière activité')->dateTime('d/m/Y H:i')->sortable(),
                TextColumn::make('revoked_at')
                    ->label('État')
                    ->badge()
                    ->formatStateUsing(fn ($state): string => $state === null ? 'Actif' : 'Révoqué')
                    ->color(fn ($state): string => $state === null ? 'success' : 'danger'),
            ])
            ->filters([
                SelectFilter::make('user_id')->label('Utilisateur')->relationship('user', 'name')->searchable()->preload(),
                SelectFilter::make('status')
                    ->label('État')
                    ->options(['active' => 'Actif', 'revoked' => 'Révoqué'])
                    ->query(fn ($query, array $data) => match ($data['value'] ?? null) {
                        'active' => $query->whereNull('revoked_at'),
                        'revoked' => $query->whereNotNull('revoked_at'),
                        default => $query,
                    }),
            ])
            ->recordActions([
                Action::make('revoke')
                    ->label('Révoquer')
                    ->icon('heroicon-o-no-symbol')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('Révoquer cet appareil ?')
                    ->modalDescription('Toutes les sessions Web et tous les tokens API associés seront invalidés.')
                    ->visible(fn (UserDevice $record): bool => $record->revoked_at === null)
                    ->action(function (UserDevice $record): void {
                        $actor = Auth::user();

                        abort_unless($actor instanceof User && $actor->can('identity.devices.manage'), 403);

                        app(RevokeUserDevice::class)->handle($actor, $record);
                    })
                    ->successNotificationTitle('Appareil révoqué'),
            ])
            ->defaultSort('last_seen_at', 'desc')
            ->paginated([10, 25, 50, 100]);
    }
}
