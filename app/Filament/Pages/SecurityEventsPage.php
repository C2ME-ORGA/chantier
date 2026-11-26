<?php

namespace App\Filament\Pages;

use App\Domains\Identity\Models\UserSecurityEvent;
use Filament\Forms\Components\DatePicker;
use Filament\Pages\Page;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

class SecurityEventsPage extends Page implements HasTable
{
    use InteractsWithTable;

    protected string $view = 'filament.pages.identity.table-page';

    protected static string|\BackedEnum|null $navigationIcon = 'heroicon-o-clipboard-document-list';

    protected static ?string $navigationLabel = 'Journal de sécurité global';

    protected static string|\\UnitEnum|null $navigationGroup = 'Administration sécurité';

    protected static ?int $navigationSort = 1;

    public static function canAccess(): bool
    {
        return Auth::user()?->can('identity.security_events.view') ?? false;
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(UserSecurityEvent::query()->with(['user', 'device']))
            ->columns([
                TextColumn::make('occurred_at')->label('Date')->dateTime('d/m/Y H:i:s')->sortable(),
                TextColumn::make('user.name')->label('Utilisateur')->searchable()->placeholder('Non identifié'),
                TextColumn::make('event')->label('Événement')->searchable()->badge(),
                TextColumn::make('channel')->label('Canal')->badge(),
                TextColumn::make('device.name')->label('Appareil')->placeholder('Non associé'),
                TextColumn::make('ip_address')->label('Adresse IP')->toggleable(),
            ])
            ->filters([
                SelectFilter::make('user_id')->label('Utilisateur')->relationship('user', 'name')->searchable()->preload(),
                SelectFilter::make('user_device_id')->label('Appareil')->relationship('device', 'name')->searchable()->preload(),
                SelectFilter::make('channel')->label('Canal')->options([
                    'web' => 'Web',
                    'api' => 'API',
                    'filament' => 'Filament',
                ]),
                SelectFilter::make('event')->label('Événement')->options([
                    'login.succeeded' => 'Connexion réussie',
                    'login.failed' => 'Échec de connexion',
                    'logout.succeeded' => 'Déconnexion',
                    'mfa.challenge.succeeded' => 'MFA validé',
                    'mfa.challenge.failed' => 'Échec MFA',
                    'device.registered' => 'Appareil enregistré',
                    'device.trusted' => 'Appareil approuvé',
                    'device.revoked' => 'Appareil révoqué',
                    'token.created' => 'Token créé',
                    'token.revoked' => 'Token révoqué',
                    'session.revoked' => 'Session révoquée',
                ]),
                Filter::make('period')
                    ->label('Période')
                    ->schema([
                        DatePicker::make('from')->label('Du'),
                        DatePicker::make('until')->label('Au'),
                    ])
                    ->query(function (Builder $query, array $data): Builder {
                        if (is_string($data['from'] ?? null)) {
                            $query->whereDate('occurred_at', '>=', $data['from']);
                        }

                        if (is_string($data['until'] ?? null)) {
                            $query->whereDate('occurred_at', '<=', $data['until']);
                        }

                        return $query;
                    }),
            ])
            ->defaultSort('occurred_at', 'desc')
            ->paginated([10, 25, 50, 100]);
    }
}
