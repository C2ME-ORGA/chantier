<?php

namespace App\Filament\Pages;

use App\Models\User;
use App\Domains\Identity\Models\UserSecurityEvent;
use Filament\Pages\Page;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;

class MySecurityEventsPage extends Page implements HasTable
{
    use InteractsWithTable;

    protected string $view = 'filament.pages.identity.table-page';

    protected static string|\BackedEnum|null $navigationIcon = 'heroicon-o-shield-check';

    protected static ?string $navigationLabel = 'Mon historique de sécurité';

    protected static string|\UnitEnum|null $navigationGroup = 'Sécurité';

    protected static ?int $navigationSort = 91;

    public static function canAccess(): bool
    {
        return Auth::check();
    }

    public function table(Table $table): Table
    {
        $user = Auth::user();

        abort_unless($user instanceof User, 403);

        return $table
            ->query(UserSecurityEvent::query()->where('user_id', $user->getKey()))
            ->columns([
                TextColumn::make('occurred_at')->label('Date')->dateTime('d/m/Y H:i:s')->sortable(),
                TextColumn::make('event')->label('Événement')->searchable()->badge(),
                TextColumn::make('channel')->label('Canal')->badge(),
                TextColumn::make('device.name')->label('Appareil')->placeholder('Non associé'),
                TextColumn::make('ip_address')->label('Adresse IP')->placeholder('Non disponible'),
            ])
            ->defaultSort('occurred_at', 'desc')
            ->paginated([10, 25, 50]);
    }
}
