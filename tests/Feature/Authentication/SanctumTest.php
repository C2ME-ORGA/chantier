<?php

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

test('crée un token personnel pour un utilisateur', function () {
    $user = User::factory()->create();

    $token = $user->createToken('api-test');
    [, $plainTextToken] = explode('|', $token->plainTextToken, 2);

    expect($token->plainTextToken)->toBeString()->not->toBeEmpty()
        ->and($token->accessToken->name)->toBe('api-test')
        ->and($token->accessToken->tokenable_id)->toBe($user->getKey())
        ->and($token->accessToken->token)->toBe(hash('sha256', $plainTextToken));

    $this->assertDatabaseHas('personal_access_tokens', [
        'tokenable_type' => User::class,
        'tokenable_id' => $user->getKey(),
        'name' => 'api-test',
    ]);
});

test('authentifie une requête avec un Bearer Token valide', function () {
    $user = User::factory()->create();
    $plainTextToken = $user->createToken('api-test')->plainTextToken;

    $this->withToken($plainTextToken)
        ->getJson('/api/user')
        ->assertOk()
        ->assertJsonPath('id', $user->getKey())
        ->assertJsonPath('email', $user->email)
        ->assertJsonMissingPath('password');
});

test('refuse un Bearer Token invalide', function () {
    $this->withToken('token-invalide')
        ->getJson('/api/user')
        ->assertUnauthorized();
});

test('révoque un token sans affecter les autres tokens de l utilisateur', function () {
    $user = User::factory()->create();
    $revokedToken = $user->createToken('api-test-revoque');
    $activeToken = $user->createToken('api-test-actif');

    $this->withToken($revokedToken->plainTextToken)
        ->getJson('/api/user')
        ->assertOk();

    $revokedToken->accessToken->delete();

    $this->assertDatabaseMissing('personal_access_tokens', [
        'id' => $revokedToken->accessToken->getKey(),
    ]);

    // Chaque requête HTTP réelle repart d'un guard vierge ; ces assertions
    // enchaînent plusieurs requêtes dans le même processus de test.
    app('auth')->forgetGuards();

    $this->withToken($revokedToken->plainTextToken)
        ->getJson('/api/user')
        ->assertUnauthorized();

    app('auth')->forgetGuards();

    $this->withToken($activeToken->plainTextToken)
        ->getJson('/api/user')
        ->assertOk();
});

test('expire un token après 30 jours', function () {
    expect(config('sanctum.expiration'))->toBe(60 * 24 * 30);

    $user = User::factory()->create();
    $plainTextToken = $user->createToken('api-test')->plainTextToken;

    $this->travel(29)->days();

    $this->withToken($plainTextToken)
        ->getJson('/api/user')
        ->assertOk();

    $this->travel(2)->days();

    app('auth')->forgetGuards();

    $this->withToken($plainTextToken)
        ->getJson('/api/user')
        ->assertUnauthorized();
});

test('refuse l accès anonyme aux routes protégées par Sanctum', function () {
    $this->getJson('/api/user')->assertUnauthorized();
});

test('conserve les rôles et permissions Spatie pour un utilisateur authentifié par token', function () {
    $permission = Permission::create(['name' => 'chantiers.consulter']);
    $role = Role::create(['name' => 'conducteur']);
    $role->givePermissionTo($permission);

    $user = User::factory()->create();
    $user->assignRole($role);
    $plainTextToken = $user->createToken('api-test')->plainTextToken;

    Route::middleware('auth:sanctum')->get('/api/permission-check', function (Request $request) {
        return response()->json([
            'has_role' => $request->user()->hasRole('conducteur'),
            'has_permission' => $request->user()->hasPermissionTo('chantiers.consulter'),
        ]);
    });

    $this->withToken($plainTextToken)
        ->getJson('/api/permission-check')
        ->assertOk()
        ->assertJson([
            'has_role' => true,
            'has_permission' => true,
        ]);
});
