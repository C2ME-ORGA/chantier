# Authentification API par tokens Sanctum

Ce document décrit l'authentification des routes API de **C2ME Chantier** par tokens personnels Laravel Sanctum, installée dans le cadre de **CHAN-39**.

- Package : [`laravel/sanctum`](https://laravel.com/docs/sanctum).
- Version verrouillée : `4.5.0` (contrainte Composer `^4.0`).
- Ticket : CHAN-39 — Implémentation Laravel Sanctum.
- Périmètre : installation du package, modèle `User`, route API, migration `personal_access_tokens`, expiration des tokens, révocation et tests.
- Hors périmètre : API métier, connexion et déconnexion utilisateur (CHAN-43), rôles et permissions métier (CHAN-40), Policies et middleware d'accès aux chantiers (CHAN-42) et authentification SPA par cookies.

## Installation

Le package est une dépendance Composer du projet. L'installation a été réalisée avec le scaffolding Laravel :

```powershell
php artisan install:api --without-migration-prompt --no-interaction
```

Le scaffolding a :

1. ajouté `laravel/sanctum` aux dépendances et mis à jour `composer.lock` ;
2. publié `config/sanctum.php` ;
3. publié la migration `create_personal_access_tokens_table` ;
4. créé `routes/api.php` ;
5. enregistré le fichier de routes API dans `bootstrap/app.php`.

Les fichiers versionnés sont :

- `config/sanctum.php` ;
- `database/migrations/2026_11_19_080607_create_personal_access_tokens_table.php` ;
- `routes/api.php` ;
- `bootstrap/app.php` ;
- `app/Models/User.php` ;
- `composer.json` et `composer.lock`.

## Configuration

### Garde et mode d'authentification

L'authentification de ce lot repose uniquement sur des **Personal Access Tokens** transmis dans l'en-tête HTTP :

```http
Authorization: Bearer <token>
```

`config/sanctum.php` conserve le guard `web` dans la liste des guards examinés avant le token :

```php
'guard' => ['web'],
```

Aucune authentification SPA stateful par cookies n'est activée dans ce lot : la méthode `statefulApi()` n'est pas appelée dans `bootstrap/app.php` et le middleware `EnsureFrontendRequestsAreStateful` n'est pas ajouté au groupe `api`. Les routes API restent donc authentifiées par token.

Le guard `web` reste le guard par défaut de l'application dans `config/auth.php`. Les tokens Sanctum ne remplacent pas la connexion web de CHAN-43.

### Expiration

L'expiration des tokens est fixée à **30 jours** dans `config/sanctum.php` :

```php
'expiration' => 60 * 24 * 30,
```

La valeur est exprimée en minutes, conformément à l'API Sanctum : 43 200 minutes. Sanctum compare la date de création du token à l'heure courante ; un token créé il y a plus de 30 jours est refusé. La valeur peut être ajustée dans ce fichier de configuration, avec une revue explicite des conséquences de sécurité.

Le jeton lui-même n'est jamais stocké en clair : Sanctum conserve uniquement son empreinte SHA-256 dans la colonne `token` de `personal_access_tokens`. La valeur retournée par `createToken()` n'est affichée qu'une fois.

### Préfixe

`config/sanctum.php` conserve un préfixe vide :

```php
'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),
```

Aucun préfixe n'est imposé dans ce lot. Si un préfixe est introduit, il doit être documenté et appliqué de manière cohérente sur tous les environnements.

## Modèle User

`App\Models\User` utilise le trait `Laravel\Sanctum\HasApiTokens` :

```php
use HasApiTokens, HasFactory, HasRoles, Notifiable;
```

Le trait est ajouté sans retirer :

- `HasFactory` ;
- `HasRoles` de Spatie Laravel Permission ;
- `Notifiable` ;
- `FilamentUser` et `canAccessPanel()`.

Les règles d'accès Filament ne sont pas modifiées par CHAN-39.

## Routage API

`bootstrap/app.php` enregistre désormais le fichier de routes API :

```php
->withRouting(
    web: __DIR__.'/../routes/web.php',
    api: __DIR__.'/../routes/api.php',
    commands: __DIR__.'/../routes/console.php',
    health: '/up',
)
```

Laravel applique automatiquement le préfixe `/api` et le groupe de middleware `api`. Le fichier `routes/api.php` créé par le scaffolding contient une route de démonstration protégée :

```php
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
```

Cette route permet de vérifier le fonctionnement de l'authentification par token. Elle ne constitue pas une API métier. Aucun endpoint de connexion, de déconnexion ou de gestion des chantiers n'est ajouté dans ce lot.

## Migration

La migration `2026_11_19_080607_create_personal_access_tokens_table.php` crée la table `personal_access_tokens` avec les colonnes standard de Sanctum :

| Colonne | Type | Rôle |
| --- | --- | --- |
| `id` | clé primaire | Identifiant du token. |
| `tokenable_type`, `tokenable_id` | relation polymorphe | Utilisateur ou autre modèle propriétaire du token. |
| `name` | texte | Libellé du token. |
| `token` | chaîne unique de 64 caractères | Empreinte SHA-256 du token. |
| `abilities` | texte nullable | Capacités éventuelles du token. |
| `last_used_at` | horodatage nullable | Dernière utilisation. |
| `expires_at` | horodatage nullable indexé | Expiration explicite éventuelle. |
| `created_at`, `updated_at` | horodatages | Suivi standard Eloquent. |

La migration est additive : elle ne modifie aucune table existante. Elle porte les annotations de politique de migration du projet :

```php
/**
 * @phase expand
 *
 * @ticket CHAN-39
 */
```

Elle est appliquée par la procédure habituelle (`php artisan migrate`) sur chaque environnement. Ne jamais exécuter `migrate:fresh` sur une base qui n'est pas explicitement isolée.

La table est vérifiée sur SQLite par la suite Feature et sur MariaDB 10.11 par la suite `tests/MariaDb`. La politique générale est décrite dans [`database-migrations.md`](database-migrations.md).

## Utilisation

### Créer un token

```php
$newToken = $user->createToken('nom-du-client');

return response()->json([
    'token' => $newToken->plainTextToken,
]);
```

La valeur `plainTextToken` n'est disponible qu'à la création. Le client doit la conserver de manière sécurisée.

### Appeler une route protégée

```http
GET /api/user
Authorization: Bearer 1|valeur-du-token
Accept: application/json
```

Un token absent, invalide, expiré ou révoqué produit une réponse `401 Unauthorized`.

### Révoquer un token

Révoquer le token utilisé par la requête courante :

```php
$request->user()->currentAccessToken()->delete();
```

Révoquer tous les tokens d'un utilisateur :

```php
$request->user()->tokens()->delete();
```

La révocation est immédiate : le token supprimé ne peut plus authentifier de requête. Les autres tokens du même utilisateur restent valides.

## Sécurité

- Transmettre les tokens uniquement sur HTTPS en dehors du développement local.
- Ne jamais journaliser un token en clair ni le versionner dans le dépôt.
- Ne jamais exposer `plainTextToken` ailleurs que dans la réponse de création.
- Considérer un token comme un secret équivalent à un mot de passe.
- Ajuster la durée d'expiration et révoquer les tokens compromis.
- Les capacités (`abilities`) ne remplacent pas les rôles et permissions Spatie : les contrôles métier restent du ressort des Policies et des règles d'autorisation.

Aucun mécanisme de limitation de débit spécifique aux routes API n'est ajouté dans ce lot ; il devra être traité avec les routes métier et leur exposition.

## Coexistence avec Spatie Permission

Les deux mécanismes sont complémentaires :

| Mécanisme | Rôle | Ticket |
| --- | --- | --- |
| Token Sanctum | Identifier l'utilisateur qui appelle l'API | CHAN-39 |
| Rôle ou permission Spatie | Vérifier un droit global | CHAN-38, puis CHAN-40 |
| Policy Laravel | Autoriser une action sur une ressource | CHAN-42 |

Un utilisateur authentifié par token reste un utilisateur Eloquent standard. Ses rôles et permissions Spatie sont résolus normalement, comme le vérifie `tests/Feature/Authentication/SanctumTest.php`.

## Tests et contrôles

Les tests dédiés sont :

- `tests/Feature/Authentication/SanctumTest.php` pour SQLite ;
- `tests/MariaDb/SanctumTest.php` pour le schéma et le comportement sur MariaDB 10.11.

Ils couvrent :

- la création d'un token et le stockage de son empreinte ;
- l'authentification avec un Bearer Token valide ;
- le refus d'un token invalide ;
- la révocation d'un token sans affecter les autres ;
- l'expiration après 30 jours ;
- le refus d'accès anonyme ;
- la coexistence avec Spatie Permission.

Commandes utiles :

```powershell
php artisan test tests/Feature/Authentication/SanctumTest.php
vendor/bin/pest --configuration=phpunit.mariadb.xml
composer lint:check
composer types:check
```

La suite MariaDB nécessite une base isolée `chantier_test` déjà migrée. Ne jamais exécuter `migrate:fresh` sur une base non explicitement isolée.

## Hors périmètre CHAN-39

Ne pas considérer comme implémentés dans ce ticket :

- les endpoints métier, y compris les chantiers ;
- la connexion, la déconnexion et la réinitialisation du mot de passe (CHAN-43) ;
- les rôles et permissions métier (CHAN-40) ;
- les Policies et middleware d'accès aux chantiers (CHAN-42) ;
- l'authentification SPA stateful par cookies ;
- le MFA (CHAN-44) ;
- la journalisation des événements de sécurité (CHAN-45).

## Références

- [`AGENTS.md`](../../AGENTS.md)
- [`config/sanctum.php`](../../config/sanctum.php)
- [`config/auth.php`](../../config/auth.php)
- [`app/Models/User.php`](../../app/Models/User.php)
- [`routes/api.php`](../../routes/api.php)
- [`database/migrations/2026_11_19_080607_create_personal_access_tokens_table.php`](../../database/migrations/2026_11_19_080607_create_personal_access_tokens_table.php)
- [`docs/development/authorization.md`](authorization.md)
- [`docs/development/testing.md`](testing.md)
- [`docs/development/database-migrations.md`](database-migrations.md)
- [Documentation Laravel Sanctum](https://laravel.com/docs/sanctum)
