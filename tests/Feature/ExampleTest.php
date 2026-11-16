<?php

test('la route nommée home affiche la vue d accueil', function () {
    $this->get(route('home'))
        ->assertOk()
        ->assertViewIs('welcome');
});
