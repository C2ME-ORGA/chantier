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

La validation spécifique MariaDB (migrations, contraintes, types, transactions et tests automatisés sur le moteur réel) reste à réaliser dans CHAN-21. La configuration SQLite des tests ne prouve pas la compatibilité MariaDB.

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

Ces commandes doivent être exécutées après installation ; leur présence ici ne signifie pas qu'elles ont déjà été validées sur chaque environnement.

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

Les protections `protect-main` et `protect-develop` sont documentées comme actives. Les conventions détaillées sont décrites dans [`docs/development/git-workflow.md`](docs/development/git-workflow.md).

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
