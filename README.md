# C2ME Chantier

Application de gestion opérationnelle des chantiers de SARL C2ME.

> **État du dépôt :** initialisation technique. Le socle Laravel doit être généré localement avant l'ajout des dépendances applicatives.

## Stack cible

- PHP 8.4
- Laravel 13
- Livewire 4
- Filament 5
- Bootstrap 5
- Vite
- MySQL / MariaDB
- Redis (cache, files et sessions selon configuration)
- Pest, Laravel Pint et Larastan

## Initialisation locale

Prérequis : PHP 8.4, Composer, Node.js/npm et une base MySQL ou MariaDB disponibles dans l'environnement local.

Depuis le répertoire parent du projet :

```powershell
composer create-project laravel/laravel chantier "^13.0"
cd chantier
```

Si le dépôt Git est déjà cloné dans le répertoire cible, générer le projet Laravel dans un répertoire temporaire puis transférer les fichiers générés dans le dépôt, sans écraser `.git/`.

Installer ensuite les dépendances applicatives une fois les contraintes de versions confirmées :

```powershell
composer require livewire/livewire
composer require filament/filament
npm install
npm install bootstrap @popperjs/core
```

Les commandes ci-dessus installent les dernières versions compatibles déclarées par Composer/npm ; vérifier explicitement les versions majeures attendues avant de valider le socle. La configuration Filament, Livewire et Bootstrap sera réalisée dans les tickets Jira dédiés.

## Vérifications initiales

```powershell
php -v
composer --version
node --version
npm --version
php artisan --version
php artisan test
npm run build
```

Configurer ensuite le fichier `.env` local, créer la base de données, puis exécuter :

```powershell
php artisan key:generate
php artisan migrate
```

Ne jamais versionner `.env`, secrets, clés privées, exports de base de données ou fichiers contenant des données réelles.

## Organisation cible

Le projet suivra une architecture **Modular Monolith**. Les domaines métier seront isolés dans `modules/`, avec des contrats explicites et des règles de dépendance documentées. Le répertoire `app/` conservera le bootstrap Laravel et les éléments transverses nécessaires.

## Workflow Git cible

- `main` : branche de référence et releases.
- `develop` : intégration continue.
- `feature/CHAN-123-description` : nouvelles fonctionnalités.
- `bugfix/CHAN-123-description` : corrections.
- `hotfix/CHAN-123-description` : correctifs urgents de production.

Les protections de branches seront activées après la mise en place de la CI et la validation du premier cycle de Pull Request.

## Suivi

Le backlog et les décisions projet sont suivis dans [Jira – C2ME Chantier](https://sarlc2me.atlassian.net/jira/software/projects/CHAN).

Dépôt : https://github.com/C2ME-ORGA/chantier
