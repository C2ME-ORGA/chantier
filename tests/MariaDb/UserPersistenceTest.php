<?php

use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

test('réalise les opérations CRUD sur le modèle User', function () {
    $user = User::factory()->create([
        'name' => 'Alice Chantier',
        'email' => 'alice@example.test',
    ]);

    expect($user->id)->toBeGreaterThan(0)
        ->and($user->exists)->toBeTrue()
        ->and($user->created_at)->not->toBeNull()
        ->and($user->updated_at)->not->toBeNull();

    $found = User::query()->findOrFail($user->id);

    expect($found->email)->toBe('alice@example.test');

    $found->update(['name' => 'Alice C2ME']);

    expect($found->fresh()->name)->toBe('Alice C2ME');

    $found->delete();

    expect(User::query()->find($user->id))->toBeNull();
});

test('chiffre le mot de passe et masque les attributs sensibles', function () {
    $user = User::factory()->create([
        'email' => 'hash@example.test',
        'password' => 'secret-password',
    ]);

    expect($user->password)->not->toBe('secret-password')
        ->and(Hash::check('secret-password', $user->password))->toBeTrue()
        ->and($user->getHidden())->toContain('password', 'remember_token')
        ->and($user->toArray())->not->toHaveKey('password');
});

test('accepte les colonnes nullables et renseigne les timestamps', function () {
    $user = User::factory()->unverified()->create([
        'email' => 'nullable@example.test',
        'remember_token' => null,
    ]);

    expect($user->email_verified_at)->toBeNull()
        ->and($user->remember_token)->toBeNull()
        ->and($user->created_at)->not->toBeNull()
        ->and($user->updated_at)->not->toBeNull();
});

test('refuse une valeur nulle dans une colonne obligatoire', function () {
    $this->expectException(QueryException::class);

    DB::table('users')->insert([
        'name' => null,
        'email' => 'null-name@example.test',
        'password' => 'not-hashed',
    ]);
});

test('applique l unicité de l email', function () {
    User::factory()->create(['email' => 'unique@example.test']);

    $this->expectException(QueryException::class);

    User::factory()->create(['email' => 'unique@example.test']);
});

test('applique une unicité insensible à la casse sur email', function () {
    User::factory()->create(['email' => 'case@example.test']);

    $this->expectException(QueryException::class);

    User::factory()->create(['email' => 'CASE@example.test']);
});

test('annule une transaction interrompue', function () {
    $email = 'rollback@example.test';

    expect(function () use ($email): void {
        DB::transaction(function () use ($email): void {
            User::factory()->create(['email' => $email]);

            throw new RuntimeException('rollback attendu');
        });
    })->toThrow(RuntimeException::class, 'rollback attendu');

    expect(User::query()->where('email', $email)->exists())->toBeFalse();
});
