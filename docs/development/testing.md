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

### Analyse statique PHP (Larastan)

Larastan étend PHPStan avec la connaissance des APIs Laravel : modèles Eloquent, conteneur, façades, validation et relations. Il complète les tests et Pint en détectant des incohérences de types, des méthodes inexistantes ou des contrats mal respectés sur le code applicatif. Il ne remplace ni les tests de comportement ni la validation MariaDB.

Versions réellement verrouillées dans `composer.lock` :

| Paquet | Version verrouillée | Rôle |
| --- | --- | --- |
| `larastan/larastan` | `v3.15.0` | extension Laravel pour PHPStan |
| `phpstan/phpstan` | `2.3.5` | moteur d'analyse statique |

`composer.json` déclare `larastan/larastan` avec la contrainte `^3.9` ; PHPStan est amené transitivement par Larastan.

La configuration est définie dans `phpstan.neon`. Le niveau actuellement configuré est **7**. Le périmètre analysé est exactement :

- `app/` ;
- `bootstrap/app.php` ;
- `config/` ;
- `database/` ;
- `routes/`.

`tests/` et `bootstrap/providers.php` ne font pas partie du périmètre actuel.

La commande de référence est :

```bash
composer types:check
```

Elle exécute `phpstan analyse` avec la configuration `phpstan.neon`. Le niveau 7 constitue le niveau initial retenu pour le code existant ; il ne garantit pas l'absence de défauts et pourra être relevé par décision documentée.

Politique d'exclusion :

- aucune exclusion globale de `app/` n'est admise ;
- toute exclusion éventuelle doit rester limitée à un chemin précis, être justifiée et documentée ;
- les exclusions ne doivent pas servir à masquer des erreurs applicatives : une erreur réelle doit être corrigée, pas ignorée.

En cas d'erreur détectée, l'analyse retourne un code de sortie non nul. `composer types:check` échoue alors et la CI (`composer ci:check`) s'arrête, ce qui rend la régression bloquante. Ne pas contourner ce comportement avec `|| true`, une option d'ignorance ou un baseline ajouté sans justification.

Lors de la validation locale de CHAN-34, l'analyse a porté sur 22 fichiers avec un code de sortie nul et aucune erreur. Ce résultat est un constat daté de cette validation, pas une garantie permanente : il dépend du périmètre et du niveau configurés.

### Commande agrégée destinée à la CI

```bash
composer ci:check --no-interaction
```

`ci:check` délègue au script Composer `test`, qui exécute dans l'ordre :

1. `php artisan config:clear --ansi` ;
2. `pint --parallel --test` via `composer lint:check` ;
3. `phpstan analyse` via `composer types:check` ;
4. `php artisan test`.

Cette commande est le point d'entrée stable pour les contrôles PHP et les suites SQLite dans le job `ci` de GitHub Actions. Elle ne lance pas la suite MariaDB : celle-ci reste un job distinct, avec son service éphémère, ses migrations et sa configuration dédiée. Le build frontend et les tests des scripts d'exploitation restent également des étapes séparées du workflow.

Ne pas remplacer `composer ci:check` par une commande locale partielle dans la CI sans décision documentée.

## CI GitHub Actions

Le workflow d'intégration continue est défini dans `.github/workflows/tests.yml`. Il porte le contrôle qualité du dépôt ; il ne publie aucune release et ne déploie rien.

### Déclencheurs et branches

Le workflow s'exécute pour :

- un `push` sur `develop` ;
- un `push` sur `main` ;
- une `pull_request` ciblant `develop` ;
- une `pull_request` ciblant `main`.

Une branche temporaire (`feature/*`, `bugfix/*`, `docs/*`, etc.) ne déclenche donc pas la CI par un simple push : elle est contrôlée dès qu'une Pull Request la cible vers `develop` ou `main`. Aucun filtre `paths` n'est appliqué : chaque événement retenu exécute le workflow complet. Aucun déclenchement manuel (`workflow_dispatch`) n'est configuré, et le workflow de tests n'est déclenché ni par un tag ni par une release.

Ce périmètre est vérifié structurellement par `.github/scripts/tests/validate-workflows.php`, qui contrôle la présence des événements `push` et `pull_request` ainsi que des branches `develop` et `main` pour chacun.

### Jobs

| Job | Nom affiché | Rôle |
| --- | --- | --- |
| `ci` | `ci` | Contrôles qualité PHP, validation des workflows et des scripts d'exploitation, build frontend, tests Unit/Feature sur SQLite en mémoire. |
| `mariadb` | `mariadb-10.11` | Vérification du comportement réel sur MariaDB 10.11 avec une base éphémère dédiée. |
| `package-linux` | `package-linux` | Construction et vérification du package Linux. |

Les trois jobs ne déclarent aucune clé `needs` : ils sont indépendants et GitHub Actions peut les exécuter en parallèle, sans ordre imposé entre eux. L'échec d'un job suffit à marquer le workflow en échec.

#### Job `ci`

Le job `ci` s'exécute sur `ubuntu-latest` et :

1. exécute les tests d'automatisation de release ;
2. installe PHP 8.4, Composer 2 et Node.js 22 ;
3. installe les dépendances Composer puis valide les workflows avec `php .github/scripts/tests/validate-workflows.php` ;
4. exécute les tests d'automatisation de déploiement, de sauvegarde/restauration et de rollback ;
5. prépare un `.env` local et un fichier `database/database.sqlite` vide pour l'isolation des tests ;
6. installe les dépendances npm avec `npm ci` et construit les assets avec `npm run build` ;
7. exécute `composer ci:check`, qui enchaîne `php artisan config:clear --ansi`, Laravel Pint en mode vérification (`pint --parallel --test`), Larastan/PHPStan (`phpstan analyse`) puis la suite `php artisan test` (Pest) sur SQLite en mémoire.

#### Job MariaDB

Le job `mariadb-10.11` démarre un service `mariadb:10.11` éphémère, joignable uniquement sur la boucle locale, avec une base, un utilisateur et des mots de passe jetables propres à la CI. Il vérifie la connexion, applique les migrations avec `php artisan migrate:fresh --force --no-interaction`, contrôle leur état puis exécute `vendor/bin/pest --configuration=phpunit.mariadb.xml --colors=never`. Aucun serveur C2ME et aucune donnée réelle ne sont utilisés.

#### Job `package-linux`

Le job `package-linux` prépare PHP 8.4 et Node.js 22, puis exécute `bash .github/scripts/tests/test-assemble-linux.sh` pour construire et vérifier le package Linux. Il ne publie ni n'envoie cet artefact : la publication et le déploiement relèvent des workflows dédiés.

### Contrôles qualité exécutés

- Validation structurelle des workflows, des déclencheurs, des jobs, des permissions et des actions épinglées.
- Contrôles des scripts d'automatisation de release, de déploiement, de sauvegarde/restauration et de rollback.
- Laravel Pint en mode vérification.
- Larastan/PHPStan au niveau configuré dans `phpstan.neon`.
- Pest via `php artisan test` sur SQLite en mémoire.
- `npm run build` pour le frontend Vite/Tailwind.
- Suite Pest MariaDB dédiée.
- Construction et vérification du package Linux.

### Comportement en cas d'échec

Chaque étape échoue avec un code de sortie non nul et interrompt le job concerné ; le workflow est alors marqué en échec. Le workflow de tests n'utilise ni `continue-on-error: true` ni `|| true` pour masquer un échec, et ces usages sont refusés par `validate-workflows.php`. Les jobs n'étant pas chaînés, l'échec de l'un n'annule pas les autres, mais le résultat global reste en échec. Une Pull Request dont la CI est en échec ne doit pas être fusionnée lorsque le contrôle `ci` est requis par la protection de branche.

### CI qualité, release et déploiement

- `.github/workflows/tests.yml` : contrôle qualité uniquement, permissions `contents: read`, aucun secret SSH, aucun environnement GitHub, aucune migration hors du job MariaDB éphémère.
- `.github/workflows/release.yml` : déclenché par un tag `v*`, crée ou met à jour la release GitHub correspondante.
- `.github/workflows/deploy-staging.yml` et `.github/workflows/deploy-production.yml` : déploient les artefacts promus selon le processus de release.

La séparation est contrôlée par `validate-workflows.php` : le workflow de tests ne doit contenir aucun job de release ou de déploiement, aucune référence à un environnement de déploiement et aucun secret SSH.

La frontière de responsabilité est la suivante : CHAN-35 couvre la configuration et la fiabilisation du workflow de tests et de son script de validation ; le workflow Git, les releases, les environnements et les déploiements relèvent de CHAN-92 et de ses documents spécialisés. Les travaux spécifiques aux suites SQLite et au build frontend relèvent de CHAN-36 ; le workflow de tests conserve les étapes nécessaires à leur exécution sans les redéfinir ici.

La CI est la validation de référence pour les deux moteurs de base de données ; les résultats doivent être consultés sur le commit exact de la Pull Request.

## Ajouter un test

1. Identifier le comportement observable et la suite correspondant à ses dépendances.
2. Créer un fichier au nom explicite dans le répertoire approprié.
3. Écrire des tests indépendants, déterministes et ciblés.
4. Exécuter le fichier concerné puis la suite correspondante.
5. Exécuter `composer ci:check --no-interaction` pour les contrôles PHP/SQLite.
6. Si le changement touche MariaDB, exécuter aussi la suite MariaDB dédiée.
7. Vérifier la CI de la Pull Request et rapporter les résultats réellement observés.

Références : `README.md`, `AGENTS.md`, `phpunit.xml`, `phpunit.mariadb.xml`, `tests/Pest.php` et `.github/workflows/tests.yml`.
