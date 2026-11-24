# Authentification du panel Filament

Le panel d'administration C2ME Chantier utilise les pages d'authentification natives de Filament. Aucun parcours Web d'authentification parallèle ne doit être développé tant que l'interface applicative reste portée par ce panel.

## Configuration

La configuration est centralisée dans `app/Providers/Filament/AdminPanelProvider.php` :

- `login()` active la page native de connexion ;
- `passwordReset()` active la demande et la saisie du nouveau mot de passe ;
- `authGuard('web')` utilise le guard Laravel de session ;
- `authPasswordBroker('users')` utilise le broker Laravel des utilisateurs.

L'inscription n'est pas activée. Ne pas ajouter `registration()` sans décision fonctionnelle distincte.

## Autorisation d'accès au panel

Le modèle `App\Models\User` implémente `FilamentUser`. Sa méthode `canAccessPanel()` vérifie la permission Spatie `identity.admin_panel.access`.

Un mot de passe valide ne suffit donc pas à ouvrir le panel : l'utilisateur doit également posséder la permission d'accès prévue par le catalogue RBAC CHAN-40. Ne pas élargir cette permission ni attribuer automatiquement un rôle dans le parcours de connexion.

## Réinitialisation du mot de passe

Filament utilise le broker `users` déclaré dans `config/auth.php`, lequel utilise la table `password_reset_tokens`. Les paramètres actuels sont :

- durée de validité d'un jeton : 60 minutes ;
- temporisation entre les demandes : 60 secondes.

Les pages Filament contrôlent également l'accès au panel avant l'envoi et la validation d'une réinitialisation. Le mot de passe est enregistré sous forme hachée et le jeton est consommé par le broker Laravel.

## Configuration e-mail

Chaque environnement doit fournir sa configuration mail via ses variables d'environnement (par exemple `MAIL_MAILER`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_ENCRYPTION`, `MAIL_FROM_ADDRESS` et `MAIL_FROM_NAME`, selon le transport retenu).

Les valeurs et secrets réels ne doivent jamais être ajoutés au dépôt. Utiliser un transport de test ou un faux transport dans les tests automatisés ; ne pas dépendre d'un serveur SMTP réel pour valider le parcours.

## Vérifications

Exécuter les tests ciblés :

```bash
php artisan test tests/Feature/Filament/AdminPanelAuthenticationTest.php
php artisan test tests/Feature/Filament/AdminPanelTest.php
php artisan test tests/Feature/Authentication/SanctumTest.php
```

Puis exécuter les contrôles complets définis par le dépôt :

```bash
composer ci:check --no-interaction
```

La configuration mail de l'environnement réel doit être testée séparément avant mise en service.
