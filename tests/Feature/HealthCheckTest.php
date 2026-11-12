<?php

test('expose un point de santé accessible sans authentification', function () {
    $this->get('/up')->assertOk();
});

test('retourne un statut JSON exploitable par les contrôles de déploiement', function () {
    $this->getJson('/up')
        ->assertOk()
        ->assertExactJson(['status' => 'up']);
});
