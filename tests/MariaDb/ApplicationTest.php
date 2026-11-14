<?php

test('sert la page d accueil avec la connexion MariaDB', function () {
    $this->get('/')->assertOk();
});

test('expose le point de sante avec la connexion MariaDB', function () {
    $this->get('/up')->assertOk();
    $this->getJson('/up')
        ->assertOk()
        ->assertExactJson(['status' => 'up']);
});
