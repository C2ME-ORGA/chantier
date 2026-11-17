# C2ME Chantier

Application de gestion opérationnelle des chantiers de SARL C2ME.

## Stack technique

| Composant | Version / choix |
|---|---|
| PHP | 8.4 (contrainte Composer actuelle : `^8.3`) |
| Laravel | 13 (`^13.17`) |
| Livewire | 4 (`^4.1`) |
| Filament | 5 — installation/configuration à finaliser dans CHAN-22 |
| Front-end | Vite + Tailwind CSS 4 |
| Base de données | MariaDB / MySQL ; SQLite pour les tests automatisés |
| Tests | Pest 5 |
| Qualité | Laravel Pint, Larastan |

Le dépôt contient déjà l'application Laravel. Ne pas exécuter `composer create-project` dans ce dépôt.

## Prérequis

- PHP 8.4 et les extensions requises par Laravel 13 ;
- Composer 2 ;
- Node.js et npm ;
- SQLite pour les tests ;
- MariaDB/MySQL pour l'environnement applicatif.

Vérifier les versions :

```powershell
php -v
composer --version
node --version
npm --version
```

## Installation locale

```powershell
git clone https://github.com/C2ME-ORGA/chantier.git
cd chantier
composer install
npm ci
Copy-Item .env.example .env
php artisan key:generate
```

Configurer ensuite les paramètres locaux dans `.env`. Ne jamais placer de secrets réels dans `.env.example`.

### SQLite (développement léger et tests)

Le fichier `.env.example` et `phpunit.xml` prévoient SQLite. Pour une base locale persistante :

```powershell
New-Item -ItemType File -Force database/database.sqlite
php artisan migrate
```

### MariaDB / MySQL

Configurer dans le fichier `.env` local les paramètres d'une base de développement dédiée :

```dotenv
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=chantier
DB_USERNAME=chantier
DB_PASSWORD=
```

Créer préalablement la base et son utilisateur, puis exécuter :

```powershell
php artisan config:clear
php artisan migrate
```

Les lots 1 et 2 de CHAN-21 sont intégrés : la CI GitHub Actions démarre un service MariaDB 10.11 éphémère, exécute les migrations sur la base isolée `chantier_test`, vérifie que le schéma est à jour, puis lance la suite `tests/MariaDb` (connexion, schéma, contraintes, CRUD et routes applicatives). SQLite reste le moteur des tests rapides ; la suite MariaDB valide le comportement réel du moteur. Depuis CHAN-36, un job `sqlite` dédié vérifie aussi la connexion, les migrations et les suites Pest sur le fichier `database/testing.sqlite` ; les tests d'assets Vite restent couverts par le job `ci` après le build. Les commandes locales sont décrites dans la section « Intégration continue » ci-dessous.

### Assets front-end

Le projet utilise Tailwind CSS 4 via `@tailwindcss/vite`. La configuration est CSS-first dans `resources/css/app.css` ; aucun fichier `tailwind.config.js` n'est requis par la configuration actuelle.

```powershell
npm run build
npm run dev
```

### Vérifications

```powershell
php artisan --version
php artisan test
composer lint:check
composer types:check
npm run build
```

Pour les conventions de nommage, le choix entre Unit/Feature/MariaDB, les prérequis et toutes les commandes de test, consulter [docs/development/testing.md](docs/development/testing.md). La commande agrégée destinée à la CI est `composer ci:check --no-interaction` ; elle exécute les contrôles PHP et la suite SQLite en mémoire. La validation SQLite sur fichier dédié se lance avec `vendor/bin/pest --configuration=phpunit.sqlite.xml`. La suite MariaDB reste un job distinct du workflow et se lance avec `vendor/bin/pest --configuration=phpunit.mariadb.xml` sur une base `chantier_test` isolée.

Ces commandes doivent être exécutées après installation ; leur présence ici ne signifie pas qu'elles ont déjà été validées sur chaque environnement.

### Intégration continue

Le workflow [`.github/workflows/tests.yml`](.github/workflows/tests.yml) sépare quatre jobs indépendants :

- le job `ci` conserve les contrôles existants sur SQLite en mémoire, conformément à `phpunit.xml` : tests de l'automatisation des releases et des déploiements, validation des workflows (dont les configurations SQLite et MariaDB), tests des scripts de sauvegarde/restauration et de rollback, Pint, Larastan/PHPStan, Pest et build frontend. Il installe les dépendances avec `npm ci`, construit les assets avec `npm run build`, puis vérifie le manifest Vite et tous les fichiers référencés avec `scripts/ci/verify-vite-build.php` ;
- le job `sqlite` vérifie la connexion Laravel avec `DB_CONNECTION=sqlite`, cible le fichier dédié `database/testing.sqlite`, exécute les migrations avec `php artisan migrate --force --no-interaction`, vérifie leur état avec `scripts/ci/verify-sqlite-migrations.php`, puis lance les suites Pest avec `phpunit.sqlite.xml` ; les tests d'assets Vite y sont ignorés faute de build et restent exécutés dans le job `ci` ;
- le job `mariadb-10.11` démarre un service éphémère `mariadb:10.11`, vérifie réellement la connexion Laravel avec `DB_CONNECTION=mariadb`, exécute `migrate:fresh` sur la base isolée `chantier_test`, vérifie que toutes les migrations sont appliquées avec `scripts/ci/verify-mariadb-migrations.php`, puis exécute la suite `tests/MariaDb` (connexion, migrations, schéma, CRUD `User` et routes applicatives `/` et `/up`) via `phpunit.mariadb.xml` ;
- le job `package-linux` construit et vérifie le paquet Linux.

Le job MariaDB n'utilise que des identifiants jetables propres à la CI et n'accède à aucun serveur C2ME. Les tests rapides `tests/Unit`, `tests/Feature` et `tests/Architecture` restent exécutés sur SQLite en mémoire par `php artisan test`. La suite `tests/MariaDb` ne remplace pas SQLite : elle vérifie le moteur réel, les migrations, le schéma, le CRUD existant et le démarrage des routes applicatives sur MariaDB. Pour l'exécuter localement sur une instance MariaDB 10.11 isolée :

```powershell
$env:DB_CONNECTION='mariadb'
$env:DB_HOST='127.0.0.1'
$env:DB_PORT='3306'
$env:DB_DATABASE='chantier_test'
$env:DB_USERNAME='chantier_test'
$env:DB_PASSWORD='<mot-de-passe-local>'
php artisan config:clear
php artisan migrate --force
vendor\bin\pest --configuration=phpunit.mariadb.xml
```

Ne jamais exécuter `migrate:fresh` sur une base locale, de staging ou de production non explicitement isolée.

## Livewire et Filament

Livewire 4 est déclaré dans `composer.json` et verrouillé dans `composer.lock`.

L'installation complète de Filament 5, la création du panel d'administration et les vérifications associées sont suivies dans [CHAN-22](https://sarlc2me.atlassian.net/browse/CHAN-22). Ne pas considérer le panel Filament comme opérationnel tant que cette étape et ses tests ne sont pas réalisés.

## Architecture cible

Le projet suivra une architecture **Modular Monolith**. Les domaines métier seront isolés dans `modules/`, avec des contrats explicites et des règles de dépendance documentées. Le répertoire `app/` conservera le bootstrap Laravel et les éléments transverses nécessaires. La mise en place de cette architecture est suivie séparément dans Jira.

## Workflow Git

Le projet utilise deux branches permanentes et des branches temporaires rattachées à un ticket Jira :

- `main` : branche de référence des versions de production ;
- `develop` : branche d'intégration ;
- `feature/CHAN-123-description` : nouvelles fonctionnalités, créées depuis `develop` ;
- `bugfix/CHAN-123-description` : corrections non urgentes, créées depuis `develop` ;
- `hotfix/CHAN-123-description` : correctifs urgents, créés depuis `main` ;
- `docs/CHAN-123-description` : modifications documentaires sans changement fonctionnel, créées depuis `develop`.

Les commits suivent les [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `docs`, etc.). Les Pull Requests sont obligatoires vers `main` et `develop`, et le contrôle GitHub Actions `ci` doit être vert avant toute fusion.

Les protections `protect-main` et `protect-develop` sont documentées comme actives. Les conventions détaillées sont décrites dans [`docs/development/git-workflow.md`](docs/development/git-workflow.md). La revue technique des Pull Requests s'appuie sur [`docs/development/pull-request-review.md`](docs/development/pull-request-review.md) ; cette checklist complète le workflow sans redéfinir les règles de branches, d'approbation ou de fusion.

## Environnements et opérations

Les procédures relatives aux environnements, releases, déploiements, migrations, sauvegardes/restaurations et rollback sont documentées dans `docs/development/` : [sauvegarde et restauration](docs/development/backup-restore.md), [runbook sauvegarde/restauration](docs/development/backup-restore-runbook.md), [rollback applicatif](docs/development/application-rollback.md) et [runbook rollback](docs/development/application-rollback-runbook.md). Leur documentation ne constitue pas, à elle seule, la preuve qu'une opération réelle a été exécutée.

Aucune sauvegarde/restauration réelle ni copie hors site ne doit être considérée comme validée sans preuve d'exécution et de contrôle.

## Sécurité

- Ne jamais versionner `.env`, des secrets, clés privées, exports de base de données ou données réelles.
- Conserver `.env.example` sans identifiants ni secrets.
- Utiliser des comptes et bases dédiés aux environnements de développement et de test.
- Ne pas exécuter de migration destructive sur une base contenant des données réelles.

## Suivi

Le backlog et les décisions projet sont suivis dans [Jira – C2ME Chantier](https://sarlc2me.atlassian.net/jira/software/projects/CHAN).

Dépôt : https://github.com/C2ME-ORGA/chantier
