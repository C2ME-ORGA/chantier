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

## Workflow Git

Le projet utilise deux branches permanentes et des branches temporaires rattachées à un ticket Jira :

- `main` : branche de référence des versions de production.
- `develop` : branche d'intégration continue.
- `feature/CHAN-123-description` : nouvelles fonctionnalités, créées depuis `develop`.
- `bugfix/CHAN-123-description` : corrections non urgentes, créées depuis `develop`.
- `hotfix/CHAN-123-description` : correctifs urgents, créés depuis `main`.

Les commits suivent les [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `docs`, etc.). Les Pull Requests sont obligatoires vers `main` et vers `develop`, et le contrôle GitHub Actions `ci` doit être vert avant toute fusion.

Les protections `protect-main` et `protect-develop` sont actives : les pushes directs, le force-push et la suppression des branches protégées sont bloqués, sans bypass.

Les conventions détaillées (nommage, cycle de vie des branches, commits, Pull Requests et livraison) sont documentées dans [`docs/development/git-workflow.md`](docs/development/git-workflow.md). Le versionnement Semantic Versioning, les tags (`vX.Y.Z` et `vX.Y.Z-rc.N`), les notes de version et le processus de publication sont définis dans [`docs/development/release-process.md`](docs/development/release-process.md). Les environnements de recette et de production, leur séparation et leurs protections sont décrits dans [`docs/development/environments.md`](docs/development/environments.md). Les déploiements automatisés sont décrits dans [`docs/development/deployment-process.md`](docs/development/deployment-process.md).

## Environnements

Le projet prévoit deux environnements sur un même serveur Ubuntu 24.04 / aaPanel :

- `staging` : recette, données fictives ou anonymisées, accès réservé à l'équipe C2ME.
- `production` : données réelles et application publique.

Leur architecture, leur isolation, les variables et secrets attendus, les protections GitHub et les contrôles de validation sont documentés dans [`docs/development/environments.md`](docs/development/environments.md). Aucun workflow de déploiement n'est défini dans CHAN-96.

## Déploiements

Depuis CHAN-97, deux workflows automatisent les déploiements :

- `deploy-staging` : déclenché par un tag `vX.Y.Z-rc.N` sur `develop`, il construit le paquet, publie l'artefact immuable et le déploie en recette ;
- `deploy-production` : déclenché par la publication d'une release stable, il réutilise **exactement** l'artefact validé en staging, sans reconstruire l'application.

Le paquet contient `vendor/` et les assets Vite, jamais `.env`, `node_modules` ni `storage`. Le déploiement serveur utilise des releases versionnées, un lien `current` et un stockage partagé, sans migration automatique ni rollback automatisé. Les environnements GitHub et leurs secrets doivent être configurés manuellement. La procédure complète, les limites et les vérifications sont décrites dans [`docs/development/deployment-process.md`](docs/development/deployment-process.md). La stratégie de migrations, la compatibilité N/N-1 et la politique de rollback sont définies dans [`docs/development/database-migrations.md`](docs/development/database-migrations.md).

## Sauvegardes et restauration

La stratégie de sauvegarde, d'intégrité et de restauration isolée est définie dans [`docs/development/backup-restore.md`](docs/development/backup-restore.md), avec la procédure opérateur dans [`docs/development/backup-restore-runbook.md`](docs/development/backup-restore-runbook.md). Un jeu de sauvegarde de référence contient toujours la base et les fichiers d'une même opération ; un dump de base seul n'est jamais une sauvegarde complète. La clé privée de déchiffrement n'est jamais stockée sur le serveur.

Aucune sauvegarde réelle n'a été produite et aucune restauration réelle n'a été démontrée à ce stade. Les scripts [`scripts/ops`](scripts/ops) sont livrés avec des tests locaux à outils simulés ; ils ne sont pas planifiés automatiquement. La perte complète du serveur reste un **NO-GO** tant qu'aucune copie hors site n'existe.

## Rollback applicatif

Le rollback applicatif manuel est défini dans [`docs/development/application-rollback.md`](docs/development/application-rollback.md) et sa procédure opérateur dans [`docs/development/application-rollback-runbook.md`](docs/development/application-rollback-runbook.md). Il réactive une release antérieure en basculant atomiquement `current`, après vérification de la release, attestation de compatibilité N/N-1 et confirmation de l'arrêt des workers et de la pause des files.

Il n'est jamais déclenché automatiquement, n'exécute aucune migration, ne restaure pas la base de données et ne modifie ni `.env`, ni `shared/storage`, ni les jobs, le cron, Supervisor ou PHP-FPM. Il est outillé par [`scripts/ops/rollback.sh`](scripts/ops/rollback.sh).

## Suivi

Le backlog et les décisions projet sont suivis dans [Jira – C2ME Chantier](https://sarlc2me.atlassian.net/jira/software/projects/CHAN).

Dépôt : https://github.com/C2ME-ORGA/chantier
