# Tests Pest

Ce document définit l'organisation et les commandes de test de C2ME Chantier.

## Objectifs

Le socle distingue les tests rapides exécutés sur SQLite en mémoire des tests qui vérifient explicitement le comportement du moteur MariaDB. Ces suites sont complémentaires.

## Organisation des fichiers

| Emplacement | Responsabilité | Environnement |
| --- | --- | --- |
| `tests/Unit/` | Tests isolés de classes et fonctions, sans dépendance à HTTP ou à une base réelle | PHPUnit/Pest standard |
| `tests/Feature/` | Intégration Laravel : HTTP, authentification, autorisations et interactions applicatives | SQLite en mémoire |
| `tests/MariaDb/` | Comportements propres à MariaDB : SQL, contraintes, migrations, types, collations et persistance | MariaDB dédiée |

Fichiers de configuration :

- `phpunit.xml` : suites Unit et Feature, SQLite en mémoire.
- `phpunit.mariadb.xml` : suite MariaDB dédiée.
- `tests/Pest.php` : déclaration des TestCase Pest par répertoire.
- `tests/bootstrap-mariadb.php` : force les variables de connexion avant le bootstrap Laravel.
- `tests/TestCase.php` : base Laravel des tests applicatifs.
- `tests/MariaDbTestCase.php` : garde-fous MariaDB et transactions annulées après chaque test.

Un test est placé dans la suite correspondant à sa dépendance réelle. Ne pas placer un test MariaDB dans Feature uniquement pour bénéficier du démarrage Laravel. Ne pas utiliser MariaDB pour un test unitaire qui peut rester isolé.

## Nommage et écriture

- Nommer les fichiers selon le sujet testé et terminer par `Test.php` : `HomeRouteTest.php`, `UserPersistenceTest.php`, `MigrationPolicyTest.php`.
- Utiliser des noms explicites ; éviter `ExampleTest.php`, `Test1.php` ou les noms génériques.
- Décrire le comportement attendu dans les noms des tests Pest, de préférence en français comme les tests existants.
- Un test vérifie un comportement observable et une raison d'échouer ; supprimer les tests démonstratifs sans valeur de régression.
- Préférer des assertions ciblées et des jeux de données explicites.
- Utiliser des factories lorsque le scénario porte sur des modèles et que les factories existent ; éviter les fixtures globales ou les dépendances à l'ordre d'exécution.
- Chaque test doit pouvoir être exécuté seul et dans la suite complète.
- Nettoyer les ressources temporaires créées par le test, y compris lorsqu'une assertion échoue.
- Ne pas dépendre d'un service externe, d'une donnée de production ou d'un secret.
- Ne pas tester deux fois le même contrat au seul motif que plusieurs suites existent.

### Choix entre Unit et Feature

Utiliser Unit lorsque la logique peut être testée sans conteneur Laravel, base de données, requête HTTP ou système externe.

Utiliser Feature lorsqu'il faut vérifier le comportement intégré de Laravel : routes, middleware, authentification, autorisation, validation HTTP, réponses et interactions avec les composants applicatifs.

Les tests Feature utilisent `Tests\\TestCase` et `RefreshDatabase`, configurés dans `tests/Pest.php`. La base SQLite en mémoire est réinitialisée selon le cycle de vie Laravel.

### Choix de MariaDB

Utiliser `tests/MariaDb` lorsqu'un comportement dépend du moteur MariaDB : syntaxe SQL, contraintes, index, collations, valeurs par défaut, types, transactions ou comportement réel des migrations.

La suite est volontairement non destructive : elle attend une base `chantier_test` déjà migrée et encadre chaque test dans une transaction annulée. Le garde-fou de `MariaDbTestCase` refuse un autre pilote ou une autre base.

**Sécurité :** ne jamais lancer `migrate:fresh` sur une base autre que la base de test explicitement isolée. Ne jamais réutiliser les identifiants jetables de la CI.

## Commandes locales

Prérequis :

- PHP 8.4 et extensions nécessaires à Laravel ; `pdo_sqlite` pour SQLite et `pdo_mysql` pour MariaDB.
- Composer 2 et dépendances installées avec `composer install`.
- Node.js/npm uniquement pour le build frontend intégré au pipeline complet.
- Pour la suite MariaDB : instance MariaDB 10.11 locale, base dédiée `chantier_test`, utilisateur dédié et droits limités à cette base.

### Tests rapides SQLite

Depuis la racine du dépôt :

```bash
php artisan test
```

Cette commande exécute les suites Unit et Feature déclarées dans `phpunit.xml`, sur SQLite en mémoire. Les variables structurantes `APP_ENV`, `DB_CONNECTION`, `DB_DATABASE` et `DB_URL` sont forcées dans cette configuration.

Pour exécuter un fichier ou filtrer un test :

```bash
php artisan test tests/Feature/HomeRouteTest.php
php artisan test --filter="home"
```

### Suite MariaDB

Configurer les variables d'environnement vers une base de test dédiée `chantier_test`, puis :

```bash
php artisan config:clear
php artisan migrate --force --no-interaction
vendor/bin/pest --configuration=phpunit.mariadb.xml
```

La commande de migration ci-dessus est destructive si la base contient déjà des données et ne doit être exécutée que sur la base de test isolée. La CI utilise `migrate:fresh` sur son service éphémère ; cette commande ne doit pas être transposée à une base locale partagée.

### Contrôles qualité

```bash
composer lint:check
composer types:check
npm run build
```

### Commande agrégée destinée à la CI

```bash
composer ci:check --no-interaction
```

`ci:check` délègue au script Composer `test`, qui exécute dans l'ordre :

1. `php artisan config:clear --ansi` ;
2. `pint --parallel --test` via `composer lint:check` ;
3. `phpstan analyse` via `composer types:check` ;
4. `php artisan test`.

Cette commande est le point d'entrée stable pour les contrôles PHP et les suites SQLite dans GitHub Actions et pour l'intégration prévue dans CHAN-35. Elle ne lance pas la suite MariaDB : celle-ci reste un job distinct, avec son service éphémère, ses migrations et sa configuration dédiée. Le build frontend et les tests des scripts d'exploitation restent également des étapes séparées du workflow.

Ne pas remplacer `composer ci:check` par une commande locale partielle dans la CI sans décision documentée.

## CI GitHub Actions

Le workflow `.github/workflows/tests.yml` :

- installe PHP 8.4 et les dépendances Composer ;
- prépare l'environnement Laravel et les assets ;
- lance `composer ci:check` pour les contrôles PHP et les tests Unit/Feature SQLite ;
- démarre un service MariaDB 10.11 éphémère ;
- vérifie la connexion, applique les migrations et contrôle leur état ;
- lance `vendor/bin/pest --configuration=phpunit.mariadb.xml --colors=never` ;
- construit et vérifie le package Linux dans un job dédié.

La suite MariaDB n'utilise aucun serveur C2ME et aucune donnée réelle. La CI est la validation de référence pour les deux moteurs ; les résultats doivent être consultés sur le commit exact de la Pull Request.

## Ajouter un test

1. Identifier le comportement observable et la suite correspondant à ses dépendances.
2. Créer un fichier au nom explicite dans le répertoire approprié.
3. Écrire des tests indépendants, déterministes et ciblés.
4. Exécuter le fichier concerné puis la suite correspondante.
5. Exécuter `composer ci:check --no-interaction` pour les contrôles PHP/SQLite.
6. Si le changement touche MariaDB, exécuter aussi la suite MariaDB dédiée.
7. Vérifier la CI de la Pull Request et rapporter les résultats réellement observés.

Références : `README.md`, `AGENTS.md`, `phpunit.xml`, `phpunit.mariadb.xml`, `tests/Pest.php` et `.github/workflows/tests.yml`.
