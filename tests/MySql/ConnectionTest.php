<?php

use Illuminate\Support\Facades\DB;

test('la suite utilise réellement MySQL 8', function () {
    $version = DB::selectOne('SELECT VERSION() AS version')->version;

    expect(DB::connection()->getDriverName())->toBe('mysql')
        ->and(DB::connection()->getDatabaseName())->toBe('chantier_test_mysql')
        ->and($version)->toMatch('/^8\.0\./');
});
