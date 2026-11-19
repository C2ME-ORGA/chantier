<?php

use App\Models\User;
use Illuminate\Support\Facades\Schema;

test('applique le schéma des tokens personnels sur MariaDB', function () {
    expect(Schema::hasTable('personal_access_tokens'))->toBeTrue()
        ->and(Schema::hasColumns('personal_access_tokens', [
            'id',
            'tokenable_type',
            'tokenable_id',
            'name',
            'token',
            'abilities',
            'last_used_at',
            'expires_at',
            'created_at',
            'updated_at',
        ]))->toBeTrue();
});

test('authentifie et révoque un token personnel sur MariaDB', function () {
    $user = User::factory()->create();
    $newToken = $user->createToken('mariadb-api-test');

    $this->withToken($newToken->plainTextToken)
        ->getJson('/api/user')
        ->assertOk()
        ->assertJsonPath('email', $user->email);

    $newToken->accessToken->delete();

    // Chaque requête HTTP réelle repart d'un guard vierge ; ces assertions
    // enchaînent plusieurs requêtes dans le même processus de test.
    app('auth')->forgetGuards();

    $this->withToken($newToken->plainTextToken)
        ->getJson('/api/user')
        ->assertUnauthorized();
});
