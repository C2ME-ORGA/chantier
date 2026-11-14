# Stratégie de migrations de base de données et de rollback

Ce document définit la stratégie de migrations, les règles de compatibilité entre releases et la politique de rollback de **C2ME Chantier**.

- Ticket : CHAN-98 – Documenter la recette, le rollback et les migrations (lot 1).
- Ticket parent : CHAN-92 – Définir le workflow Git, les releases et les déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : audit du schéma existant, stratégie Expand / Migrate / Contract, compatibilité N/N-1, politique d'exécution, conventions de rédaction, validation manuelle, rollback applicatif et procédures d'échec.
- Hors portée : sauvegarde et restauration opérationnelles (traitées par le lot 2 dans [`backup-restore.md`](backup-restore.md)), recette fonctionnelle, automatisation des migrations dans les workflows et exécution réelle sur staging ou production.

> **Statut de ce lot.** Aucune migration n'a été exécutée sur une base réelle, aucune base n'a été modifiée et aucun workflow de déploiement n'a été changé. Les seules vérifications exécutées sont des tests statiques et la suite de tests locale sur SQLite en mémoire. Les procédures de ce document sont des règles à appliquer ; elles ne constituent pas une preuve d'exécution.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Migrations, compatibilité N/N-1 et rollback | Ce document |
| Sauvegarde, intégrité et restauration | [`backup-restore.md`](backup-restore.md) |
| Déploiements, releases et activation de `current` | [`deployment-process.md`](deployment-process.md) |
| Environnements, isolation et sauvegardes | [`environments.md`](environments.md) |
| Versionnement et releases | [`release-process.md`](release-process.md) |
| Branches, commits et Pull Requests | [`git-workflow.md`](git-workflow.md) |
| Règles impératives | [`AGENTS.md`](../../AGENTS.md) |
| Migrations existantes | [`database/migrations`](../../database/migrations) |
| Configuration de la connexion | [`config/database.php`](../../config/database.php) |
| Tests de politique de migration | [`tests/Unit/Migrations`](../../tests/Unit/Migrations) |

En cas de divergence entre ce document et le schéma réellement déployé, le schéma de la base active et la table `migrations` font foi. Une divergence doit être constatée, documentée et corrigée ; elle ne doit jamais être corrigée par une modification manuelle silencieuse.

## Sommaire

1. [Principes directeurs](#1-principes-directeurs)
2. [Audit initial du schéma](#2-audit-initial-du-schéma)
3. [Règle de compatibilité N/N-1](#3-règle-de-compatibilité-nn-1)
4. [Stratégie Expand / Migrate / Contract](#4-stratégie-expand--migrate--contract)
5. [Politique d'exécution](#5-politique-dexécution)
6. [Politique de rollback](#6-politique-de-rollback)
7. [Conventions de rédaction](#7-conventions-de-rédaction)
8. [Opérations interdites dans une migration automatique](#8-opérations-interdites-dans-une-migration-automatique)
9. [Règles de validation manuelle](#9-règles-de-validation-manuelle)
10. [Procédures en cas d'échec](#10-procédures-en-cas-déchec)
11. [Critères autorisant une migration destructive différée](#11-critères-autorisant-une-migration-destructive-différée)
12. [Intégration avec le mécanisme de releases CHAN-97](#12-intégration-avec-le-mécanisme-de-releases-chan-97)
13. [Tests et contrôles](#13-tests-et-contrôles)
14. [Décisions à prendre avant le lot 2](#14-décisions-à-prendre-avant-le-lot-2)
15. [Références](#15-références)

## 1. Principes directeurs

1. **La base est partagée par toutes les releases.** Une release est un répertoire immuable, mais le schéma et les données sont communs. Activer une release précédente ne recharge pas une ancienne base.
2. **Un rollback applicatif ne restaure jamais la base.** Il rebascule le lien `current` vers une release antérieure. Le schéma, les données, les jobs exécutés et les effets externes restent en l'état.
3. **La compatibilité N/N-1 est une contrainte de conception**, pas une vérification faite après coup. Tant qu'un rollback reste possible, le code N-1 doit fonctionner sur le schéma laissé par N.
4. **Aucune migration n'est exécutée automatiquement** par les workflows de déploiement. Ce lot ne change pas cette règle. Une migration est une opération d'exploitation explicite, validée et traçable.
5. **Toute évolution suit Expand, puis Migrate, puis Contract.** Une suppression ou un renommage n'est jamais mélangé à l'ajout qui le remplace.
6. **Le serveur reste l'autorité.** Aucune donnée venue du navigateur, y compris en mode hors connexion, ne décide du schéma, des droits ou d'une transition d'état.
7. **Les données financières, les validations métier et les identifiants d'opération hors connexion ne sont jamais réécrits par un mécanisme générique.** Une transformation de données doit être explicite, idempotente et rejouable.
8. **Une migration destructrice exige une décision humaine écrite**, après expiration de la fenêtre de rollback et après vérification d'une sauvegarde restaurable.
9. **Le doute profite à la compatibilité.** En cas d'incertitude sur un consommateur, une colonne ou un job, l'ancien objet reste en place et une nouvelle phase est planifiée.
10. **Aucune preuve n'est supposée.** Un test local sur SQLite ne prouve pas le comportement MariaDB 10.11 ; une répétition en staging est obligatoire avant une migration sensible en production.

## 2. Audit initial du schéma

### 2.1 Méthode

L'audit a porté sur l'intégralité du dépôt au commit `11c2673` de `develop` :

- les fichiers de `database/migrations` ;
- les modèles de `app/Models` et les usages Eloquent ;
- les contraintes, index et clés étrangères déclarés ;
- les connexions et pilotes de `config/database.php` ;
- les files d'attente, le cache et les sessions, qui utilisent la base ;
- les scripts de déploiement et les workflows, pour vérifier l'absence de migration automatique ;
- les tests et la configuration d'intégration continue.

Le dépôt ne contient à ce stade **aucun module métier**, aucun répertoire `modules/`, aucune table de domaine et un seul modèle Eloquent (`App\Models\User`). Le schéma est celui d'une installation Laravel initiale.

### 2.2 Migrations présentes

| Migration | Tables créées | Nature | Opérations destructrices |
| --- | --- | --- | --- |
| `0001_01_01_000000_create_users_table.php` | `users`, `password_reset_tokens`, `sessions` | Création initiale | `down()` supprime les trois tables |
| `0001_01_01_000001_create_cache_table.php` | `cache`, `cache_locks` | Création initiale | `down()` supprime les deux tables |
| `0001_01_01_000002_create_jobs_table.php` | `jobs`, `job_batches`, `failed_jobs` | Création initiale | `down()` supprime les trois tables |

Toutes les migrations utilisent uniquement `Schema::create` dans `up()`. Aucun `ALTER TABLE`, aucun `change()`, aucun `renameColumn()`, aucun `dropColumn()`, aucune donnée n'est écrite par une migration.

La table `migrations` est créée implicitement par Laravel. Elle est la source de vérité de l'état appliqué.

### 2.3 Contraintes et index

| Table | Clé primaire | Index et contraintes | Remarque |
| --- | --- | --- | --- |
| `users` | `id` (`bigint unsigned`) | `email` unique | Aucune clé étrangère |
| `password_reset_tokens` | `email` | Aucune | Le jeton de réinitialisation est haché par Laravel |
| `sessions` | `id` (`varchar(255)`) | `user_id` indexé, `last_activity` indexé | `user_id` n'est **pas** contraint vers `users` |
| `cache` | `key` (`varchar(255)`) | `expiration` indexé | Données reconstructibles |
| `cache_locks` | `key` (`varchar(255)`) | `expiration` indexé | Verrous de cache |
| `jobs` | `id` | `queue` indexé | File d'attente par défaut (`database`) |
| `job_batches` | `id` (`varchar(255)`) | Aucune | Suivi des lots de jobs |
| `failed_jobs` | `id` | `uuid` unique, index `(connection, queue, failed_at)` | Jobs en échec |

Il n'existe **aucune clé étrangère**, aucun `CHECK`, aucun trigger, aucune vue, aucune procédure stockée et aucune colonne générée. Aucune contrainte ne dépend donc aujourd'hui d'un ordre de suppression particulier. La migration `users` supprime néanmoins `users` avant `sessions` ; comme il n'y a pas de clé étrangère, l'ordre actuel n'échoue pas, mais il deviendrait incorrect si une contrainte était ajoutée.

Avec `utf8mb4`, un index InnoDB est limité à 3 072 octets en format de ligne `DYNAMIC` (4 octets par caractère, soit 768 caractères au maximum). Les colonnes indexées actuelles (`varchar(255)`) restent compatibles avec MariaDB 10.11. Une future colonne `varchar(768)` ou plus ne pourrait pas être indexée intégralement sans changer de type ou de stratégie d'index.

### 2.4 Données et criticité

| Donnée | Tables | Criticité | Perte acceptable |
| --- | --- | --- | --- |
| Comptes et authentification | `users`, `password_reset_tokens` | Critique | Non |
| Sessions | `sessions` | Faible | Oui, déconnexion des utilisateurs |
| File d'attente | `jobs`, `job_batches` | Opérationnelle | Non sans analyse : des traitements métier peuvent être en attente |
| Jobs en échec | `failed_jobs` | Opérationnelle et diagnostique | Non sans export préalable |
| Cache et verrous | `cache`, `cache_locks` | Faible | Oui, reconstruction automatique |

L'application utilise `CACHE_STORE=database`, `SESSION_DRIVER=database` et `QUEUE_CONNECTION=database` par défaut. Une opération DDL sur `cache`, `cache_locks`, `sessions`, `jobs` ou `failed_jobs` peut donc avoir un effet immédiat sur l'exécution, indépendamment du code métier.

### 2.5 Constats

| Réf. | Constat | Risque |
| --- | --- | --- |
| A-01 | Les trois migrations sont des créations initiales, sans opération destructive dans `up()`. | Faible |
| A-02 | Les `down()` suppriment toutes les tables. `migrate:rollback`, `migrate:reset` et `migrate:fresh` détruiraient les données. | Critique en staging et production |
| A-03 | Aucune migration métier n'existe encore. La stratégie doit être posée **avant** les premières tables de domaine. | Opportunité |
| A-04 | `sessions.user_id` est indexé mais non contraint. Une future clé étrangère devra être ajoutée selon la phase Migrate, pas dans la création initiale. | Moyen |
| A-05 | Les files d'attente sont en base. Un job sérialisé peut référencer une classe, un modèle ou une colonne qui n'existe plus après un rollback. | Élevé |
| A-06 | Le cache et les sessions sont en base. Un DDL sur ces tables peut interrompre l'authentification ou les verrous. | Moyen |
| A-07 | `composer test` et la CI utilisent SQLite en mémoire. Aucun test automatisé n'exécute les migrations sur MariaDB 10.11. | Élevé |
| A-08 | Les migrations sont incluses dans le paquet de déploiement (seuls `tests/` et `docs/` sont exclus). Elles sont donc disponibles dans chaque release, mais aucune étape ne les exécute. | Faible, par conception |
| A-09 | Aucun workflow, script de déploiement ou script de paquet ne contient `artisan migrate`. Le test de déploiement et la validation des workflows le vérifient déjà. | Faible |
| A-10 | L'utilisateur MySQL de l'application dispose des privilèges nécessaires aux migrations. Ces mêmes identifiants sont présents dans la configuration compilée lue à l'exécution. | Moyen |
| A-11 | `database/database.sqlite` n'est pas versionné ; les tests utilisent `:memory:`. Aucune base locale de référence n'est partagée. | Faible |
| A-12 | Aucun mécanisme ne relie une release à l'état du schéma. `release.json` ne contient ni lot de migrations ni empreinte du schéma. | Moyen |
| A-13 | Aucune procédure de sauvegarde/restauration n'est encore opérationnelle (lot 2). Une migration destructive ne peut donc pas être autorisée en production à ce stade. | Critique |

### 2.6 Conclusion de l'audit

Le schéma actuel ne contient aucune incompatibilité immédiate : il n'a jamais été déployé et toutes les migrations sont additives. Le risque principal n'est pas le schéma existant, mais les **pratiques** qui seront employées pour les premières migrations métier :

- confondre rollback applicatif et rollback de base ;
- utiliser `migrate --force` comme étape de déploiement ;
- livrer un renommage ou une suppression dans la même release que l'ajout ;
- oublier que N-1 doit encore fonctionner après l'activation de N ;
- considérer SQLite comme une preuve de compatibilité MariaDB.

## 3. Règle de compatibilité N/N-1

### 3.1 Définitions

- **Release N** : release applicative active, identifiée par `releases/<release-id>` et par `release.json`.
- **Release N-1** : release immédiatement précédente, conservée dans `releases/` et susceptible d'être réactivée.
- **Schéma S(N)** : état physique de la base après application des migrations livrées avec N.
- **Fenêtre de rollback** : période pendant laquelle un retour à N-1 est autorisé. Elle se termine par une décision explicite, jamais par l'écoulement implicite du temps.
- **Compatibilité N/N-1** : capacité du code N-1 à lire et écrire correctement sur S(N), sans erreur SQL, sans corruption et sans comportement métier faux.

### 3.2 Conditions de compatibilité

Le code N-1 doit pouvoir, sur S(N) :

1. démarrer sans erreur (aucune colonne ou table requise au bootstrap ne doit manquer) ;
2. lire les colonnes qu'il sélectionne, y compris avec `select *` ;
3. insérer sans violer une contrainte ajoutée par N ;
4. mettre à jour les colonnes qu'il utilise sans troncation ni erreur de type ;
5. interpréter les valeurs qu'il rencontre (statuts, énumérations, booléens, montants) ;
6. traiter les jobs qu'il rencontre ou les laisser en file sans les casser ;
7. produire des données que N saura relire après un retour en avant.

La compatibilité de structure est nécessaire mais **insuffisante** : une colonne ajoutée avec une valeur par défaut peut être structurellement compatible et provoquer un comportement métier incorrect si N-1 l'ignore.

### 3.3 Règles opposables

| Situation sur S(N) | N-1 compatible ? | Condition |
| --- | --- | --- |
| Nouvelle table | Oui, par défaut | N-1 ne la référence pas |
| Nouvelle colonne nullable | Oui | N-1 ne l'utilise pas |
| Nouvelle colonne `NOT NULL` avec valeur par défaut | Oui pour les inserts de N-1 | La valeur par défaut doit rester métier-correcte |
| Nouvelle colonne `NOT NULL` sans défaut sur une table non vide | **Non** | Les inserts de N-1 échouent |
| Nouvel index non unique | Oui | Coût de verrouillage à maîtriser |
| Nouvel index unique | **Non** tant que N-1 peut créer des doublons | Déduplication préalable et validation |
| Nouvelle clé étrangère | **Non** si N-1 peut insérer une valeur absente | Contrainte ajoutée après disparition du chemin N-1 |
| Colonne renommée | **Non** | N-1 référence l'ancien nom |
| Colonne supprimée | **Non** | N-1 échoue à la lecture ou à l'écriture |
| Type modifié ou rétréci | **Non** en général | Troncation, erreur ou perte de précision |
| `ENUM` ou jeu de statuts étendu | Dépend du code | N-1 doit tolérer les nouvelles valeurs |
| `ENUM` ou jeu de statuts réduit | **Non** | Les valeurs existantes deviennent invalides |
| Charset ou collation modifiés | Risqué | Index, comparaisons et tri peuvent changer |
| Table supprimée | **Non** | N-1 échoue |

### 3.4 Fin de la fenêtre de rollback

Une release N-1 cesse d'être une cible de rollback lorsque l'une des conditions suivantes est remplie :

- une décision explicite et traçable retire N-1 de la liste des releases réactivables ;
- une migration Contract a été appliquée et N-1 ne peut plus fonctionner sur le schéma courant ;
- la release N-1 a été supprimée de `releases/` après la période de conservation.

La fin de la fenêtre ne se déduit jamais de la seule ancienneté d'une release. La durée et les critères exacts restent à valider (voir section 14).

## 4. Stratégie Expand / Migrate / Contract

### 4.1 Vue d'ensemble

```text
Release N-1        Release N                     Release N+1
   │                  │                             │
   │   Expand         │   Migrate                   │   Contract
   │   (structure)    │   (données et usages)       │   (suppression)
   ▼                  ▼                             ▼
 Ancien schéma  ──►  Schéma compatible  ──►  N-1 ne dépend plus  ──►  Nettoyage
                     avec N-1               de l'ancien objet
```

La règle de séquencement est la suivante :

1. **Expand** ajoute la nouvelle structure sans retirer l'ancienne.
2. **Migrate** déploie un code capable de fonctionner avec l'ancienne et la nouvelle structure, puis transforme les données.
3. **Contract** supprime l'ancienne structure uniquement lorsque plus aucune release réactivable n'en dépend.

### 4.2 Expand

Objectifs :

- ajouter les nouvelles colonnes de manière compatible ;
- créer les nouvelles tables sans modifier le comportement de N-1 ;
- ajouter les index et contraintes qui ne rejettent aucune écriture légitime de N-1 ;
- ne jamais renommer ni supprimer dans cette phase.

> Les exemples de cette section sont illustratifs : la table `projects` n'existe pas encore dans le dépôt. Ils montrent la forme attendue, pas un schéma approuvé.

Exemple Laravel — ajout d'une colonne nullable :

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * @phase expand
 * @ticket CHAN-000
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('projects', 'reference')) {
            return;
        }

        Schema::table('projects', function (Blueprint $table) {
            $table->string('reference', 32)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('projects', function (Blueprint $table) {
            $table->dropColumn('reference');
        });
    }
};
```

Remarques :

- la colonne est ajoutée **en fin de table**, sans `after()` : `after()` empêche l'ajout instantané et impose une reconstruction ;
- `nullable()` garantit que les inserts de N-1 restent valides ;
- le garde `Schema::hasColumn()` permet de reprendre une exécution interrompue sans rejouer une erreur ; il ne doit pas masquer des opérations suivantes ;
- `down()` est destructif mais n'est jamais la procédure de rollback de production.

Exemple Laravel — création d'une table :

```php
Schema::create('project_references', function (Blueprint $table) {
    $table->id();
    $table->foreignId('project_id')->constrained()->cascadeOnDelete();
    $table->string('value', 32);
    $table->timestamps();

    $table->unique(['project_id', 'value']);
});
```

Une nouvelle table peut référencer une table existante : N-1 n'écrit pas dans la nouvelle table et n'est donc pas affectée. L'inverse — ajouter une clé étrangère d'une table existante vers une nouvelle table — suit les règles de la phase Migrate.

### 4.3 Migrate

Objectifs :

- livrer un code qui fonctionne avec l'ancien et le nouveau schéma ;
- transformer les données de façon contrôlée, idempotente et reprenable ;
- maintenir la double écriture lorsque N-1 doit encore lire l'ancien emplacement ;
- ne pas bloquer l'application avec un traitement long.

Exemple Laravel — transformation bornée dans une migration :

```php
public function up(): void
{
    DB::table('projects')
        ->whereNull('reference')
        ->orderBy('id')
        ->chunkById(500, function ($rows): void {
            foreach ($rows as $row) {
                DB::table('projects')
                    ->where('id', $row->id)
                    ->whereNull('reference')
                    ->update(['reference' => sprintf('PRJ-%08d', $row->id)]);
            }
        });
}
```

Cette forme convient à un volume faible et borné. Pour un volume important, la transformation sort de la migration et devient une commande Artisan dédiée, exécutée manuellement, avec reprise et journalisation (voir section 5.4).

Exemple Laravel — double écriture pendant la transition :

```php
final class ProjectReferenceWriter
{
    public function update(Project $project, string $reference): void
    {
        DB::transaction(function () use ($project, $reference): void {
            $project->forceFill([
                'reference' => $reference,
                'legacy_reference' => $reference,
            ])->save();
        });
    }
}
```

La double écriture appartient au module métier concerné, pas à la migration. Elle doit être couverte par des tests et supprimée lors du Contract.

### 4.4 Contract

Objectifs :

- supprimer l'ancienne colonne, l'ancien index ou l'ancienne table ;
- supprimer la double écriture et les lectures de secours ;
- ne jamais être livré dans la même release que l'Expand.

Exemple Laravel — suppression différée :

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * @phase contract
 * @ticket CHAN-000
 * @contract CHAN-000
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('projects', function (Blueprint $table) {
            $table->dropColumn('legacy_reference');
        });
    }

    public function down(): void
    {
        // La structure peut être recréée, jamais les données supprimées.
        Schema::table('projects', function (Blueprint $table) {
            $table->string('legacy_reference', 32)->nullable();
        });
    }
};
```

Le tag `@contract` est obligatoire et est contrôlé par les tests statiques. Il ne remplace pas la validation humaine : il rend une opération destructrice visible et empêche son introduction silencieuse.

### 4.5 Séquence complète d'un renommage compatible

| Release | Code | Schéma | Rollback possible vers |
| --- | --- | --- | --- |
| N-1 | Lit et écrit `reference` | `reference` | N-2 |
| N (Expand + Migrate) | Lit la nouvelle colonne, écrit `reference` **et** `code` | `reference` + `code` nullable | N-1 : `reference` est toujours alimentée |
| N+1 (Migrate) | Lit et écrit `code`, ne dépend plus de `reference` | inchangé | N : `code` existe et est alimentée |
| N+2 (Contract) | Lit et écrit `code` | `reference` supprimée | N+1 uniquement ; N n'est plus une cible |

Le Contract ne peut pas être livré en N+1 si N écrit encore `reference` : un rollback de N+1 vers N échouerait. Il faut une release intermédiaire qui supprime la dépendance, puis le Contract.

### 4.6 Changement de type

Un rétrécissement ou un changement de type n'est jamais compatible avec N-1. La séquence est :

1. ajouter une nouvelle colonne du type cible, nullable ;
2. backfiller et double-écrire ;
3. basculer les lectures ;
4. supprimer l'ancienne colonne après la fenêtre de rollback.

Un élargissement compatible (`varchar(50)` vers `varchar(100)`) reste une opération de type `Migrate` : il doit être répété en staging et ne doit pas être considéré comme gratuit en verrouillage.

### 4.7 Ajout d'une contrainte `NOT NULL`

1. ajouter la colonne nullable ;
2. backfiller toutes les lignes ;
3. vérifier l'absence de `NULL` ;
4. ajouter la contrainte dans une release ultérieure, après disparition des écritures N-1 qui pourraient laisser `NULL`.

Ajouter directement `NOT NULL` sans défaut sur une table non vide échoue ou bloque selon les données ; c'est interdit.

### 4.8 Ajout d'un index unique

1. identifier et corriger les doublons avec une requête de diagnostic ;
2. vérifier que N-1 ne peut plus créer de doublon ;
3. ajouter l'index dans une phase Migrate validée ;
4. prévoir le temps de verrouillage et une répétition en staging.

Un index unique ajouté sur des données non contrôlées est une migration incompatible.

## 5. Politique d'exécution

### 5.1 Classification des migrations

| Classe | Exemples | Exécution autorisée |
| --- | --- | --- |
| A — Expansion additive | Nouvelle table, colonne nullable, index non unique | Manuelle, après validation ; automatisable plus tard si le processus est prouvé |
| B — Transformation de données | Backfill, normalisation, recalcul | Manuelle, surveillée, idempotente, avec reprise |
| C — Restriction | `NOT NULL`, index unique, clé étrangère, `CHECK` | Manuelle, après vérification des données et répétition en staging |
| D — Destructrice | `DROP`, `RENAME`, `TRUNCATE`, suppression de lignes, rétrécissement de type | Validation renforcée ; `@contract` obligatoire pour retirer une structure, après la fenêtre de rollback |
| E — Infrastructure | Charset, collation, moteur, partitionnement | Fenêtre de maintenance et décision explicite ; jamais automatique |

### 5.2 Automatique, manuel et interdit

- **Automatique en local et en CI** : `migrate` sur une base éphémère SQLite en mémoire. Cela vérifie la syntaxe et l'ordre des migrations, pas le comportement MariaDB.
- **Automatique en déploiement** : aucune migration, sans exception dans ce lot. Les workflows `deploy-staging`, `deploy-production`, `release` et les scripts serveur ne contiennent aucune commande de migration.
- **Manuel avec validation** : toute migration A, B ou C sur staging puis production, avec preuve de répétition en staging.
- **Manuel avec validation renforcée** : toute migration D, avec sauvegarde vérifiée ; pour une suppression de structure, après expiration de la fenêtre de rollback.
- **Interdit** : `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe`, `migrate:rollback` en staging ou production, et toute migration D non validée.

### 5.3 Risques de `php artisan migrate --force`

`--force` ne fait pas qu'ignorer une confirmation : il exécute **toutes** les migrations en attente, dans l'ordre, sur la base cible.

| Risque | Explication |
| --- | --- |
| Absence de contrôle de contenu | `--force` n'analyse ni la nature, ni la durée, ni la compatibilité des migrations. |
| Application en lot | Toutes les migrations en attente sont appliquées avec le même numéro de lot. Un `migrate:rollback` sans `--step` tenterait de toutes les annuler. |
| Absence d'atomicité DDL | MariaDB engage implicitement chaque instruction DDL. Un échec au milieu laisse un état partiel. |
| Migration de données longue | Le backfill s'exécute dans la même commande que le DDL, sans reprise ni progression. |
| Verrouillage non maîtrisé | Un `ALTER TABLE` peut attendre un verrou de métadonnées et bloquer les écritures applicatives. |
| Absence de sauvegarde vérifiée | `--force` ne vérifie ni la sauvegarde, ni sa restaurabilité. |
| Mauvaise cible | Une erreur de répertoire, de `.env` ou de connexion peut appliquer la migration au mauvais environnement. |
| Effet de bord sur les files | Une migration qui touche `jobs`, `cache` ou `sessions` peut interrompre les workers ou les sessions. |

Conséquences :

- `--force` est autorisé uniquement après validation, dans une commande explicite et tracée, jamais comme étape générique de déploiement ;
- la commande doit préciser la connexion (`--database`) lorsque plusieurs connexions existent ;
- `--isolated` est recommandé pour éviter deux exécutions concurrentes, avec la réserve de la section 5.5 ;
- `--pretend` est exécuté avant toute migration non triviale, mais ne remplace pas une répétition réelle.

### 5.4 Migrations longues

Une migration est considérée comme longue si elle dépasse l'un des seuils proposés suivants :

- plus de 30 secondes estimées ;
- plus de 10 000 lignes à transformer ;
- un `ALTER TABLE` sur une table de plus de 100 000 lignes ;
- un verrou de métadonnées susceptible de durer plus de quelques secondes.

Une migration longue :

- n'est pas exécutée dans la même commande que le déploiement ;
- est portée par une commande Artisan dédiée, idempotente et reprenable ;
- traite les données par lots avec `chunkById` ;
- enregistre sa progression dans une table de suivi ou dans un journal d'exploitation ;
- peut être interrompue puis reprise sans doublon ;
- est exécutée pendant une fenêtre à faible trafic, avec surveillance ;
- ne bloque pas les écritures applicatives plus longtemps que la fenêtre validée.

Exemple de commande dédiée (hors migration) :

```php
final class BackfillProjectReferences extends Command
{
    protected $signature = 'projects:backfill-references {--chunk=500}';

    public function handle(): int
    {
        DB::table('projects')
            ->whereNull('reference')
            ->orderBy('id')
            ->chunkById((int) $this->option('chunk'), function ($rows): void {
                foreach ($rows as $row) {
                    DB::table('projects')
                        ->where('id', $row->id)
                        ->whereNull('reference')
                        ->update(['reference' => sprintf('PRJ-%08d', $row->id)]);
                }
            });

        return self::SUCCESS;
    }
}
```

La commande n'est pas planifiée automatiquement et n'est pas appelée par un déploiement.

### 5.5 Verrous MySQL/MariaDB

- **Verrou de métadonnées** : un `ALTER TABLE` attend la fin des transactions ouvertes qui utilisent la table, puis bloque les nouvelles requêtes pendant sa phase critique. Une transaction longue suffit à bloquer une migration.
- **Délai de verrou** : définir un `lock_wait_timeout` court sur la session de migration pour échouer vite plutôt que bloquer l'application. La valeur exacte est une décision d'exploitation.
- **Transactions applicatives** : ne jamais laisser une transaction ouverte pendant un DDL. Vérifier `SHOW PROCESSLIST` avant une opération sensible.
- **Algorithmes explicites** : pour un `ALTER TABLE` sensible, utiliser `ALGORITHM=INPLACE, LOCK=NONE` lorsque l'opération le permet. MariaDB échoue alors explicitement si l'algorithme n'est pas disponible, au lieu de verrouiller silencieusement.
- **`INSTANT`** : l'ajout d'une colonne en fin de table peut être instantané selon la version et le moteur. Ne pas en dépendre sans répétition sur MariaDB 10.11.
- **`foreign_key_checks`** : ne pas désactiver globalement les contrôles pour faire passer une migration. Une désactivation locale doit être justifiée, encadrée et suivie d'une vérification des orphelins.
- **`--isolated`** : s'appuie sur le cache de l'application. Le cache par défaut étant en base, une migration qui modifie `cache` ou `cache_locks` peut perturber le verrou lui-même. Dans ce cas, utiliser une coordination externe (verrou de déploiement ou arrêt des exécutions concurrentes).
- **Concurrence GitHub** : les groupes `deploy-staging` et `deploy-production` empêchent deux déploiements simultanés, mais pas une exécution manuelle parallèle. L'opérateur doit vérifier qu'aucune migration n'est déjà en cours.

### 5.6 Transactions et DDL MariaDB

- MariaDB engage implicitement la transaction courante avant et après une instruction DDL. Un `ROLLBACK` ne défait pas un `CREATE`, un `ALTER` ou un `DROP`.
- Laravel 13 déclare `public $withinTransaction = true` sur `Migration`, mais l'enveloppe n'est utilisée que si la grammaire supporte les transactions de schéma. Ce n'est pas le cas du pilote MySQL/MariaDB : les migrations ne sont donc **pas** exécutées dans une transaction de schéma.
- Une migration composée de plusieurs instructions DDL n'est pas atomique. Même si certaines instructions récentes sont atomiques au niveau de l'instruction, l'ensemble ne l'est pas.
- Une migration de données purement DML peut utiliser `DB::transaction`, mais la transaction doit rester courte. Pour un backfill massif, privilégier des lots avec commit intermédiaire et une reprise idempotente.
- Ne jamais mélanger dans une même migration un DDL long et un backfill massif : le DDL peut réussir, le backfill échouer, et l'état devient difficile à interpréter.

### 5.7 Procédure standard d'exécution

#### Avant

1. Identifier le ticket, la release source et la migration exacte.
2. Vérifier `migrate:status` et l'état de `release.json` de la release active.
3. Vérifier que la migration a été répétée en staging sur MariaDB 10.11.
4. Vérifier la classification (A, B, C, D, E) et les approbations requises.
5. Vérifier la sauvegarde et sa restaurabilité (obligatoire pour C, D et E ; lot 2 pour la procédure).
6. Estimer la durée, le verrouillage et l'impact.
7. Exécuter `--pretend` et relire le SQL.
8. Vérifier `SHOW PROCESSLIST` et l'absence de transaction longue.
9. Prévenir les utilisateurs si une interruption est possible.

#### Pendant

1. Exécuter la migration avec la connexion explicite et `--isolated` lorsque pertinent.
2. Surveiller la sortie, les journaux et `SHOW PROCESSLIST`.
3. Ne pas interrompre un DDL par `KILL` sans décision explicite : l'arrêt du client n'arrête pas nécessairement le serveur.
4. En cas d'échec, arrêter et passer à la section 10.

#### Après

1. Vérifier `migrate:status` (qui ne montre que les migrations connues de la release courante) et la structure réelle.
2. Vérifier la structure réelle avec `SHOW CREATE TABLE`.
3. Vérifier les invariants métier (comptages, `NULL`, doublons, orphelins).
4. Vérifier `/up`, les journaux applicatifs et les files d'attente.
5. Consigner la migration, l'heure, l'opérateur, le résultat et le ticket.
6. Ne pas supprimer la sauvegarde avant la fin de la fenêtre de rollback.

### 5.8 Séquencement avec une release immuable

Trois situations doivent être distinguées :

- **Le code N peut démarrer sans l'Expand** (nouvelle table ou colonne non utilisée au démarrage) : l'Expand peut être livré avec N et appliqué juste après l'activation, avant l'usage de la fonctionnalité.
- **Le code N ne peut pas démarrer sans l'Expand** : l'Expand doit être planifié et livré **dans N-1**, appliqué pendant que N-1 est active, puis N est déployée. C'est la seule façon de garantir qu'aucune requête de N ne s'exécute sur un schéma incomplet sans modifier le mécanisme CHAN-97.
- **L'Expand est déjà dans N et N vient d'être activée** : l'appliquer immédiatement depuis `current`, avant d'utiliser la fonctionnalité. La fenêtre pendant laquelle N peut rencontrer un schéma incomplet doit être explicitement acceptée et la plus courte possible.

La règle est donc : **une migration dont l'absence casse le démarrage de la nouvelle release appartient à la release précédente.** Le fichier doit être présent sur le serveur : si aucune release publiée ne le contient, il ne peut pas être appliqué avant le transfert du paquet. L'Expand doit alors être planifié dans la release précédente dès la conception.

Pour restreindre l'exécution à un fichier précis — notamment lorsqu'une release déjà présente sur le serveur contient la migration mais n'est pas encore active — utiliser l'`artisan` de la release active avec `--path` et `--realpath` :

```bash
PHP=/chemin/verifie/vers/php8.4
ROOT=/www/wwwroot/chantier.c2me.fr

cd "$ROOT/current"

# Contrôler l'état et le SQL sans exécuter
"$PHP" artisan migrate:status --path="$ROOT/releases/<release-id>/database/migrations/<migration>.php" --realpath
"$PHP" artisan migrate --force --pretend --path="$ROOT/releases/<release-id>/database/migrations/<migration>.php" --realpath

# Exécuter uniquement ce fichier, avec la release active comme contexte
"$PHP" artisan migrate --force --isolated --path="$ROOT/releases/<release-id>/database/migrations/<migration>.php" --realpath
```

Cette commande exige que la migration soit **autonome** : ni modèle Eloquent, ni service, ni enum de l'application, uniquement `Schema` et `DB`. C'est une contrainte de rédaction (section 7) autant qu'une contrainte d'exploitation.

## 6. Politique de rollback

### 6.1 Règle absolue

> **Un retour à la release précédente ne restaure jamais automatiquement la base de données.**

Le rollback applicatif rebascule le code. Il ne défait ni un `ALTER`, ni un `DROP`, ni un backfill, ni un job exécuté, ni un email envoyé, ni un fichier écrit dans `shared/storage`.

Aucun rollback de base n'est automatique. `migrate:rollback` n'est pas une procédure de rollback de production. Une release N-1 ne contient pas les fichiers de migration de N : exécuter `migrate:rollback` depuis N-1 ne peut pas interpréter correctement le dernier lot et peut échouer ou laisser un état incohérent. De même, `migrate:status` exécuté depuis une release ne montre que les migrations connues de cette release ; il ne prouve pas à lui seul l'état complet du schéma.

### 6.2 Ce qu'un rollback applicatif restaure

| Élément | Restauré | Remarque |
| --- | --- | --- |
| Code PHP de la release | Oui | Via le lien `current` |
| Autoloader et dépendances | Oui | Contenu de la release |
| Assets Vite | Oui | Contenu de la release |
| Configuration compilée | Oui, celle de la release | Peut être obsolète si `.env` a changé |
| Routes et vues compilées | Oui | Contenu de la release |
| Schéma de base | **Non** | Partagé, non versionné par release |
| Données | **Non** | Aucune restauration implicite |
| Jobs exécutés | **Non** | Effets irréversibles |
| Jobs en file | **Non** | Payloads susceptibles d'être incompatibles |
| Fichiers de `shared/storage` | **Non** | Partagés et non versionnés |
| Emails, webhooks, exports | **Non** | Effets externes |
| Cache et sessions | **Non** | Peuvent être vidés, jamais « restaurés » |

### 6.3 Conditions de compatibilité du schéma avec N-1

Avant tout rollback, vérifier que :

1. aucune colonne utilisée par N-1 n'a été supprimée ou renommée ;
2. aucun type utilisé par N-1 n'a été rétréci ;
3. aucune colonne `NOT NULL` sans défaut n'a été ajoutée à une table où N-1 insère ;
4. aucun index unique ni `CHECK` ajouté par N ne rejette une écriture légitime de N-1 ;
5. aucune clé étrangère ajoutée par N ne rejette une valeur produite par N-1 ;
6. les valeurs de statut, d'énumération et de booléen sont interprétables par N-1 ;
7. les jobs en file sont compatibles avec les classes et les colonnes connues de N-1 ;
8. le protocole de synchronisation hors connexion reste compatible avec N-1 ;
9. N-1 ne dépend pas d'une colonne dont N a cessé la double écriture.

Si une seule condition échoue, le rollback applicatif vers N-1 est **interdit**. Il faut corriger en avant ou restaurer une sauvegarde (lot 2), avec perte de données assumée.

### 6.4 Risques liés aux jobs déjà exécutés

- Un job exécuté par N peut avoir écrit une colonne, créé une ligne, envoyé un email ou appelé un service externe. Aucun rollback ne défait ces effets.
- Un job encore en file peut référencer une classe supprimée, un modèle dont le schéma a changé ou une colonne absente. N-1 peut échouer à le désérialiser et le placer dans `failed_jobs`.
- Les jobs peuvent être dans `jobs`, `job_batches` ou `failed_jobs`. Le payload est sérialisé et ne suit pas le schéma.
- Avant un rollback : mettre les files en pause (`queue:pause --all`), arrêter les workers supervisés, attendre la fin des jobs en cours, puis décider du sort des jobs en file (traitement par N avant rollback, ou conservation pour N-1 après vérification).
- Après le rollback : redémarrer les workers avec le code N-1 et reprendre les files (`queue:resume` ou commande équivalente du superviseur).
- Ne jamais vider `jobs` ou `failed_jobs` pour « nettoyer » un rollback : cela détruit la trace de traitements métier.

### 6.5 Risques liés aux données écrites par la nouvelle version

- Les nouvelles lignes peuvent contenir des valeurs inconnues de N-1 (statuts, types, références).
- Les colonnes ajoutées peuvent être remplies alors que N-1 les ignore ; ce n'est pas un problème tant que N-1 ne les sélectionne pas explicitement.
- Un backfill peut avoir modifié des données existantes. N-1 peut les interpréter différemment, surtout si la transformation n'était pas idempotente.
- Les données financières, les validations et les identifiants d'opération hors connexion ne doivent jamais être « corrigés » automatiquement par un rollback. Une correction nécessite une analyse métier et une trace.
- Les fichiers de `shared/storage` écrits par N restent présents et peuvent référencer des entités ou des formats que N-1 ne comprend pas.

### 6.6 Conditions interdisant un rollback automatique

Un rollback ne doit jamais être déclenché automatiquement, même sur échec du health check, lorsque :

- une migration destructive ou un Contract a été appliqué ;
- une migration de données non réversible a été exécutée ;
- une colonne `NOT NULL` sans défaut a été ajoutée ;
- une contrainte ou un index unique rejette les écritures de N-1 ;
- de nouvelles valeurs de statut ont été écrites et N-1 ne les gère pas ;
- le contrat des jobs a changé ;
- le protocole de synchronisation hors connexion a changé ;
- des données financières ou des validations métier ont été produites par N ;
- une migration est en cours, partielle ou non vérifiée ;
- une restauration de données serait nécessaire et aucune sauvegarde vérifiée n'est disponible.

Cette liste est cumulative. Un rollback automatique est toujours exclu. Un rollback applicatif manuel reste possible uniquement si le schéma est compatible et si aucune restauration de données n'est nécessaire.

### 6.7 Matrice de décision

| Situation | Rollback applicatif | Action |
| --- | --- | --- |
| Schéma compatible, aucune donnée sensible écrite | Autorisé, manuel | Rebascule `current`, vérifications, redémarrage des workers |
| Schéma compatible, jobs en file | Autorisé après pause/drain | Traiter ou conserver les jobs selon compatibilité |
| Schéma compatible, données métier nouvelles mais connues de N-1 | Autorisé avec vérification | Contrôles métier renforcés |
| Schéma incompatible | Interdit | Correction en avant ou restauration de sauvegarde |
| Migration destructive appliquée | Interdit | Correction en avant ; restauration de sauvegarde en dernier recours (lot 2) |
| Migration en cours ou partielle | Interdit | Diagnostiquer et terminer/réparer d'abord |
| Échec du health check après activation | Manuel uniquement | Décision explicite, jamais de rollback automatique |

### 6.8 Procédure manuelle de rollback applicatif

Cette procédure est **manuelle**, exécutée par l'administrateur avec le compte technique de l'environnement. Elle ne modifie pas le workflow CHAN-97 et ne restaure pas la base.

Depuis le lot 3, elle est outillée par [`scripts/ops/rollback.sh`](../../scripts/ops/rollback.sh), décrit dans [`application-rollback.md`](application-rollback.md) et [`application-rollback-runbook.md`](application-rollback-runbook.md). Le script applique les mêmes règles, exige une attestation de compatibilité N/N-1 et refuse toute opération non vérifiée. Il ne restaure pas la base et n'exécute aucune migration.

1. **Décider** : qualifier l'incident, choisir la release cible, vérifier qu'elle existe et que `release.json` est lisible.
2. **Geler** : mettre les files en pause et arrêter les workers supervisés. Activer le mode maintenance uniquement si l'incohérence entre code et données l'exige.
3. **Vérifier la compatibilité** : appliquer la checklist 6.3, contrôler `migrate:status` et la structure réelle.
4. **Contrôler la cible** : `artisan`, `public/index.php`, `bootstrap/cache/config.php` et `release.json` doivent être présents et lisibles par le groupe.
5. **Rebasculer atomiquement** `current`, avec la même technique que le déploiement :

   ```bash
   ROOT=/www/wwwroot/chantier.c2me.fr   # adapter à l'environnement
   TARGET="$ROOT/releases/<release-id>"
   LINK="$ROOT/.current.rollback.$$"

   for file in artisan public/index.php bootstrap/cache/config.php release.json; do
     test -f "$TARGET/$file" || { echo "release cible incomplète : $file"; exit 1; }
   done

   ln -sfn "$TARGET" "$LINK"
   mv -Tf "$LINK" "$ROOT/current"
   readlink -f "$ROOT/current"
   ```

6. **Vérifier** : `/up`, journaux, connexion, lectures et écritures représentatives, files d'attente, planificateur.
7. **Redémarrer les workers** avec le code restauré, puis reprendre les files.
8. **Consigner** : release source, release cible, raison, heure, opérateur, état du schéma, décisions sur les jobs et les données.
9. **Ne pas rollback la base** : ne jamais exécuter `migrate:rollback` pour « aligner » la base sur la release restaurée.
10. **Décider de la suite** : correction en avant, nouvelle release, ou restauration de sauvegarde selon le lot 2.

Le rétablissement du service ne vaut pas clôture de l'incident : les données écrites par la release retirée doivent être analysées.

## 7. Conventions de rédaction

### 7.1 Nommage et structure

- Nom de fichier : `YYYY_MM_DD_HHMMSS_verbe_sujet.php`, en minuscules ASCII, mots séparés par `_`. L'horodatage doit être celui de la création ; ne pas antidater une migration pour contourner la politique.
- Une migration = un changement logique. Ne pas mélanger création de table, ajout de colonne et backfill massif.
- Classe anonyme retournée : `return new class extends Migration`.
- `up()` et `down()` obligatoires et non vides.
- `down()` doit être aussi sûr que possible, mais il n'est jamais la procédure de rollback de production.
- En-tête de classe avec `@phase expand|migrate|contract`, `@ticket CHAN-xxx` et, pour une opération destructrice, `@contract CHAN-xxx` (structure) ou `@destructive CHAN-xxx` (données). Ces annotations sont obligatoires pour toute migration créée à compter du 13 novembre 2026 et sont contrôlées par les tests statiques.

Exemple d'en-tête pour une nouvelle migration :

```php
/**
 * @phase expand
 * @ticket CHAN-123
 */
```

### 7.2 Règles de code

- Utiliser `Schema` pour la structure et `DB` pour les données.
- Ne jamais utiliser de modèle Eloquent dans une migration : le modèle évolue avec le code et ne représente pas le schéma au moment de l'exécution.
- Ne jamais utiliser `env()` dans une migration : la configuration doit passer par `config()` ou par la connexion.
- Ne jamais utiliser de service, d'action, d'enum ou de DTO applicatif dans une migration destinée à être exécutée depuis une release antérieure.
- Préférer les colonnes nullables (`->nullable()`) et les valeurs par défaut explicites.
- Ajouter les colonnes en fin de table, sans `after()`, sauf justification et répétition MariaDB.
- Déclarer explicitement les clés étrangères et leurs actions (`nullOnDelete`, `cascadeOnDelete`, `restrict`) ; ne pas compter sur le hasard.
- Nommer les index et contraintes lorsque le nom généré approche la limite de 64 caractères.
- Utiliser `decimal` pour les montants, jamais `float`.
- Éviter `enum` en base ; préférer `string` avec validation applicative et cast PHP.
- Traiter `JSON` comme du texte validé : MariaDB ne fournit pas un type binaire JSON natif aux mêmes garanties que d'autres moteurs.
- Rester compatible `utf8mb4` et `utf8mb4_unicode_ci`, comme la connexion configurée. Toute modification de charset ou de collation est une opération de classe E.
- Écrire des commentaires qui expliquent le **pourquoi** métier et la contrainte de compatibilité, pas la syntaxe.

### 7.3 Idempotence et reprise

- Un backfill doit pouvoir être rejoué sans doubler une valeur : filtrer sur `NULL`, sur une version de traitement ou sur un état explicite.
- Utiliser `chunkById` plutôt que `chunk` lorsque la requête modifie des lignes.
- Ne pas utiliser `update()` massif sans borne sur une table volumineuse.
- Vérifier les invariants avant et après : nombre de lignes, `NULL`, doublons, orphelins.
- Pour une opération DDL, un garde `Schema::hasTable()` ou `Schema::hasColumn()` peut aider à reprendre, mais ne remplace pas la vérification de la table `migrations`.

### 7.4 SQL brut

Le SQL brut est autorisé uniquement lorsqu'il est nécessaire (algorithme explicite, index spécifique, opération non exposée par le builder). Il doit alors :

- utiliser des identifiants fixes, jamais une valeur provenant d'une requête ou d'un utilisateur ;
- être compatible MariaDB 10.11 ;
- être répété en staging ;
- être commenté et associé à un ticket ;
- ne pas contenir plusieurs instructions destructrices non contrôlées.

### 7.5 Tests d'une migration

Avant livraison :

- exécuter la migration sur une base de test vide, puis sur une copie anonymisée représentative ;
- exécuter `--pretend` et relire le SQL ;
- exécuter le `down()` uniquement sur la base de test ;
- vérifier le comportement de N-1 sur le schéma N lorsque la migration est compatible ;
- exécuter les tests Pest, Pint, Larastan et le build frontend selon `AGENTS.md` ;
- ne jamais déclarer une migration testée en production sans preuve d'exécution.

## 8. Opérations interdites dans une migration automatique

Les opérations suivantes sont interdites dans toute migration exécutée automatiquement ou sans validation explicite :

| Opération | Exemple | Raison |
| --- | --- | --- |
| Suppression de table | `Schema::drop`, `Schema::dropIfExists` dans `up()` | Perte de données et rupture N-1 |
| Suppression de colonne | `$table->dropColumn('x')` | Rupture N-1 et perte de données |
| Renommage | `$table->renameColumn('a', 'b')`, `Schema::rename` | Rupture N-1 |
| Troncature | `DB::table('x')->truncate()`, `TRUNCATE TABLE` | Perte de données |
| Suppression massive de lignes | `->delete()`, `->forceDelete()`, `DELETE FROM` | Perte de données |
| Réinitialisation | `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe` | Perte de données |
| Rollback | `migrate:rollback` en staging/production | N'est pas une procédure de rollback |
| Rétrécissement de type | `string(50)->change()` sur `varchar(255)` | Troncation ou erreur |
| `NOT NULL` sans défaut | `$table->string('x')` sur table non vide | Échec des inserts existants |
| Index unique non préparé | `$table->unique('email')` avec doublons | Échec de création |
| Clé étrangère non préparée | `constrained()` sur des valeurs orphelines | Échec de création |
| Désactivation globale des FK | `foreign_key_checks = 0` | Données incohérentes |
| Changement de charset/collation | `ALTER TABLE ... CONVERT TO` | Verrou long, index et tris modifiés |
| Changement de moteur | `ENGINE=...` | Reconstruction complète |
| Mise à jour massive non bornée | `DB::table('x')->update([...])` | Verrou long, transaction volumineuse |
| Appel applicatif | Job, HTTP, mail, événement, modèle Eloquent | Effets de bord imprévisibles |
| `env()` | `env('DB_...')` | Configuration non fiable à l'exécution |
| `KILL` / timeout | Interruption d'un DDL | État partiel |

Une suppression de structure de cette liste n'est autorisée que si elle porte `@phase contract` **et** `@contract CHAN-xxx`, après validation humaine et expiration de la fenêtre de rollback. Une suppression de lignes ou une mise à jour massive relève d'une phase Migrate explicitement identifiée, porte `@destructive CHAN-xxx`, exige une validation de niveau 3 et une sauvegarde vérifiée ; elle n'est jamais une opération de nettoyage implicite.

## 9. Règles de validation manuelle

### 9.1 Niveaux de validation

| Niveau | Migrations | Validation requise |
| --- | --- | --- |
| 1 | A — expansion additive sans données | Responsable technique désigné + répétition en staging |
| 2 | B et C — données, `NOT NULL`, index unique, clé étrangère | Responsable technique + propriétaire du dépôt |
| 3 | D et E — destructrice ou infrastructure | Responsable technique + propriétaire du dépôt + sauvegarde restaurable vérifiée + décision écrite |

Les rôles exacts et les personnes habilitées restent à formaliser (section 14). Le propriétaire du dépôt est déjà l'approbateur de l'environnement `production` dans [`deployment-process.md`](deployment-process.md). La stratégie de sauvegarde et de restauration est définie dans [`backup-restore.md`](backup-restore.md) et sa procédure opérateur dans [`backup-restore-runbook.md`](backup-restore-runbook.md). Tant qu'aucune restauration réelle n'a été démontrée avec preuves, aucune migration de niveau 2 ou 3 ne peut être approuvée pour la production.

### 9.2 Checklist avant staging

- [ ] La migration est classée A, B, C, D ou E.
- [ ] Le ticket Jira est référencé.
- [ ] La migration est autonome et n'utilise aucun modèle applicatif.
- [ ] Un `--pretend` a été relu.
- [ ] La migration a été exécutée sur une base vide.
- [ ] La migration a été exécutée sur une copie représentative ou un jeu de données équivalent.
- [ ] Le `down()` a été exécuté sur la base de test, jamais sur une base réelle.
- [ ] Les invariants de données sont vérifiés.
- [ ] Le comportement de N-1 est vérifié lorsque la migration est compatible.

### 9.3 Checklist avant production

- [ ] La répétition en staging sur MariaDB 10.11 a réussi.
- [ ] La durée estimée et le verrouillage sont connus.
- [ ] La fenêtre d'exécution est choisie.
- [ ] La sauvegarde est disponible et sa restauration a été vérifiée (niveau 2 et 3).
- [ ] La compatibilité N-1 est démontrée.
- [ ] Les jobs en file ont été analysés.
- [ ] Les workers peuvent être mis en pause et redémarrés.
- [ ] Le rollback applicatif est possible ou explicitement interdit.
- [ ] Les personnes habilitées ont donné leur accord écrit.
- [ ] Le plan de surveillance et les seuils d'arrêt sont définis.
- [ ] La commande exacte, le répertoire et la connexion ont été relus.

### 9.4 Preuves à conserver

- ticket et approbations ;
- sortie de `migrate:status` avant/après ;
- sortie de `--pretend` ;
- résultat de la répétition en staging ;
- horodatage, opérateur, release source, commit ;
- vérifications métier et journaux ;
- décision sur les jobs et les données ;
- éventuelle sauvegarde associée et sa date.

## 10. Procédures en cas d'échec

### 10.1 Avant l'exécution

Si un contrôle échoue (sauvegarde absente, staging non répété, compatibilité douteuse), la migration **ne démarre pas**. Le report n'est pas un incident ; une migration non validée exécutée est un incident.

### 10.2 Pendant l'exécution

- Ne pas relancer immédiatement la même commande sans diagnostic.
- Ne pas interrompre un DDL par `KILL` sauf décision explicite : l'arrêt du client ne garantit pas l'arrêt du serveur.
- Relever la dernière migration affichée, l'heure et le message d'erreur.
- Consulter les journaux MariaDB et `SHOW PROCESSLIST`.
- Vérifier la structure réelle avec `SHOW CREATE TABLE` : la table `migrations` ne prouve pas l'état physique d'une migration échouée en cours d'application.
- Si un verrou est en cause, identifier la transaction bloquante avant toute action.

### 10.3 Après un échec partiel

| État constaté | Action |
| --- | --- |
| La migration a échoué avant toute modification | Corriger la migration, répéter en staging, replanifier |
| Le DDL a réussi mais le backfill a échoué | Rendre le backfill idempotent, le reprendre par lots, ne pas rejouer le DDL |
| La migration est enregistrée mais l'objet physique est incomplet | Ne pas modifier la table `migrations` sans procédure écrite ; produire une migration de réparation revue |
| Une migration antérieure du lot a réussi, la suivante a échoué | Laisser l'état en place, corriger la migration en échec ou livrer une migration corrective |
| Des données sont incohérentes | Geler les écritures concernées, analyser, corriger en avant, consigner |

Règles :

- ne jamais supprimer ou insérer manuellement une ligne dans `migrations` sans procédure revue et tracée ;
- ne jamais exécuter `migrate:rollback` pour compenser ;
- privilégier une migration de correction en avant, idempotente et testée ;
- si la migration a déjà été livrée, ne pas modifier son contenu pour « réparer » : livrer une nouvelle migration ;
- si un correctif immédiat est nécessaire, utiliser une commande ciblée et la documenter.

### 10.4 Communication

- Informer les personnes concernées de l'état réel : migration appliquée, partielle ou échouée.
- Ne pas annoncer un retour à la normale avant vérification des données.
- Consigner l'incident et la décision dans le ticket.
- Si le service est dégradé, appliquer la politique de rollback (section 6), pas un rollback de base réflexe.

## 11. Critères autorisant une migration destructive différée

Une migration destructive de structure (classe D) ne peut être planifiée que si **tous** les critères suivants sont remplis :

1. **Fenêtre de rollback close** : plus aucune release réactivable ne dépend de l'objet supprimé.
2. **Release intermédiaire** : au moins une release stable a été déployée sans dépendre de l'objet (fin de la double écriture et des lectures de secours).
3. **Compatibilité N-1 démontrée** : le code de la release immédiatement précédente ne référence plus l'objet.
4. **Sauvegarde vérifiée** : une sauvegarde de la base et du stockage est disponible et sa restauration a été testée (voir [`backup-restore.md`](backup-restore.md)).
5. **Archivage** : les données à conserver sont exportées ou migrées avant la suppression.
6. **Consommateurs identifiés** : aucun export, client hors connexion, intégration ou rapport ne dépend du champ supprimé.
7. **Répétition en staging** : la migration a été exécutée sur une copie représentative anonymisée.
8. **Validation écrite** : le responsable technique et le propriétaire du dépôt ont approuvé la suppression, avec ticket et date.
9. **Plan de surveillance** : les contrôles post-migration et les seuils d'alerte sont définis.
10. **Traçabilité** : la migration porte `@phase contract`, `@contract CHAN-xxx` et une description de la décision.

Un seul critère manquant interdit la migration destructive de structure. Une suppression de lignes ou une mise à jour massive suit les mêmes exigences de sauvegarde, d'archivage, de répétition et de validation, mais ne nécessite ni fenêtre de rollback close ni release intermédiaire au sens structurel ; elle porte `@destructive` et reste de niveau 3. En cas d'urgence de sécurité (donnée personnelle exposée, secret en base), une suppression immédiate peut être autorisée par le propriétaire du dépôt avec une sauvegarde préalable et une trace écrite ; l'urgence ne supprime ni la sauvegarde ni la traçabilité.

## 12. Intégration avec le mécanisme de releases CHAN-97

### 12.1 Ce qui ne change pas

- Le paquet reste immuable.
- `current` est basculé atomiquement vers une release complète.
- `shared/.env` et `shared/storage` ne sont ni copiés ni remplacés.
- Aucune migration n'est ajoutée aux workflows ou aux scripts de déploiement.
- Aucun rollback automatique n'est ajouté.
- `release.json` reste le marqueur de version et de commit.

### 12.2 Ce que le schéma partagé impose

| Élément | Conséquence |
| --- | --- |
| Base unique par environnement | N et N-1 partagent le même schéma |
| Releases immuables | Une migration livrée ne doit pas être modifiée après application |
| Activation atomique | Le code peut changer avant ou après l'application d'une migration |
| `shared/storage` | Les fichiers écrits par N restent après un rollback |
| `release.json` | Permet d'identifier la release active, pas l'état du schéma |
| Pas de hook de migration | L'application d'une migration est une décision d'exploitation explicite |

### 12.3 Séquence recommandée

1. **Préparer** : répéter la migration en staging, vérifier la compatibilité N-1, choisir la fenêtre.
2. **Expand** :
   - si le code N peut démarrer sans l'Expand, livrer l'Expand avec N et l'appliquer juste après l'activation ;
   - si N ne peut pas démarrer sans l'Expand, livrer l'Expand dans N-1 et l'appliquer avant de déployer N.
3. **Migrate** : exécuter les transformations bornées, puis les commandes longues séparément.
4. **Vérifier** : `migrate:status`, structure, invariants, health check, journaux, files.
5. **Contract** : uniquement après la fenêtre de rollback et validation, dans une release ultérieure.

### 12.4 Rollback et releases

- Le rollback applicatif cible une release **complète** présente dans `releases/` et marquée par `release.json`.
- Une release dont le `bootstrap/cache/config.php` est absent ou illisible n'est pas une cible valide.
- Une release dont le code n'est pas compatible avec le schéma courant n'est pas une cible valide.
- Une release dont les fichiers de migration seraient réexécutés ne doit pas être activée sans contrôle de `migrate:status`.
- Une release N-1 peut être conservée dans `releases/` sans être une cible de rollback ; la décision doit être écrite.
- Le rollback applicatif est outillé par [`scripts/ops/rollback.sh`](../../scripts/ops/rollback.sh) (lot 3) : manuel, fail-closed, sans migration ni restauration de base. L'automatisation d'un rollback reste exclue. La sauvegarde et la restauration sont définies dans [`backup-restore.md`](backup-restore.md) ; la procédure manuelle de la section 6.8 reste une règle d'exploitation à répéter en staging avant toute utilisation en production.

### 12.5 Limites assumées de ce lot

- Aucun hook de migration n'est ajouté au déploiement.
- Aucun script de rollback n'est créé.
- Aucune migration réelle n'a été exécutée.
- Aucun environnement GitHub, secret ou serveur n'a été modifié.
- Aucune preuve d'exécution MariaDB n'est fournie.

## 13. Tests et contrôles

### 13.1 Tests statiques ajoutés

Les tests [`tests/Unit/Migrations/MigrationPolicyTest.php`](../../tests/Unit/Migrations/MigrationPolicyTest.php) vérifient :

- le nommage des fichiers ;
- la présence d'une classe anonyme étendant `Migration` ;
- la présence de `up()` et `down()` non vides ;
- l'absence d'opération destructrice de structure dans `up()` sans annotation `@contract` ;
- l'absence de suppression de lignes dans `up()` sans annotation `@destructive` ;
- la classification `@phase` des migrations créées après l'entrée en vigueur de cette politique ;
- l'absence de modèle Eloquent et d'`env()` dans les migrations ;
- l'absence de commande de migration dans les workflows et scripts de déploiement.

Les tests [`tests/Unit/Documentation/MigrationDocumentationTest.php`](../../tests/Unit/Documentation/MigrationDocumentationTest.php) vérifient la présence de ce document, de ses sections obligatoires et du lien depuis [`deployment-process.md`](deployment-process.md).

Ces tests sont statiques : ils ne prouvent pas le comportement MariaDB.

### 13.2 Contrôles manuels

```bash
# État local
php artisan migrate:status
php artisan migrate --pretend

# Tests et qualité
composer test
composer lint:check
composer types:check

# Workflows et scripts de déploiement
php .github/scripts/tests/validate-workflows.php
bash .github/scripts/tests/test-deployment-automation.sh
```

### 13.3 Limites des tests

- La suite applicative utilise SQLite en mémoire (`phpunit.xml`). Elle ne détecte pas les différences de DDL, de verrouillage, de collation ou d'index MariaDB.
- Aucun test ne se connecte à MariaDB 10.11.
- Aucun test n'exécute de migration sur une base réelle.
- Aucun test ne prouve la restaurabilité d'une sauvegarde.
- Un test vert ne remplace pas une répétition en staging.

## 14. Décisions à prendre avant le lot 2

| Réf. | Décision | Impact |
| --- | --- | --- |
| D-01 | Durée et critères exacts de la fenêtre de rollback | Détermine le moment autorisé du Contract |
| D-02 | Rôles et personnes habilitées à approuver les niveaux 1, 2 et 3 | Détermine la validation manuelle |
| D-03 | Utilisateur MySQL dédié aux migrations, distinct de l'utilisateur d'exécution | Réduit le privilège DDL disponible à l'application |
| D-04 | Environnement de répétition MariaDB 10.11 (CI ou staging dédié) | Réduit le risque DDL non testé |
| D-05 | Procédure de sauvegarde, rétention, chiffrement et test de restauration | **Tranchée** : [`backup-restore.md`](backup-restore.md) et [`backup-restore-runbook.md`](backup-restore-runbook.md). Les comptes, clés et racines restent à créer par l'administrateur. |
| D-06 | Ajout de métadonnées de schéma dans `release.json` ou dans un journal séparé | Améliore la traçabilité release/schéma |
| D-07 | Seuils précis des migrations longues et fenêtres d'exécution | Détermine le mode opératoire |
| D-08 | Outil de changement de schéma en ligne (si nécessaire) | À valider avant toute adoption |
| D-09 | Backlog des Contracts à planifier | Évite l'accumulation de colonnes mortes |
| D-10 | Versionnement du protocole de synchronisation hors connexion | Conditionne les migrations visibles par les clients hors connexion |
| D-11 | Sort des jobs en file lors d'un rollback | Détermine la procédure d'arrêt et de reprise |
| D-12 | Autorisation et procédure de restauration de sauvegarde en production | **Partiellement tranchée** : procédure de restauration isolée définie dans [`backup-restore.md`](backup-restore.md). Aucune restauration de production n'est autorisée ni démontrée ; l'autorisation reste à accorder après un test réel réussi. |

## 15. Références

- [`AGENTS.md`](../../AGENTS.md) — règles impératives du projet.
- [`deployment-process.md`](deployment-process.md) — releases, activation et limites CHAN-97.
- [`backup-restore.md`](backup-restore.md) — sauvegarde, intégrité et restauration.
- [`backup-restore-runbook.md`](backup-restore-runbook.md) — procédure opérateur.
- [`application-rollback.md`](application-rollback.md) — rollback applicatif outillé.
- [`application-rollback-runbook.md`](application-rollback-runbook.md) — procédure de rollback.
- [`environments.md`](environments.md) — environnements, isolation, base et sauvegardes.
- [`release-process.md`](release-process.md) — versionnement, tags et releases.
- [`git-workflow.md`](git-workflow.md) — branches, commits et Pull Requests.
- [`config/database.php`](../../config/database.php) — connexion, charset et collation.
- [`database/migrations`](../../database/migrations) — migrations existantes.
- [Laravel 13 — Migrations](https://laravel.com/docs/13.x/migrations).
- [MariaDB 10.11 — ALTER TABLE](https://mariadb.com/kb/en/alter-table/).
- [MariaDB 10.11 — InnoDB Online DDL](https://mariadb.com/kb/en/innodb-online-ddl/).
