# Rôles et permissions

Ce document décrit le socle global de rôles et permissions installé dans le cadre de **CHAN-38**.

- Package : [`spatie/laravel-permission`](https://spatie.be/docs/laravel-permission).
- Version verrouillée : `8.5.0` (contrainte Composer `^8.5`).
- Ticket : CHAN-38 — Installer et configurer Spatie Laravel Permission.
- Périmètre : installation, configuration, modèle `User`, migrations, cache et tests du package.
- Hors périmètre : rôles et permissions métier (CHAN-40), Policies et restrictions d'accès aux chantiers (CHAN-42), authentification (CHAN-39 et CHAN-43), MFA (CHAN-44), journalisation de sécurité (CHAN-45) et matrice complète d'autorisation (CHAN-46).

## Installation

Le package est une dépendance Composer du projet :

```powershell
composer require "spatie/laravel-permission:^8.5"
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag=permission-config
php artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag=permission-migrations
```

Les fichiers publiés sont :

- `config/permission.php` ;
- `database/migrations/2026_11_18_161315_create_permission_tables.php`.

La configuration et la migration sont versionnées. Ne pas publier une seconde fois ces fichiers sans vérifier leur contenu et leur historique.

## Configuration

La configuration conserve les modèles et tables standard du package :

| Élément | Valeur |
| --- | --- |
| Modèle des permissions | `Spatie\Permission\Models\Permission` |
| Modèle des rôles | `Spatie\Permission\Models\Role` |
| Table des permissions | `permissions` |
| Table des rôles | `roles` |
| Table des permissions directes | `model_has_permissions` |
| Table des rôles attribués | `model_has_roles` |
| Table des permissions par rôle | `role_has_permissions` |
| Clé de modèle | `model_id` |
| Clés pivots | `role_id`, `permission_id` |

Ces noms restent ceux du package afin d'éviter une personnalisation inutile.

### Guard `web`

Le projet utilise le guard `web` comme guard par défaut :

- `config/auth.php` déclare `web` avec le provider `users` et le modèle `App\Models\User` ;
- `config/auth.php` définit `auth.defaults.guard` sur `web` ;
- Spatie résout le guard par défaut à partir de cette configuration ;
- les rôles et permissions créés sans guard explicite utilisent donc `web`.

Le guard `web` est vérifié par les tests du socle. Ne pas créer de rôle ou de permission avec un guard différent sans décision documentée.

### Teams désactivé

`config/permission.php` conserve :

```php
'teams' => false,
```

La décision est volontaire : les rôles et permissions sont **globaux à l'application**. Les chantiers ne sont pas des équipes Spatie et ne doivent pas être représentés par le mécanisme Teams.

Conséquences :

- aucune colonne `team_id` dans `roles`, `model_has_roles` ou `model_has_permissions` ;
- aucun `team_id` n'est requis lors de l'attribution d'un rôle ou d'une permission ;
- les restrictions propres à un chantier relèvent des Policies Laravel de CHAN-42, pas de Spatie Teams.

### Cache

La configuration conserve le cache standard du package :

- durée : 24 heures ;
- clé : `spatie.permission.cache` ;
- store : `default`, c'est-à-dire le store de cache configuré par l'application.

Le cache est invalidé automatiquement lors de la création, de la modification ou de la suppression d'un rôle ou d'une permission via Eloquent. Une modification directe en SQL ne passe pas par les événements Eloquent du package et ne déclenche pas nécessairement cette invalidation ; après une insertion, une mise à jour ou une suppression directe dans les tables Spatie, exécuter :

```powershell
php artisan permission:cache-reset
```

## Modèle User

`App\Models\User` utilise désormais :

```php
use Spatie\Permission\Traits\HasRoles;
```

Le trait est ajouté sans retirer les fonctionnalités existantes :

- `Authenticatable` ;
- `HasFactory` ;
- `Notifiable` ;
- `FilamentUser` et `canAccessPanel()`.

`canAccessPanel()` reste temporairement ouvert à tous les utilisateurs authentifiés. Le contrôle d'accès Filament n'est pas modifié dans CHAN-38 ; il sera traité avec les autorisations métier.

## Rôles et permissions globaux

Le socle permet de :

- créer des permissions ;
- créer des rôles ;
- attribuer un rôle à un utilisateur ;
- accorder une permission directement à un utilisateur ;
- vérifier une permission héritée d'un rôle ;
- vérifier l'absence d'un droit ;
- contrôler le guard `web` et refuser un guard incompatible ;
- supprimer les relations lorsqu'un rôle est supprimé ;
- invalider le cache lors des changements.

Aucun rôle métier n'est créé dans CHAN-38. Les rôles et permissions métier seront définis dans CHAN-40.

## Séparation avec les autorisations par chantier

Le socle global répond à la question « cet utilisateur possède-t-il cette permission ? ». Il ne décide pas si un utilisateur peut agir sur un chantier précis.

La séparation est la suivante :

| Niveau | Mécanisme | Ticket |
| --- | --- | --- |
| Permission globale | Rôle ou permission Spatie | CHAN-38, puis CHAN-40 |
| Autorisation sur une ressource | Policy Laravel et vérification serveur | CHAN-42 |
| Authentification | Guard `web`, connexion et session | CHAN-43 |

Une permission globale ne remplace jamais une Policy. Une Policy ne doit pas être contournée par une attribution directe en base.

## Migrations

La migration crée les cinq tables du package. Elle est additive et ne modifie aucune table existante. Elle s'applique avec la procédure habituelle (`php artisan migrate`) sur l'environnement ciblé ; ne pas utiliser `migrate:fresh` hors d'une base explicitement isolée.

Elle porte les annotations de politique de migration du projet :

```php
/**
 * @phase expand
 *
 * @ticket CHAN-38
 */
```

Les tables sont vérifiées sur SQLite par la suite Feature et sur MariaDB 10.11 par la suite `tests/MariaDb`. La politique générale est décrite dans [`database-migrations.md`](database-migrations.md).

## Tests et contrôles

Les tests dédiés sont :

- `tests/Feature/Authorization/SpatiePermissionTest.php` pour le comportement sur SQLite ;
- `tests/MariaDb/SpatiePermissionTest.php` pour le schéma et le comportement sur MariaDB 10.11.

Commandes utiles :

```powershell
php artisan test tests/Feature/Authorization/SpatiePermissionTest.php
vendor/bin/pest --configuration=phpunit.mariadb.xml
composer lint:check
composer types:check
```

La suite MariaDB nécessite une base isolée `chantier_test` déjà migrée. Ne jamais exécuter `migrate:fresh` sur une base non explicitement isolée.

## Hors périmètre CHAN-38

Ne pas considérer comme implémentés dans ce ticket :

- les rôles et permissions métier (CHAN-40) ;
- les profils utilisateurs et appareils (CHAN-41) ;
- les Policies et middleware des chantiers (CHAN-42) ;
- Sanctum (CHAN-39) ;
- la connexion et la réinitialisation du mot de passe (CHAN-43) ;
- le MFA (CHAN-44) ;
- la journalisation des événements de sécurité (CHAN-45) ;
- la matrice complète des tests d'autorisation (CHAN-46).

## Références

- [`AGENTS.md`](../../AGENTS.md)
- [`README.md`](../../README.md)
- [`config/permission.php`](../../config/permission.php)
- [`config/auth.php`](../../config/auth.php)
- [`app/Models/User.php`](../../app/Models/User.php)
- [`database/migrations/2026_11_18_161315_create_permission_tables.php`](../../database/migrations/2026_11_18_161315_create_permission_tables.php)
- [`docs/development/testing.md`](testing.md)
- [`docs/development/database-migrations.md`](database-migrations.md)
- [Documentation Spatie Laravel Permission](https://spatie.be/docs/laravel-permission)
