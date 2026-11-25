<?php

use App\Filament\Auth\TrackedLogin;
use App\Models\User;
use Filament\Auth\MultiFactor\App\AppAuthentication;
use Filament\Facades\Filament;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;
use Spatie\Permission\Models\Permission;

beforeEach(function () {
    Filament::setCurrentPanel(Filament::getPanel('admin'));

    Permission::findOrCreate('identity.admin_panel.access', 'web');
});

function createUserWithEnabledAppMfa(): User
{
    $user = User::factory()->create([
        'app_authentication_secret' => app(AppAuthentication::class)->generateSecret(),
    ]);

    $user->givePermissionTo('identity.admin_panel.access');

    return $user;
}

test('ne journalise pas un succès et ne suit pas un appareil avant la validation MFA', function () {
    $user = createUserWithEnabledAppMfa();

    Livewire::test(TrackedLogin::class)
        ->set('data.email', $user->email)
        ->set('data.password', 'password')
        ->call('authenticate')
        ->assertHasNoErrors()
        ->assertSet('userUndertakingMultiFactorAuthentication', fn ($value): bool => filled($value));

    expect(auth('web')->check())->toBeFalse()
        ->and($user->fresh()->securityEvents()->where('event', 'authentication.succeeded')->count())->toBe(0)
        ->and($user->fresh()->devices()->count())->toBe(0);
});

test('journalise un échec MFA sur le compte concerné sans authentifier ni enregistrer un appareil', function () {
    $user = createUserWithEnabledAppMfa();

    $component = Livewire::test(TrackedLogin::class)
        ->set('data.email', $user->email)
        ->set('data.password', 'password')
        ->call('authenticate')
        ->assertHasNoErrors();

    $component
        ->set('data.multiFactor.app.code', 'invalid-code')
        ->call('authenticate')
        ->assertHasErrors();

    expect(auth('web')->check())->toBeFalse()
        ->and($user->fresh()->securityEvents()->where('event', 'mfa.failed')->count())->toBe(1)
        ->and($user->fresh()->securityEvents()->where('event', 'authentication.succeeded')->count())->toBe(0)
        ->and($user->fresh()->devices()->count())->toBe(0);
});

test('journalise le succès uniquement après validation du code MFA', function () {
    $user = createUserWithEnabledAppMfa();

    $component = Livewire::test(TrackedLogin::class)
        ->set('data.email', $user->email)
        ->set('data.password', 'password')
        ->call('authenticate')
        ->assertHasNoErrors();

    $code = AppAuthentication::make()->getCurrentCode($user);

    $component
        ->set('data.multiFactor.app.code', $code)
        ->call('authenticate')
        ->assertHasNoErrors();

    expect(auth('web')->check())->toBeTrue()
        ->and($user->fresh()->securityEvents()->where('event', 'authentication.succeeded')->count())->toBe(1)
        ->and($user->fresh()->securityEvents()->where('event', 'mfa.failed')->count())->toBe(0);
});
