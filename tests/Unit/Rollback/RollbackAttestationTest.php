<?php

$root = dirname(__DIR__, 3);
$libPath = $root.'/scripts/ops/lib/rollback-attestation.php';

require_once $libPath;

/**
 * @param  array<string, mixed>  $overrides
 * @return array<string, mixed>
 */
function chan98ValidAttestation(array $overrides = []): array
{
    $attestation = [
        'schema_version' => 1,
        'environment' => 'production',
        'source_release' => 'v0.2.0-2-1',
        'target_release' => 'v0.1.0-1-1',
        'database' => 'chantier_production',
        'checked_at' => gmdate('Y-m-d\TH:i:s\Z'),
        'checked_by' => 'c2me-deploy-production',
        'migrate_status_sha256' => str_repeat('b', 64),
        'migrations' => [
            'in_progress' => false,
            'pending' => false,
            'partial' => false,
            'destructive_applied' => false,
            'contract_applied' => false,
            'compatible_with_target' => true,
        ],
    ];

    return array_replace($attestation, $overrides);
}

/**
 * @return array{environment:string,source:string,target:string,database:string,max_age:int}
 */
function chan98AttestationExpected(): array
{
    return [
        'environment' => 'production',
        'source' => 'v0.2.0-2-1',
        'target' => 'v0.1.0-1-1',
        'database' => 'chantier_production',
        'max_age' => 86400,
    ];
}

test('une attestation valide est acceptée', function (): void {
    expect(rollback_attestation_validate_array(chan98ValidAttestation(), chan98AttestationExpected()))
        ->toBe([]);
});

test('les champs de migration doivent tous être dans l état attendu', function (string $field, bool $value): void {
    $attestation = chan98ValidAttestation();
    $attestation['migrations'][$field] = $value;

    $errors = rollback_attestation_validate_array($attestation, chan98AttestationExpected());

    expect($errors)->not->toBe([]);
})->with([
    ['in_progress', true],
    ['pending', true],
    ['partial', true],
    ['destructive_applied', true],
    ['contract_applied', true],
    ['compatible_with_target', false],
]);

test('un environnement ou une base incohérents sont refusés', function (string $field, string $value): void {
    $attestation = chan98ValidAttestation([$field => $value]);

    $errors = rollback_attestation_validate_array($attestation, chan98AttestationExpected());

    expect($errors)->not->toBe([]);
})->with([
    ['environment', 'staging'],
    ['source_release', 'v9.9.9-9-9'],
    ['target_release', 'v9.9.9-9-9'],
    ['database', 'chantier_staging'],
]);

test('une attestation périmée ou future est refusée', function (string $checkedAt): void {
    $attestation = chan98ValidAttestation(['checked_at' => $checkedAt]);

    $errors = rollback_attestation_validate_array($attestation, chan98AttestationExpected());

    expect($errors)->not->toBe([]);
})->with([
    ['2020-01-01T00:00:00Z'],
    [gmdate('Y-m-d\TH:i:s\Z', time() + 3600)],
]);

test('un horodatage mal formé est refusé', function (): void {
    $attestation = chan98ValidAttestation(['checked_at' => '2026-02-31T10:00:00Z']);

    expect(rollback_attestation_validate_array($attestation, chan98AttestationExpected()))
        ->not->toBe([]);
});

test('les champs obligatoires et les empreintes sont contrôlés', function (string $field, mixed $value): void {
    $attestation = chan98ValidAttestation();

    if ($value === null) {
        unset($attestation[$field]);
    } else {
        $attestation[$field] = $value;
    }

    expect(rollback_attestation_validate_array($attestation, chan98AttestationExpected()))
        ->not->toBe([]);
})->with([
    ['checked_by', ''],
    ['migrate_status_sha256', 'xyz'],
    ['schema_version', 2],
    ['source_release', null],
]);

test('les champs inconnus, secrets et migrations inconnues sont refusés', function (callable $mutator): void {
    $attestation = chan98ValidAttestation();
    $attestation = $mutator($attestation);

    expect(rollback_attestation_validate_array($attestation, chan98AttestationExpected()))
        ->not->toBe([]);
})->with([
    'champ inconnu' => [fn (array $a): array => $a + ['extra' => 'valeur']],
    'secret' => [fn (array $a): array => $a + ['private_key' => 'contenu']],
    'migration inconnue' => [function (array $a): array {
        $a['migrations']['GNU.sparse'] = true;

        return $a;
    }],
]);

test('le validateur de fichier refuse un JSON invalide et un fichier absent', function (): void {
    $directory = sys_get_temp_dir().'/chan98-attestation-'.bin2hex(random_bytes(4));
    mkdir($directory, 0700, true);
    $invalid = $directory.'/invalid.json';
    file_put_contents($invalid, '{');

    expect(rollback_attestation_validate_file($directory.'/absent.json', chan98AttestationExpected()))
        ->toContain('Attestation introuvable : '.$directory.'/absent.json.');

    expect(rollback_attestation_validate_file($invalid, chan98AttestationExpected())[0])
        ->toStartWith('Attestation JSON invalide');

    unlink($invalid);
    rmdir($directory);
});

/**
 * Écrit une attestation et sa preuve migrate:status dans un répertoire neuf.
 *
 * @param  array<string, mixed>  $overrides
 * @param  (callable(string):string)|null  $proofMutator
 * @return array{0:string,1:string,2:string}
 */
function chan98WriteAttestationWithProof(array $overrides = [], ?callable $proofMutator = null): array
{
    $directory = sys_get_temp_dir().'/chan98-proof-'.bin2hex(random_bytes(6));
    mkdir($directory, 0700, true);

    $attestation = chan98ValidAttestation($overrides);
    $proofPath = $directory.'/attestation.json.migrate-status.txt';

    $proof = "C2ME-MIGRATE-STATUS-PROOF\n"
        ."version: 1\n"
        .'environment: '.$attestation['environment']."\n"
        .'release: '.$attestation['source_release']."\n"
        .'database: '.$attestation['database']."\n"
        .'captured_at: '.$attestation['checked_at']."\n"
        ."---\n"
        ." Migration name ......................................... Batch / Status\n"
        ." 0001_01_01_000000_create_users_table ................... [1] Ran\n";

    if ($proofMutator !== null) {
        $proof = $proofMutator($proof);
    }

    file_put_contents($proofPath, $proof);
    chmod($proofPath, 0600);

    if (! array_key_exists('migrate_status_sha256', $overrides)) {
        $attestation['migrate_status_sha256'] = hash('sha256', $proof);
    }
    $attestationPath = $directory.'/attestation.json';
    file_put_contents($attestationPath, json_encode($attestation, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
    chmod($attestationPath, 0600);

    return [$attestationPath, $proofPath, $directory];
}

test('une attestation avec preuve intacte est acceptée', function (): void {
    [$attestationPath, , $directory] = chan98WriteAttestationWithProof();

    expect(rollback_attestation_validate_file($attestationPath, chan98AttestationExpected()))
        ->toBe([]);

    unlink($attestationPath);
    unlink($attestationPath.'.migrate-status.txt');
    rmdir($directory);
});

test('une preuve modifiée, absente ou non régulière invalide l attestation', function (string $mode): void {
    if ($mode === 'modified') {
        [$attestationPath, $proofPath, $directory] = chan98WriteAttestationWithProof();
        file_put_contents($proofPath, 'contenu modifié', FILE_APPEND);
    } elseif ($mode === 'absent') {
        [$attestationPath, $proofPath, $directory] = chan98WriteAttestationWithProof();
        unlink($proofPath);
    } else {
        [$attestationPath, $proofPath, $directory] = chan98WriteAttestationWithProof();
        unlink($proofPath);
        mkdir($proofPath);
    }

    $errors = rollback_attestation_validate_file($attestationPath, chan98AttestationExpected());

    expect($errors)->not->toBe([]);

    @unlink($attestationPath);
    @unlink($proofPath);
    @rmdir($proofPath);
    @rmdir($directory);
})->with(['modified', 'absent', 'directory']);

test('un digest incorrect est refusé', function (): void {
    [$attestationPath, , $directory] = chan98WriteAttestationWithProof([
        'migrate_status_sha256' => str_repeat('c', 64),
    ]);

    $errors = rollback_attestation_validate_file($attestationPath, chan98AttestationExpected());

    expect($errors)->toContain('migrate_status_sha256 ne correspond pas à la preuve conservée.');

    unlink($attestationPath);
    unlink($attestationPath.'.migrate-status.txt');
    rmdir($directory);
});

test('une preuve d un autre environnement ou d une autre release est refusée', function (string $header, string $value, string $expectedMessage): void {
    [$attestationPath, , $directory] = chan98WriteAttestationWithProof([], function (string $proof) use ($header, $value): string {
        return preg_replace('/^'.$header.': .*$/m', $header.': '.$value, $proof) ?? $proof;
    });

    $errors = rollback_attestation_validate_file($attestationPath, chan98AttestationExpected());

    expect($errors)->toContain($expectedMessage);

    unlink($attestationPath);
    unlink($attestationPath.'.migrate-status.txt');
    rmdir($directory);
})->with([
    ['environment', 'staging', 'Preuve migrate:status : environnement incohérent.'],
    ['release', 'v9.9.9-9-9', 'Preuve migrate:status : release incohérente.'],
    ['database', 'chantier_staging', 'Preuve migrate:status : base incohérente.'],
]);

test('une preuve incohérente dans le temps est refusée', function (string $capturedAt, string $expectedMessage): void {
    [$attestationPath, , $directory] = chan98WriteAttestationWithProof([], function (string $proof) use ($capturedAt): string {
        return preg_replace('/^captured_at: .*$/m', 'captured_at: '.$capturedAt, $proof) ?? $proof;
    });

    $errors = rollback_attestation_validate_file($attestationPath, chan98AttestationExpected());

    expect($errors)->toContain($expectedMessage);

    unlink($attestationPath);
    unlink($attestationPath.'.migrate-status.txt');
    rmdir($directory);
})->with([
    [gmdate('Y-m-d\TH:i:s\Z', time() + 3600), 'Preuve migrate:status : captured_at est dans le futur.'],
    ['2020-01-01T00:00:00Z', 'Preuve migrate:status : trop ancienne par rapport à l attestation.'],
]);
