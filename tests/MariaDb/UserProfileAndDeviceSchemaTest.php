<?php

use App\Domains\Identity\Models\UserDevice;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Schema;

test('applique le schéma des profils utilisateurs et appareils sur MariaDB', function () {
    expect(Schema::hasColumns('user_profiles', [
        'id',
        'user_id',
        'first_name',
        'last_name',
        'phone',
        'job_title',
        'avatar_path',
        'created_at',
        'updated_at',
    ]))->toBeTrue()
        ->and(Schema::hasColumns('user_devices', [
            'id',
            'user_id',
            'uuid',
            'name',
            'platform',
            'device_type',
            'last_seen_at',
            'trusted_at',
            'revoked_at',
            'created_at',
            'updated_at',
        ]))->toBeTrue();
});

test('applique les contraintes uniques et les relations sur MariaDB', function () {
    $user = User::factory()->create();
    $user->profile()->create(['first_name' => 'Camille']);

    expect($user->fresh()->profile->first_name)->toBe('Camille');

    $attributes = ['uuid' => '550e8400-e29b-41d4-a716-446655440003'];
    $user->devices()->create($attributes);

    expect(fn () => $user->devices()->create($attributes))
        ->toThrow(QueryException::class);

    expect(UserDevice::query()->where('user_id', $user->id)->count())->toBe(1);
});
