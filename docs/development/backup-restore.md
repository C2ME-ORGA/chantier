# Stratégie de sauvegarde et de restauration

Ce document définit la stratégie de sauvegarde, de vérification d'intégrité et de restauration de **C2ME Chantier**.

- Ticket : CHAN-98 – Documenter la recette, le rollback et les migrations (lot 2 : sauvegarde et restauration).
- Ticket parent : CHAN-92 – Définir le workflow Git, les releases et les déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : inventaire des données persistantes, méthode de sauvegarde de la base et des fichiers, cohérence entre les deux, nommage et manifeste, chiffrement, rétention, contrôles d'intégrité, restauration isolée, RPO/RTO proposés, checklist GO/NO-GO et intégration avec les lots précédents.
- Hors portée : automatisation planifiée en production (cron, timer), copie hors site, sauvegarde de la configuration serveur, coffre de secrets, restauration de production réelle et migration de données. Ces sujets sont soit interdits dans ce lot, soit explicitement reportés.

> **Statut de ce lot.** Aucun script n'a été exécuté sur un serveur, aucune sauvegarde réelle n'a été produite et **aucune restauration réelle n'a été réalisée**. Les seules vérifications exécutées sont des tests statiques, des tests unitaires sur le manifeste et des tests locaux à outils simulés. En conséquence :
>
> - la fiabilité des sauvegardes **n'est pas démontrée** ;
> - aucun RTO démontré ne peut être annoncé ;
> - aucune migration de classe C, D ou E ne peut être approuvée en production sur la base de ce document seul ;
> - la procédure de restauration est **prête à être testée**, pas validée.

Le mode opératoire pas-à-pas destiné à l'administrateur est dans [`backup-restore-runbook.md`](backup-restore-runbook.md). Ce document fixe les règles ; le runbook décrit les gestes.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Sauvegarde, intégrité, rétention, restauration | Ce document |
| Gestes opérateur et checklists d'exécution | [`backup-restore-runbook.md`](backup-restore-runbook.md) |
| Migrations, compatibilité N/N-1 et rollback applicatif | [`database-migrations.md`](database-migrations.md) |
| Déploiements, releases et activation de `current` | [`deployment-process.md`](deployment-process.md) |
| Environnements, isolation et permissions | [`environments.md`](environments.md) |
| Versionnement et releases | [`release-process.md`](release-process.md) |
| Branches, commits et Pull Requests | [`git-workflow.md`](git-workflow.md) |
| Règles impératives | [`AGENTS.md`](../../AGENTS.md) |
| Schéma du manifeste | [`scripts/ops/schema/backup-manifest.schema.json`](../../scripts/ops/schema/backup-manifest.schema.json) |
| Validateur du manifeste | [`scripts/ops/lib/manifest.php`](../../scripts/ops/lib/manifest.php) |
| Scripts d'exploitation | [`scripts/ops`](../../scripts/ops) |
| Tests de la stratégie | [`tests/Unit/Backup`](../../tests/Unit/Backup) et [`scripts/ops/tests`](../../scripts/ops/tests) |

En cas de divergence entre ce document et un manifeste réellement produit, le manifeste et le journal d'exploitation font foi. Une divergence doit être constatée et corrigée ; elle ne doit jamais être corrigée par une modification manuelle silencieuse d'un manifeste.

## Sommaire

1. [Principes directeurs](#1-principes-directeurs)
2. [Inventaire des données persistantes](#2-inventaire-des-données-persistantes)
3. [Définition d'une sauvegarde valide](#3-définition-dune-sauvegarde-valide)
4. [Cohérence entre la base et les fichiers](#4-cohérence-entre-la-base-et-les-fichiers)
5. [Sauvegarde de la base de données](#5-sauvegarde-de-la-base-de-données)
6. [Sauvegarde des fichiers](#6-sauvegarde-des-fichiers)
7. [Jeu de sauvegarde, nommage et manifeste](#7-jeu-de-sauvegarde-nommage-et-manifeste)
8. [Chiffrement, stockage et permissions](#8-chiffrement-stockage-et-permissions)
9. [Contrôle d'intégrité](#9-contrôle-dintégrité)
10. [Rétention et protection contre la suppression](#10-rétention-et-protection-contre-la-suppression)
11. [RPO, RTO et fréquences](#11-rpo-rto-et-fréquences)
12. [Restauration isolée](#12-restauration-isolée)
13. [Rapport de restauration et conservation des preuves](#13-rapport-de-restauration-et-conservation-des-preuves)
14. [Checklist GO / NO-GO](#14-checklist-go--no-go)
15. [Intégration avec CHAN-97 et le lot 1](#15-intégration-avec-chan-97-et-le-lot-1)
16. [Tests et contrôles](#16-tests-et-contrôles)
17. [Décisions, prérequis et limites](#17-décisions-prérequis-et-limites)
18. [Références](#18-références)

## 1. Principes directeurs

1. **Une sauvegarde n'est valide que si elle est complète, cohérente, chiffrée, manifestée et vérifiée.** Un fichier présent sur le disque ne suffit pas.
2. **Le jeu de sauvegarde de référence est complet : base de données et fichiers, pris dans la même opération.** Un dump de base seul n'est jamais présenté comme une sauvegarde restaurable de l'application.
3. **Le serveur n'est pas une destination de confiance pour la clé privée.** La clé de déchiffrement ne réside jamais sur le serveur, ni dans le dépôt, ni dans une release.
4. **La restauration est une opération d'exploitation explicite.** Elle n'est jamais automatique, jamais déclenchée par un déploiement et jamais exécutée sur une base active de staging ou de production.
5. **Une cible de restauration est toujours neuve.** Une base ou un répertoire préexistant n'est jamais réutilisé : la cible porte un identifiant unique et son existence bloque l'opération.
6. **Aucune suppression implicite.** Une sauvegarde n'est jamais écrasée, jamais supprimée par une rotation silencieuse et jamais supprimée si elle a servi de preuve de restauration.
7. **Aucun secret dans une sauvegarde métier.** `.env`, configuration compilée et export des droits MySQL sont exclus et relèvent d'une procédure de conservation séparée.
8. **Aucune preuve n'est supposée.** Un test d'intégrité ne prouve pas la restaurabilité ; un test sur un autre moteur ne prouve pas MariaDB 10.11 ; une restauration sur le même serveur ne prouve pas la reprise après perte de serveur.
9. **Le doute profite au blocage.** Si la cohérence, l'intégrité, l'espace disque ou les permissions ne peuvent pas être garantis, la sauvegarde ou la restauration échoue explicitement.
10. **La documentation décrit un état vérifiable.** Toute affirmation de fiabilité doit renvoyer à un manifeste, un checksum, un journal et un rapport de restauration datés.

## 2. Inventaire des données persistantes

### 2.1 Données incluses dans le jeu de sauvegarde

| Donnée | Emplacement | Criticité | Justification |
| --- | --- | --- | --- |
| Comptes, migrations, futures tables métier | base `chantier_production` ou `chantier_staging` | Critique | Source de vérité applicative |
| Sessions, cache, verrous, jobs, jobs échoués | mêmes bases | Opérationnelle | Reprise des traitements et des sessions ; inclus dans le dump complet |
| Pièces jointes privées, documents métier | `shared/storage/app/private` | Critique | Données non reconstructibles |
| Fichiers publics téléversés | `shared/storage/app/public` | Importante | Référencés par la base et servis publiquement |
| Métadonnées de release | `releases/current/release.json` | Traçabilité | Recopiées dans le manifeste, pas archivées comme données |

### 2.2 Données explicitement exclues

| Donnée | Emplacement | Raison |
| --- | --- | --- |
| Code applicatif et dépendances | `releases/<release-id>` | Reconstructible depuis Git, le tag et l'artefact GitHub |
| Configuration compilée | `bootstrap/cache/config.php` | Contient des secrets en clair |
| Secrets d'environnement | `shared/.env` | Secret ; procédure de conservation séparée (§2.4) |
| Cache, sessions et vues compilées | `shared/storage/framework/*` | Reconstructible ; le mode maintenance dépose un marqueur ici |
| Journaux applicatifs | `shared/storage/logs` | Diagnostique, volumineux, peut contenir des données personnelles ; archivage séparé à rétention courte |
| Configuration serveur | aaPanel, Nginx, PHP-FPM, Supervisor, cron | Hors périmètre automatisé ; inventaire et export manuel (§2.4) |
| Utilisateurs et droits MySQL | serveur MariaDB | Export séparé chiffré (§2.4) |
| Artefacts et manifestes de déploiement | GitHub Actions | Conservés 90 jours par la plateforme |

### 2.3 Séparation staging / production

| Élément | Staging | Production |
| --- | --- | --- |
| Racine | `/www/wwwroot/chantier-staging.c2me.ovh` | `/www/wwwroot/chantier.c2me.fr` |
| Base | `chantier_staging` | `chantier_production` |
| Racine de sauvegarde | `/var/backups/c2me/staging` | `/var/backups/c2me/production` |
| Clé de chiffrement | Destinataire `age` dédié | Destinataire `age` dédié |
| Compte de sauvegarde | Compte technique distinct | Compte technique distinct |

Règles :

- les deux racines de sauvegarde sont distinctes, sans lien symbolique et sans montage croisé ;
- une sauvegarde de production n'est jamais lisible ni montée depuis staging ;
- une sauvegarde de production n'est restaurée en staging qu'après anonymisation irréversible, conformément à [`environments.md`](environments.md) ; en pratique, le jeu de recette doit être reconstruit à partir de données fictives ;
- une sauvegarde de staging n'est jamais importée en production.

### 2.4 Données exclues mais indispensables à une reprise complète

Ces éléments ne sont pas dans le jeu métier, mais leur absence rend une reprise incomplète. Ils relèvent d'une **procédure de conservation séparée**, documentée dans le runbook et non automatisée par ce lot :

- `shared/.env` de chaque environnement, conservé dans un coffre de secrets hors serveur, avec une procédure de restauration contrôlée ;
- export des utilisateurs et `GRANT` MySQL, chiffré séparément, contenant des empreintes de mots de passe ;
- configuration aaPanel/Nginx/PHP-FPM/Supervisor et entrées cron, inventoriées et exportées manuellement ;
- destination et identifiants de la copie hors site, lorsqu'elle existera.

Aucun de ces éléments n'est inclus dans les archives métier, même chiffrées, afin qu'une fuite de clé de sauvegarde ne compromette pas les secrets d'exploitation.

## 3. Définition d'une sauvegarde valide

Une sauvegarde est **valide** si et seulement si les conditions suivantes sont réunies :

1. l'opération porte sur un **jeu complet** : un artefact base et un artefact fichiers issus de la même exécution ;
2. l'opération s'est déroulée pendant une fenêtre où les écritures applicatives étaient arrêtées et où les workers et tâches planifiées étaient vérifiés inactifs ;
3. aucun fichier du périmètre n'a changé entre l'inventaire initial et l'inventaire final ;
4. chaque artefact a été compressé, vérifié, chiffré puis haché ;
5. le manifeste est présent, conforme au schéma, et son propre checksum est vérifié ;
6. l'espace disque et les permissions de destination étaient conformes ;
7. le journal d'exécution ne contient aucune erreur et se termine par un statut `complete`.

Conséquences :

- **un dump de base seul n'est pas une sauvegarde complète** ; il peut exister pour un diagnostic ou une analyse, avec `scope: database-only` et `restorable_as_complete: false`, et il ne peut jamais servir de preuve de restauration applicative ;
- une archive de fichiers seule ne restaure pas la base et n'est jamais présentée comme suffisante ;
- un artefact sans manifeste, ou dont le manifeste est invalide, est traité comme inexistant ;
- une exécution interrompue ne produit aucune sauvegarde : le répertoire de travail est supprimé, jamais promu en jeu valide.

## 4. Cohérence entre la base et les fichiers

### 4.1 Mode maintenance obligatoire

Le jeu de sauvegarde est produit pendant une fenêtre d'arrêt des écritures :

1. activer le mode maintenance de l'application ;
2. mettre en pause les files d'attente ;
3. arrêter les workers supervisés ;
4. neutraliser les tâches planifiées ;
5. vérifier l'absence de traitement en cours ;
6. produire le jeu complet ;
7. rétablir les workers, les files et les tâches planifiées ;
8. désactiver le mode maintenance.

Le mode maintenance Laravel **ne suffit pas** : il bloque les requêtes HTTP entrantes, mais ni les workers de file, ni le cron `schedule:run`, ni un script d'administration. L'arrêt doit donc être vérifié, pas supposé.

### 4.2 Vérification effective des workers

Le script de sauvegarde refuse de démarrer si l'un des contrôles suivants échoue :

- un programme Supervisor configuré (`C2ME_SUPERVISOR_PROGRAM`) est encore dans l'état `RUNNING` ou `STARTING` ;
- aucun programme Supervisor n'est configuré **et** l'opérateur n'a pas fourni la confirmation explicite `--confirm-workers-stopped` ;
- un processus `queue:work`, `queue:listen` ou `horizon` appartenant à l'environnement est encore actif.

La confirmation explicite est une déclaration d'opérateur, pas une preuve : elle est enregistrée dans le manifeste (`workers_verified`) et doit être justifiée dans le ticket d'exploitation.

### 4.3 Vérification des tâches planifiées

Le cron `schedule:run` est une entrée système, hors du contrôle du script. La sauvegarde exige :

- la neutralisation de l'entrée cron de l'environnement avant l'opération ;
- la confirmation explicite `--confirm-scheduler-disabled` ;
- l'absence de tâche `schedule:run` en cours d'exécution au moment du contrôle.

Le rétablissement de l'entrée cron est une étape du runbook, vérifiée par la suite. Aucune commande ne modifie le cron automatiquement dans ce lot.

### 4.4 Détection de modification de fichiers pendant l'opération

L'inventaire et l'archive doivent porter sur **le même état** du système de fichiers :

1. l'inventaire A est produit avant l'archivage : chemins, tailles, dates de modification, modes et SHA-256 de chaque fichier ;
2. l'archive est créée à partir de la liste de fichiers figée issue de l'inventaire A ;
3. l'inventaire B est recalculé après la création de l'archive ;
4. si A et B diffèrent — apparition, disparition, changement de taille, de date, de mode ou de contenu — la sauvegarde **échoue** et le jeu est marqué en échec ;
5. le nombre d'entrées de l'archive est comparé au nombre d'entrées de l'inventaire.

L'inventaire A est conservé comme artefact du jeu (`inventory.sha256` et `inventory.meta`), avec son propre checksum dans le manifeste. La commande `verify` contrôle les artefacts et leurs empreintes ; la confrontation complète du contenu à l'inventaire est réalisée à la restauration, avant l'application des permissions.

### 4.5 Ce qui reste non détectable

- Une écriture qui modifie un fichier puis le resta à l'identique entre l'inventaire A et l'inventaire B n'est pas détectée ; elle est sans effet sur le contenu sauvegardé.
- Une écriture directe dans la base par un accès SQL non applicatif pendant le dump n'est pas visible dans le manifeste. Elle est limitée par la fenêtre de maintenance et la vérification des accès.
- Un accès réseau à un stockage externe (S3, etc.) n'est pas couvert par ce lot : aucun stockage objet n'est utilisé à ce jour.

En cas de doute sur la fenêtre (worker découvert après coup, cron non neutralisé), le jeu est **invalidé** et un nouveau jeu est produit.

## 5. Sauvegarde de la base de données

### 5.1 Méthode retenue

**Dump logique `mariadb-dump` avec `--single-transaction`.**

Justification :

- le volume actuel est très faible ; une sauvegarde physique (`mariabackup`) n'apporte aucun gain de durée et ajoute une dépendance, des privilèges supplémentaires et une contrainte de compatibilité de version ;
- `--single-transaction` fournit un instantané cohérent des tables InnoDB sans bloquer les écritures ;
- le dump est portable, inspectable, relisible par un humain et permet une restauration table par table ;
- il se compresse, se chiffre et se hache simplement, avec un résultat déterministe vérifiable.

La sauvegarde physique reste une option documentée si la base dépasse les seuils proposés (plus de 5 Go, ou RTO cible inférieur à 30 minutes). Elle exigerait une nouvelle décision, une répétition et des tests dédiés.

### 5.2 Préflight obligatoire

Avant tout dump :

1. `mariadb-dump` et le client `mariadb` sont présents et exécutables ;
2. leur version majeure correspond à celle du serveur (MariaDB 10.11) ;
3. un fichier d'options MySQL dédié, en `0600`, fournit les identifiants ; aucun mot de passe n'est passé en argument ;
4. l'utilisateur de sauvegarde ne dispose que des privilèges de lecture nécessaires ;
5. **toutes les tables de l'application sont en InnoDB** ; la requête `information_schema.tables` ne doit retourner aucune table d'un autre moteur ;
6. la base contient au moins une table et la table `migrations` est lisible ;
7. l'espace disque libre est au moins égal à 2,5 fois la taille estimée du jeu ;
8. aucune autre sauvegarde ou restauration n'est en cours (verrou) ;
9. aucune migration n'est en cours et aucune migration n'est planifiée pendant la fenêtre ;
10. le serveur MariaDB ne signale pas de transaction longue susceptible de bloquer le dump.

Une table non InnoDB rend le dump à chaud non cohérent : la sauvegarde est refusée. Aucune sauvegarde « au mieux » n'est produite.

### 5.3 Options du dump

Options de référence (à confirmer par `mariadb-dump --help` sur le serveur, jamais supposées) :

```text
--single-transaction
--quick
--routines
--events
--triggers
--default-character-set=utf8mb4
--hex-blob
--skip-add-locks
--no-tablespaces
```

Règles complémentaires :

- le dump est produit **sans** `--force` et **sans** `--ignore-error` : une erreur interrompt l'opération ;
- la base ciblée est explicite et doit correspondre à l'environnement résolu ;
- les options effectivement utilisées sont hachées dans le manifeste (`options_sha256`) pour permettre de comparer deux exécutions ;
- aucun `--where`, aucun filtre de table : un dump partiel n'est pas une sauvegarde complète ;
- la version de l'outil et celle du serveur sont enregistrées.

### 5.4 Interruptions et sauvegardes incomplètes

- Le dump est écrit dans un fichier `.partial` en zone de travail `0700`.
- Le piège `EXIT` assure le nettoyage en toutes circonstances. Les signaux `HUP`, `INT` et `TERM` sont traités par des gestionnaires dédiés qui, avant tout nettoyage :
  1. identifient les processus enfants et descendants (PID suivis par les opérations critiques et arbre de processus) ;
  2. envoient `TERM` aux processus concernés ;
  3. attendent leur terminaison réelle, avec escalade `KILL` après un délai borné ;
  4. seulement ensuite, suppriment la zone de travail et libèrent le verrou, puis terminent avec `129`, `130` ou `143`.
- Les commandes critiques (`mariadb-dump`, `age`, `tar`, `zstd`/`gzip` en compression **et décompression**, import `mariadb`) sont exécutées via `c2me_run`, qui suit le PID de l'enfant. Le verrou n'est jamais libéré tant qu'un processus enfant peut encore écrire.
- Aucune opération ne reprend après le nettoyage.
- Si le processus est tué par `SIGKILL`, aucun gestionnaire ne s'exécute : le verrou et le répertoire de travail peuvent subsister. La procédure de verrou orphelin (§10.4) s'applique ; le répertoire `incoming/` est examiné et jamais promu.
- Aucun renommage final n'a lieu avant la vérification de compression, le chiffrement et le calcul du checksum.
- Un artefact incomplet n'est jamais déplacé dans `sets/`. Le répertoire de travail est supprimé par le piège de sortie, y compris après un échec, car il peut contenir un dump en clair ; seul le journal d'exploitation conserve la trace. Aucun artefact incomplet n'est conservé.
- Un échec du dump n'entraîne jamais la suppression d'un jeu antérieur.

### 5.5 Ce que le dump ne contient pas

- les utilisateurs et droits MySQL (export séparé) ;
- les tables système (`mysql`, `performance_schema`, `information_schema`, `sys`) ;
- les fichiers déposés (traités par l'archive fichiers) ;
- les secrets de configuration (`.env`, configuration compilée) ;
- les journaux applicatifs.

## 6. Sauvegarde des fichiers

### 6.1 Périmètre

Inclus :

- `shared/storage/app/private` ;
- `shared/storage/app/public`.

Exclus :

- `shared/storage/framework/cache`, `framework/sessions`, `framework/views` ;
- `shared/storage/logs` ;
- `*.part`, `*.partial` et fichiers temporaires connus ;
- tout fichier hors de `shared/storage` (aucune remontée, aucun chemin absolu).

### 6.2 Méthode

- `tar` en flux, avec une liste de chemins figée issue de l'inventaire A ;
- `--no-recursion` : seules les entrées listées sont ajoutées, sans parcours implicite ;
- `--format=gnu` lorsque l'outil le permet, avec `--numeric-owner` et `--one-file-system` ;
- **ni `--acls` ni `--xattrs`** : aucun besoin métier ne les justifie et ils introduisent des en-têtes PAX supplémentaires ; les permissions sont remappées à la restauration ;
- **jamais `-h`** : les liens symboliques sont enregistrés comme liens, jamais suivis ;
- compression (`zstd` si disponible, sinon `gzip`) puis chiffrement `age`.

### 6.3 Liens symboliques et fichiers spéciaux

Avant l'archivage :

- tout lien symbolique dans le périmètre inclus provoque un **NO-GO** ; aucun lien légitime n'est attendu dans les données métier ;
- tout fichier spécial (socket, FIFO, périphérique), tout lien physique sortant du périmètre et tout fichier non lisible provoque un **NO-GO** ;
- un fichier qui change de taille ou de date pendant le calcul de l'inventaire provoque un **NO-GO** (inventaire instable).

### 6.4 Permissions

Les modes sont enregistrés dans l'archive et dans l'inventaire. Ils ne sont **pas** appliqués tels quels lors d'une restauration : la restauration remappe l'appartenance vers le compte et le groupe de l'environnement de restauration et applique une politique de modes explicite (§12.4). Aucun mode `777` n'est jamais appliqué ni accepté.

### 6.5 Inventaire

Deux fichiers sont produits :

- `inventory.sha256` : format `sha256sum` (`<empreinte>  <chemin relatif>`), trié en ordre ASCII ;
- `inventory.meta` : chemin, taille, date de modification, mode, type.

Leur nombre d'entrées doit correspondre au nombre d'entrées de l'archive. `inventory.sha256` est vérifié après restauration par `sha256sum -c` depuis la racine restaurée.

## 7. Jeu de sauvegarde, nommage et manifeste

### 7.1 Structure d'un jeu

```text
/var/backups/c2me/<environnement>/
├── incoming/                             travaux en cours, 0700
├── sets/
│   └── set-<env>-<AAAAMMJJTHHMMSSZ>-<hex8>/
│       ├── db-<env>-<AAAAMMJJTHHMMSSZ>-<version>-<commit7>-<trigger>.sql.<ext>.age
│       ├── files-<env>-<AAAAMMJJTHHMMSSZ>-<version>-<commit7>-<trigger>.tar.<ext>.age
│       ├── inventory.sha256
│       ├── inventory.meta
│       ├── manifest.json
│       ├── manifest.json.sha256
│       └── SHA256SUMS
├── expired/                             quarantaine avant suppression
├── ledger/
│   ├── restore-reports/                 rapports de restauration
│   ├── restore-state/                   résultats des restaurations
│   └── chain.jsonl                      chaîne d'intégrité des rapports
├── keys/recipient.pub                   clé publique age uniquement
└── ops.log                              journal d'exploitation (ajout seul)
```

### 7.2 Convention de nommage

| Élément | Format | Exemple |
| --- | --- | --- |
| Identifiant de jeu | `set-<env>-<YYYYMMDDTHHMMSSZ>-<hex8>` | `set-production-20261113T020000Z-a1b2c3d4` |
| Artefact base | `db-<env>-<horodatage>-<version>-<commit7>-<trigger>.sql.<ext>.age` | `db-production-20261113T020000Z-v0.1.0-8742e19-scheduled.sql.zst.age` |
| Artefact fichiers | `files-<env>-<horodatage>-<version>-<commit7>-<trigger>.tar.<ext>.age` | `files-production-20261113T020000Z-v0.1.0-8742e19-scheduled.tar.zst.age` |
| Déclencheur | `scheduled`, `pre-migration`, `manual`, `pre-restore` | `pre-migration` |
| Compression | `zst` ou `gz` | `zst` |

Contraintes :

- caractères autorisés : `a-z`, `0-9`, `-`, `_`, `.` ; aucun espace, aucun accent, aucun séparateur de chemin ;
- horodatage en UTC, jamais en heure locale ;
- version et commit issus de `release.json` ; en l'absence de `release.json` lisible, la valeur littérale `unknown` est utilisée et signalée ;
- `<hex8>` est aléatoire et garantit l'unicité même pour deux exécutions dans la même seconde ;
- un nom existant n'est jamais réutilisé ni écrasé.

### 7.3 Manifeste

Le manifeste est un JSON à schéma strict, versionné, validé par [`scripts/ops/lib/manifest.php`](../../scripts/ops/lib/manifest.php) et décrit par [`scripts/ops/schema/backup-manifest.schema.json`](../../scripts/ops/schema/backup-manifest.schema.json). Champs obligatoires :

| Champ | Contenu |
| --- | --- |
| `schema_version` | `1` |
| `backup_set_id` | Identifiant du jeu, cohérent avec le nom du répertoire et l'environnement |
| `environment` | `staging` ou `production` |
| `created_at`, `completed_at` | UTC ISO 8601 `YYYY-MM-DDTHH:MM:SSZ` |
| `trigger` | `scheduled`, `pre-migration`, `manual` ou `pre-restore` |
| `scope` | `full` ou `database-only` |
| `restorable_as_complete` | `true` uniquement pour un jeu `full` complet |
| `status` | `complete` ; un manifeste `incomplete` n'est jamais placé dans `sets/` |
| `consistency` | Mode, vérifications workers/cron, modifications détectées |
| `release` | Version, commit, arbre |
| `database` | Nom, version serveur, outil, options, tables, lignes |
| `files` | Racines incluses, exclusions, nombre de fichiers, octets, checksum d'inventaire |
| `artifacts[]` | Type, nom, octets, SHA-256, compression, chiffrement, destinataire |
| `retention` | Classe et échéance de retrait |
| `host` | Identifiant d'hôte, opérateur ou `automated` |

Le manifeste ne contient **aucun** secret, aucune clé privée, aucun mot de passe, aucun contenu de fichier. Le validateur refuse toute clé dont le nom évoque un secret (`password`, `secret`, `private_key`, `identity`, `passphrase`).

Le manifeste est écrit **en dernier**, après tous les contrôles. Son propre SHA-256 est écrit dans `manifest.json.sha256`. `SHA256SUMS` liste tous les artefacts du jeu. Un manifeste modifié invalide le jeu.

## 8. Chiffrement, stockage et permissions

### 8.1 Chiffrement

- Outil : `age`, avec un destinataire par environnement.
- Le serveur ne détient que la **clé publique** (`keys/recipient.pub`).
- La clé privée est conservée hors serveur, dans un coffre avec au moins deux détenteurs et une procédure de secours ; elle n'est jamais copiée dans le dépôt, une release, `shared/` ou un répertoire de sauvegarde.
- Un opérateur qui restaure fournit temporairement la clé privée, en `0600`, depuis un emplacement autorisé (mémoire ou répertoire personnel), puis la retire.
- Le script de restauration refuse une clé située sous une racine publiée, une release, `shared/` ou la racine de sauvegarde.
- Une sauvegarde créée sans chiffrement est refusée : il n'existe pas d'option « non chiffré ».
- Le bénéficiaire et l'empreinte de la clé publique sont enregistrés dans le manifeste.

### 8.2 Emplacement

- Racine de sauvegarde hors de la racine applicative : `/var/backups/c2me/<environnement>`.
- Le répertoire est préparé par l'administrateur, propriété du compte de sauvegarde et du groupe de l'environnement, en `2750` ; `incoming/` en `2770` pour l'écriture temporaire.
- Aucune sauvegarde n'est écrite dans `releases/`, `current/`, `public/` ou `shared/storage/`.
- Aucune sauvegarde n'est servie par le vhost : la racine de sauvegarde est hors DocumentRoot.
- La copie hors site est **reportée** (§17). En son absence, la perte complète du serveur est un **NO-GO** explicite.

### 8.3 Permissions et comptes

| Chemin | Propriétaire | Mode | Justification |
| --- | --- | --- | --- |
| `/var/backups/c2me` | `root` | `0755` | conteneur neutre |
| `/var/backups/c2me/<env>` | compte de sauvegarde : groupe env | `2750` | lecture et traversée contrôlées |
| `incoming/` | compte de sauvegarde : groupe env | `2770` | écriture temporaire |
| `sets/<id>/` | compte de sauvegarde : groupe env | `2750` | jeux en lecture seule |
| fichiers d'un jeu | compte de sauvegarde : groupe env | `0640` | lecture contrôlée |
| `keys/recipient.pub` | compte de sauvegarde : groupe env | `0644` | clé publique |
| `ledger/` | compte de sauvegarde : groupe env | `2750` | preuves |

- Le compte de sauvegarde est distinct du compte de déploiement et ne dispose d'aucun `sudo`.
- Il lit `shared/storage` (traversée et lecture) mais n'y écrit jamais.
- Il n'a aucun accès à l'autre environnement.
- Les identifiants MySQL proviennent d'un fichier d'options en `0600`, jamais d'un argument de commande ni d'une variable exportée dans un journal.
- L'hôte doit posséder un nom **stable, unique et non réservé** (`hostname -s` non vide, différent de `unknown`, `localhost` et `localhost.localdomain`) ou une variable `C2ME_HOST_ID` explicite respectant les mêmes règles. Une identité explicitement invalide n'est jamais remplacée par l'identité détectée. Une identité inconnue empêche la prise de verrou : les verrous ne sont jamais rattachés à un hôte ambigu.

### 8.4 Données déchiffrées

- Le déchiffrement n'a lieu que pendant une restauration, dans une zone de travail `0700` sous `/var/tmp/c2me-restore` ou en mémoire.
- Aucune donnée déchiffrée n'est écrite dans une release, dans `public/`, dans `shared/storage/` ou dans la racine de sauvegarde.
- Le script vérifie que le chemin résolu de la zone de travail ne se trouve sous aucune de ces racines avant d'écrire.
- La zone de travail est supprimée à la fin, y compris après un échec, par un piège `EXIT`, et par les gestionnaires `HUP`, `INT` et `TERM`. Un résidu éventuel est signalé et jamais réutilisé.
- Les fichiers déchiffrés ne sont jamais copiés dans un répertoire accessible par le vhost.

### 8.5 Détection d'une clé privée déposée par erreur

Avant chaque sauvegarde, le script recherche des fichiers dont le **nom** correspond à `age-identity*`, `*.agekey` ou `keys.txt`, sous la racine applicative et sous la racine de sauvegarde, à l'exclusion de `keys/recipient.pub`. Une correspondance bloque l'opération.

Ce contrôle est un **garde-fou heuristique, pas une preuve d'absence** :

- il ne lit pas le contenu des fichiers et ne détecte pas une clé renommée, encodée, stockée dans une base, un fichier de configuration, une variable d'environnement, un historique de shell ou un autre système de fichiers ;
- il ne couvre ni les volumes montés ailleurs, ni les sauvegardes externes, ni les postes des opérateurs ;
- il ne remplace pas la règle absolue : la clé privée n'est jamais stockée sur le serveur, dans une release, `shared/`, la racine de sauvegarde ou le dépôt.

L'absence de correspondance ne doit donc jamais être présentée comme une garantie. La conformité repose sur la procédure d'exploitation, la garde de la clé hors serveur et la revue des accès.

## 9. Contrôle d'intégrité

### 9.1 Contrôles automatiques après écriture

1. code retour de chaque outil (dump, archive, compression) ;
2. test d'intégrité de la compression (`zstd -t` ou `gzip -t`) **avant** chiffrement ;
3. taille non nulle et cohérente avec l'estimation ;
4. SHA-256 de chaque artefact chiffré, recalculé après écriture ;
5. SHA-256 du manifeste ;
6. vérification du manifeste par le validateur de schéma ;
7. comparaison des inventaires A et B ;
8. comparaison du nombre d'entrées de l'archive et de l'inventaire.

### 9.2 Contrôles à la demande

`backup.sh verify <jeu>` vérifie :

- présence de tous les artefacts listés ;
- SHA-256 de chaque artefact contre le manifeste et `SHA256SUMS` ;
- validité du manifeste et de son checksum ;
- cohérence du nommage et de l'environnement ;
- cohérence de `scope` et de `restorable_as_complete`.

### 9.3 Limite du contrôle sans clé privée

Le serveur ne peut pas déchiffrer une sauvegarde : il ne peut donc pas prouver qu'un artefact est déchiffrable. Cette vérification est réalisée :

- par un **test de déchiffrement mensuel** effectué par un détenteur de clé, sur un jeu désigné, avec rapport ;
- et obligatoirement lors d'une restauration isolée, dont le rapport constitue la preuve.

Un jeu dont le déchiffrement n'a jamais été testé reste **non prouvé**, même si tous ses checksums sont valides.

### 9.4 Altération

Une altération, même d'un octet, est détectée par le SHA-256. Le jeu est alors déclaré **invalide**, retiré de la liste des jeux restaurables et conservé pour analyse. Il n'est jamais « réparé » par recalcul du checksum.

## 10. Rétention et protection contre la suppression

### 10.1 Politique proposée

| Classe | Producteur | Rétention proposée |
| --- | --- | --- |
| `daily` | Jeu complet quotidien | 30 jours |
| `monthly` | Jeu complet du premier jour du mois | 12 mois |
| `pre-migration` | Avant une migration de classe C, D ou E | Jusqu'à clôture de la fenêtre de rollback, minimum 30 jours |
| `manual` | Opération exceptionnelle | 30 jours, prolongeable par décision écrite |

Chaque jour produit **un jeu complet** (base + fichiers). Il n'existe pas de jour où seuls les fichiers ou seule la base seraient sauvegardés comme mécanisme principal. Une archive de fichiers hebdomadaire peut être ajoutée plus tard comme optimisation de volume, jamais comme unique protection des fichiers métier.

### 10.2 Suppression

- La suppression est une sous-commande explicite (`prune`), en simulation par défaut.
- `--confirm` est obligatoire pour agir.
- Les jeux sortants sont d'abord déplacés dans `expired/`, puis supprimés seulement après une seconde commande explicite et un délai de quarantaine de 7 jours.
- Ne sont jamais supprimés : le jeu le plus récent, un jeu référencé par un rapport de restauration, un jeu `pre-migration` non clos, un jeu dont l'intégrité est en cours d'analyse.
- Un jeu n'est jamais écrasé : la création échoue si le répertoire cible existe.

### 10.3 Protection contre la suppression accidentelle

- compte dédié, sans droit de suppression sur `sets/` en dehors de `prune` ;
- quarantaine obligatoire ;
- journal d'exploitation en ajout seul ;
- copie hors site (reportée) destinée à couvrir la suppression locale et la perte de serveur ;
- revue périodique de la liste des jeux et des rapports de restauration.

### 10.4 Verrou orphelin

Une interruption brutale (`SIGKILL`, arrêt du serveur, coupure) peut laisser le répertoire `<BACKUP_ROOT>/.lock` sans que le piège de sortie ait pu s'exécuter. Le verrou contient le PID, l'horodatage de prise et l'hôte.

Règles :

- un verrou existant n'est **jamais supprimé automatiquement** ;
- l'identité d'hôte locale doit être **stable, unique et non réservée** ; `unknown`, une valeur vide, `localhost`, `localhost.localdomain` et un hostname non résolu ne sont jamais acceptés. La prise d'un verrou est refusée si l'identité locale n'est pas fiable ; une valeur explicitement invalide n'est jamais remplacée silencieusement ;
- le champ `host` est lu et validé ; un verrou sans hôte, vide ou égal à `unknown`, ou dont l'hôte diffère de l'hôte courant, est refusé : un PID distant ne constitue jamais une preuve de processus mort ;
- sur l'hôte enregistré, le script vérifie si le PID est encore vivant (`kill -0`) ;
- PID vivant : l'opération est refusée comme concurrente ; la libération est également refusée ;
- PID absent, illisible ou mort sur le même hôte : l'opération est refusée avec la mention « verrou orphelin » et la commande de récupération ;
- la récupération est explicite : `backup.sh unlock --env <env> --confirm-stale-lock` (ou `restore.sh unlock`), après vérification humaine qu'aucune sauvegarde ou restauration n'est en cours ;
- un verrou provenant d'un autre hôte ne peut pas être libéré localement : la vérification doit être faite sur cet hôte, puis le verrou y est retiré après confirmation ; si l'hôte n'existe plus, la décision est prise par l'administrateur et consignée dans le ticket ;
- avant libération, vérifier l'absence de processus `backup.sh`/`restore.sh` et l'état de `incoming/` ; un répertoire de travail résiduel est analysé puis supprimé manuellement, jamais promu dans `sets/` ;
- un PID réutilisé par un autre processus est un cas de faux positif possible ; la confirmation humaine reste obligatoire.

## 11. RPO, RTO et fréquences

Ces valeurs sont des **propositions à valider**, pas des engagements approuvés.

| Indicateur | Proposition | Statut |
| --- | --- | --- |
| RPO planifié | 24 heures | **Cible**, pas une garantie : dépend de l'exécution quotidienne et de la supervision, qui ne sont pas opérationnelles dans ce lot |
| RPO avant opération risquée | 0 (jeu complet pris immédiatement avant) | Cible, dépend de l'exécution effective du runbook |
| RTO cible | 4 heures | Cible technique, sur un volume faible |
| RTO réaliste annoncé | 1 jour ouvré | Dépend de la disponibilité de l'administrateur (opérateur unique) |
| RTO démontré | **aucun** | Aucune restauration réelle n'a été réalisée à ce jour |
| Fréquence | 1 jeu complet par jour ; jeu complet avant toute opération risquée | Proposition |
| Rétention | 30 quotidiens, 12 mensuels, pré-migration selon fenêtre de rollback | Proposition |
| Test de restauration | Mensuel en environnement isolé, et obligatoire avant toute migration de classe D | Proposition |
| Test de déchiffrement | Mensuel | Proposition |

Règles :

- un RPO de 24 heures n'est une garantie qu'à partir du moment où l'exécution quotidienne, la supervision et les alertes sont en place et prouvées ;
- le RTO démontré est mesuré lors d'une restauration réelle et consigné ; il ne se déduit pas du RTO cible ;
- si un RPO inférieur à une heure devient nécessaire, l'activation du journal binaire (`binlog`) et d'une restauration point-in-time devient indispensable ; ce périmètre n'est pas couvert ;
- tant qu'aucune copie hors site n'existe, la perte complète du serveur est un **NO-GO** documenté, sans exception.

## 12. Restauration isolée

### 12.1 Principes d'isolation

- La restauration ne touche **jamais** la base active de staging ou de production.
- La base cible porte un identifiant unique : `chantier_restore_<AAAAMMJJ>_<hex8>`.
- La cible est **créée par l'opération** ; si elle existe déjà, la restauration est refusée.
- Le répertoire cible des fichiers est neuf, en dehors de toute racine applicative, hors `releases/`, `current/`, `public/` et `shared/storage/`.
- L'utilisateur MySQL de restauration ne possède de droits que sur la base cible, jamais sur les bases applicatives.
- Aucun vhost public n'est créé. La vérification applicative se fait en localhost ou en ligne de commande.
- L'isolation est **logique** lorsque la restauration a lieu sur le même serveur. Elle ne prouve pas la reprise après perte du serveur.

### 12.2 Gardes obligatoires

Le script de restauration refuse notamment :

- un jeu inexistant, invalide, incomplet ou d'un autre environnement ;
- un `scope: database-only` pour une restauration « complète » ;
- une base cible qui ne respecte pas le motif `^chantier_restore_[0-9]{8}_[0-9a-f]{8}$` ;
- une base cible préexistante ;
- une base cible égale à `chantier_production` ou `chantier_staging` ;
- un répertoire cible préexistant, non vide, ou situé sous une racine applicative, une release, un répertoire public ou la racine de sauvegarde ;
- une clé privée absente, lisible par le groupe ou les autres, ou située dans un emplacement interdit ;
- une archive dont une entrée n'est pas un fichier régulier ou un répertoire sous `app/private` ou `app/public` : lien symbolique, lien physique, FIFO, socket, périphérique, entrée spéciale, chemin absolu, composant `.` ou `..`, nom avec barre oblique inverse ou hors périmètre ;
- une archive dont l'en-tête est corrompu, tronqué, sans bloc de fin, ou dont le nombre de fichiers et le volume ne correspondent pas au manifeste ;
- une archive dont les octets situés après le bloc de fin ne sont pas tous nuls : le reste du fichier est parcouru intégralement par blocs, sans limite de 512 Kio ;
- une cible qui ne correspond pas à l'environnement déclaré du jeu, sauf dérogation écrite documentée ;
- un opérateur sans droits suffisants pour appliquer le remappage d'appartenance.

Le contrôle des entrées est réalisé par [`scripts/ops/lib/tar-inspect.php`](../../scripts/ops/lib/tar-inspect.php), qui analyse les en-têtes TAR (nom, préfixe, type, taille, checksum, en-têtes GNU `L` et PAX `x`) **avant toute extraction**. Aucune extraction ne commence si une seule entrée est interdite.

Formats acceptés : **ustar POSIX** et **GNU**. Toute autre valeur de `magic`/`version` est refusée.

Métadonnées acceptées :

| Métadonnée | Traitement |
| --- | --- |
| `L` (nom long GNU) | Acceptée une seule fois, valeur unique sans octet nul interne, terminée par NUL, longueur bornée. Elle ne peut modifier ni le type ni la taille de l'entrée. |
| `K` (lien long GNU) | **Refusée** : aucun lien n'est autorisé dans une archive de restauration. |
| `x` (PAX étendu) | Acceptée une seule fois, clés limitées à `path` et `linkpath`. Toute autre clé est refusée. |
| `g` (PAX global) | **Refusée** : format non nécessaire et insuffisamment borné. |

Sont explicitement refusés, entre autres : `size`, `GNU.sparse.*`, `SCHILY.*`, les ACL, les attributs étendus, les clés dupliquées, les enregistrements PAX mal formés, les longueurs incohérentes, les métadonnées contradictoires ou redondantes, et les métadonnées sans entrée cible. Les tailles et positions sont calculées exactement comme GNU tar (blocs de 512 octets, taille déclarée dans l'en-tête, en-têtes de métadonnées exclus du décompte).

### 12.3 Procédure

1. Sélectionner le jeu par identifiant.
2. Vérifier le manifeste, son checksum et les SHA-256 de tous les artefacts.
3. Préparer la zone de travail `0700` et vérifier son chemin résolu.
4. Déchiffrer puis décompresser les artefacts dans la zone de travail uniquement.
5. Refuser une cible préexistante, créer la base et le répertoire cibles.
6. Restaurer la base, puis contrôler le code retour, le nombre de tables et les lignes par table.
7. Restaurer les fichiers, vérifier l'inventaire, remapper l'appartenance et appliquer les modes.
8. Vérifier les permissions finales, l'absence de lien symbolique et l'absence de `777`.
9. Vérifier la cohérence base/fichiers : fichiers référencés mais absents, fichiers orphelins.
10. Exécuter la vérification applicative en localhost : `/up`, page de connexion, lecture représentative.
11. Produire un rapport de restauration horodaté et chaîné (§13).
12. Nettoyer la zone de travail, conserver la base et le répertoire restaurés pour analyse jusqu'à décision explicite.

### 12.4 Remappage des permissions

L'appartenance d'origine n'est **jamais** appliquée telle quelle : les UID/GID de la source n'ont aucune signification sur la cible et pourraient donner des droits à un compte inattendu.

1. Extraction sans conservation du propriétaire (`--no-same-owner`).
2. Vérification de l'inventaire.
3. Remappage explicite vers le compte et le groupe de l'environnement de restauration, fournis par l'opérateur (`--owner utilisateur:groupe`) ; l'existence du compte et du groupe est vérifiée.
4. Application de la politique de modes : répertoires en `2770`, fichiers en `0640`, exécutables en `0750` lorsqu'ils existent.
5. Contrôle final : aucun élément accessible en écriture aux autres utilisateurs, aucun `777`, aucun élément n'appartenant pas au couple cible.
6. Si le remappage ne peut pas être appliqué, la restauration échoue : aucun mode permissif n'est utilisé comme solution de repli.

### 12.5 Vérification de la cohérence base/fichiers

- Le manifeste fournit le décompte et le checksum d'inventaire, qui sont contrôlés.
- Un rapport liste les fichiers orphelins et les références absentes. Tant qu'aucune table métier ne référence de fichiers, ce contrôle se limite au décompte, à la présence des racines et à l'absence de doublons.
- Dès l'arrivée des premières tables de pièces jointes, le contrôle doit être étendu à une commande applicative dédiée, testée et documentée. Aucune suppression automatique n'est effectuée par ce contrôle.
- Un écart entre base et fichiers est un **résultat**, pas un incident à masquer : il est consigné dans le rapport et arbitré par l'opérateur.

## 13. Rapport de restauration et conservation des preuves

### 13.1 Contenu du rapport

Le rapport est un JSON horodaté qui contient :

- identifiant du jeu, environnement, version et commit ;
- date, opérateur, hôte, version des outils ;
- résultat de chaque contrôle : manifeste, checksums, déchiffrement, restauration base, restauration fichiers, inventaire, permissions, cohérence, vérification applicative ;
- durée mesurée de chaque étape et durée totale (base du RTO démontré) ;
- écarts constatés et décisions prises ;
- mention explicite de ce qui **n'a pas** été vérifié.

### 13.2 Intégrité du rapport

Le rapport n'est **pas signé** au sens cryptographique : aucun mécanisme de signature n'est mis en place dans ce lot, et il ne doit jamais être présenté comme tel. Son intégrité est protégée par :

- l'écriture d'un fichier `.sha256` à côté du rapport ;
- l'ajout d'une ligne dans `ledger/chain.jsonl` contenant le nom du rapport, son SHA-256 et le SHA-256 de l'entrée précédente ;
- l'ajout seul : une entrée n'est jamais modifiée ni supprimée ;
- la copie du rapport hors du serveur avec la sauvegarde qu'il concerne.

Ce mécanisme est **détecteur d'altération**, pas authentifiant : il ne prouve pas l'identité de l'auteur. Une signature réelle (`age`/`minisign`/GPG avec clé d'opérateur) pourra être ajoutée par une décision ultérieure.

### 13.3 Preuves à conserver

- manifeste et `SHA256SUMS` du jeu restauré ;
- journaux d'exécution de la sauvegarde et de la restauration ;
- rapport de restauration et son checksum ;
- entrée correspondante de `chain.jsonl` ;
- sortie des contrôles de permissions et de cohérence ;
- résultat de la vérification applicative ;
- mesures de durée.

Les preuves sont conservées hors du dépôt : elles peuvent contenir des noms de fichiers et des données d'exploitation. Le dépôt ne contient que la procédure, les scripts et les tests.

## 14. Checklist GO / NO-GO

### 14.1 Avant une sauvegarde

- [ ] Le jeu cible est complet (base + fichiers) et le déclencheur est identifié.
- [ ] L'environnement est le bon et la racine correspond.
- [ ] Le mode maintenance est actif.
- [ ] Les workers sont arrêtés et l'arrêt est vérifié.
- [ ] Le cron `schedule:run` est neutralisé.
- [ ] Aucune migration n'est en cours ni planifiée.
- [ ] `mariadb-dump` et `mariadb` sont présents, en version cohérente.
- [ ] Toutes les tables sont en InnoDB.
- [ ] L'espace disque est suffisant (≥ 2,5 fois l'estimation).
- [ ] La clé publique `age` de l'environnement est présente ; la clé privée est absente du serveur.
- [ ] Aucune autre sauvegarde ou restauration n'est en cours.
- [ ] Le journal d'exploitation est accessible en écriture.

### 14.2 Après une sauvegarde (GO pour considérer le jeu comme valide)

- [ ] Le manifeste est présent et valide.
- [ ] Les SHA-256 sont vérifiés et concordent.
- [ ] Les inventaires A et B sont identiques.
- [ ] Le nombre d'entrées de l'archive correspond à l'inventaire.
- [ ] Le statut est `complete`.
- [ ] Le jeu apparaît avec `scope: full` et `restorable_as_complete: true`.
- [ ] Le jeu est journalisé et référencé dans le ticket d'exploitation.
- [ ] Les workers, les files et le cron ont été rétablis.
- [ ] Le mode maintenance a été désactivé.
- [ ] Le déchiffrement n'est pas prouvé : le jeu est « valide mais non prouvé » jusqu'au test de déchiffrement ou de restauration.

### 14.3 Avant une restauration

- [ ] Le jeu est `complete`, `full` et d'intégrité vérifiée.
- [ ] La clé privée est fournie par un détenteur habilité, en `0600`, depuis un emplacement autorisé.
- [ ] La base cible respecte le motif et n'existe pas.
- [ ] Le répertoire cible est neuf et hors racine applicative.
- [ ] L'utilisateur MySQL de restauration est limité à la base cible.
- [ ] La zone de travail est en `0700` et son chemin résolu est vérifié.
- [ ] La cible n'est ni `chantier_production` ni `chantier_staging`.
- [ ] L'opérateur peut appliquer le remappage d'appartenance.
- [ ] Le mode maintenance ou l'absence d'utilisateurs est confirmé sur l'environnement de restauration.
- [ ] Aucun vhost public ne sera créé.

### 14.4 Après une restauration (GO pour considérer la restauration comme prouvée)

- [ ] Les tables et les lignes correspondent au manifeste.
- [ ] L'inventaire des fichiers est vérifié à 100 %.
- [ ] Les permissions finales sont conformes, sans `777`, sans lien symbolique.
- [ ] Le rapport de cohérence a été produit et les écarts sont expliqués.
- [ ] La vérification applicative a réussi en localhost.
- [ ] Le rapport de restauration est horodaté, haché et chaîné.
- [ ] Les preuves sont copiées hors du serveur.
- [ ] La zone de travail est supprimée.
- [ ] Le RTO mesuré est consigné.
- [ ] Le jeu est marqué comme référence de restauration dans le registre.

### 14.5 NO-GO

Une sauvegarde ou une restauration est **NO-GO** si l'un des cas suivants est constaté :

- un fichier a changé pendant l'opération ou la cohérence ne peut pas être garantie ;
- une table n'est pas en InnoDB ;
- un worker ou le cron n'a pas été arrêté ou neutralisé ;
- un checksum ne concorde pas ;
- le manifeste est absent, invalide ou incohérent ;
- la clé privée est sur le serveur, lisible par le groupe ou les autres, ou dans un emplacement interdit ;
- la cible de restauration existe déjà ;
- la cible est une base ou une racine applicative active ;
- l'espace disque est insuffisant ;
- une écriture déchiffrée devrait avoir lieu dans une release, un répertoire public ou la racine de sauvegarde ;
- le remappage d'appartenance n'est pas possible ;
- une copie hors site est exigée alors qu'elle n'existe pas (perte de serveur).

## 15. Intégration avec CHAN-97 et le lot 1

### 15.1 Ce que CHAN-97 ne change pas

- Le paquet reste immuable et `current` est basculé atomiquement.
- Aucune sauvegarde ni restauration n'est déclenchée par `deploy-staging`, `deploy-production`, `release`, `remote-deploy.sh` ou `remote-check.sh`.
- `shared/.env` et `shared/storage` ne sont jamais copiés ni remplacés par un déploiement.
- `release.json` reste le marqueur de version, de commit et d'arbre utilisé par le manifeste de sauvegarde.

### 15.2 Ce que le lot 1 impose

| Exigence du lot 1 | Réponse du lot 2 |
| --- | --- |
| Sauvegarde vérifiée avant migration de niveau 2 ou 3 | Jeu complet `pre-migration` + contrôle d'intégrité + preuve de restauration disponible |
| Restauration testée avant migration de classe D | Rapport de restauration isolée obligatoire avant validation |
| Un rollback applicatif ne restaure jamais la base | La restauration est une décision explicite, jamais une étape de rollback |
| Fenêtre de rollback | Les jeux `pre-migration` sont conservés jusqu'à sa clôture |
| SQLite ne prouve rien pour MariaDB | Le test de restauration doit être exécuté sur MariaDB 10.11 |

### 15.3 Séquence recommandée avant une migration sensible

1. vérifier le classement de la migration et les approbations requises ;
2. neutraliser les écritures, workers et cron ;
3. produire un jeu complet `pre-migration` ;
4. vérifier l'intégrité du jeu et consigner le manifeste dans le ticket ;
5. vérifier qu'une restauration de ce jeu a déjà été démontrée, ou réaliser le test isolé ;
6. exécuter la migration selon [`database-migrations.md`](database-migrations.md) ;
7. en cas d'incident, décider : correction en avant ou restauration explicite, avec perte de données assumée ;
8. ne pas clore la fenêtre de rollback avant validation écrite.

## 16. Tests et contrôles

### 16.1 Tests statiques et unitaires (Pest)

| Fichier | Objet |
| --- | --- |
| [`tests/Unit/Backup/BackupDocumentationTest.php`](../../tests/Unit/Backup/BackupDocumentationTest.php) | Présence du document, du runbook, des sections et des règles obligatoires |
| [`tests/Unit/Backup/BackupManifestTest.php`](../../tests/Unit/Backup/BackupManifestTest.php) | Schéma, validateur, jeux valides et invalides, refus des secrets |
| [`tests/Unit/Backup/BackupPolicyTest.php`](../../tests/Unit/Backup/BackupPolicyTest.php) | Gardes des scripts : pas de `777`, pas de `--same-owner`, cibles uniques, pas de clé privée, pas d'automatisation |

Ces tests sont statiques : ils ne prouvent ni le comportement MariaDB 10.11, ni la restaurabilité.

### 16.2 Tests shell locaux

[`scripts/ops/tests/test-backup-restore.sh`](../../scripts/ops/tests/test-backup-restore.sh) exécute les scripts dans un bac à sable avec des outils simulés :

- création d'un jeu complet et validation du manifeste ;
- calcul de `files.total_bytes` sur les seuls fichiers réguliers, avec un jeu de tailles connues ;
- refus sans mode maintenance ;
- refus si un fichier change pendant l'opération ;
- refus en présence d'un lien symbolique ;
- refus si `age` est absent ;
- interruption par `INT` et `TERM` : code retour 130/143, aucun jeu promu, verrou et zone de travail nettoyés ;
- interruption d'un processus enfant bloqué (`mariadb-dump`, `gzip`, `age`, `tar`, import `mariadb`) : enfant effectivement terminé avant la libération du verrou et la suppression de la zone de travail ;
- verrou orphelin : refus sans confirmation, refus si le PID est vivant, refus si l'hôte diffère ou est absent, libération explicite sur le même hôte ;
- inspection d'archives malveillantes : symlink, hardlink, FIFO, périphériques, `../`, chemin absolu, entrée hors périmètre, en-tête corrompu, archive tronquée ;
- en-têtes PAX : global `g`, `size`, `GNU.sparse.*`, `SCHILY.xattr.*`, enregistrement mal formé, en-tête vide, métadonnées contradictoires, nom long GNU mal formé, lien long GNU refusé ;
- PAX `path` autorisé et nom long GNU valide acceptés ;
- fin d'archive : remplissage nul supérieur à 512 Kio accepté, octet non nul juste après 512 Kio refusé, octet non nul en fin de fichier refusé, reste entièrement nul accepté ;
- décompression interrompue : `gzip -d` et `zstd -d` bloqués, enfant terminé avant nettoyage et libération du verrou ;
- refus d'une restauration dont l'archive contient une entrée interdite, sans création de la cible ;
- détection d'un artefact altéré ;
- refus d'une base de restauration préexistante ;
- refus d'un répertoire cible préexistant ou interdit ;
- refus d'une clé privée dans un emplacement interdit ;
- simulation de rotation sans suppression ;
- génération et chaînage du rapport de restauration.

Les fixtures TAR malveillantes sont générées par [`scripts/ops/tests/make-tar-fixture.php`](../../scripts/ops/tests/make-tar-fixture.php). Les outils `mariadb-dump`, `mariadb`, `age` et, si nécessaire, `zstd` sont remplacés par des doubles de test. Aucune connexion réelle n'est établie.

### 16.3 Contrôles manuels

```bash
# Tests et qualité
composer test

# Tests shell des scripts d'exploitation
bash scripts/ops/tests/test-backup-restore.sh

# Validation d'un manifeste existant
php scripts/ops/lib/manifest.php validate /var/backups/c2me/<env>/sets/<id>/manifest.json
```

### 16.4 Ce que les tests ne prouvent pas

- aucun dump réel n'est produit ;
- aucune restauration MariaDB 10.11 n'est exécutée ;
- aucun chiffrement `age` réel n'est vérifié ;
- aucune permission réelle n'est appliquée à un compte système ;
- aucune preuve de RTO n'est fournie.

La démonstration réelle relève du runbook, sur un environnement isolé, avec conservation des preuves.

## 17. Décisions, prérequis et limites

### 17.1 Décisions retenues

| Réf. | Décision |
| --- | --- |
| B-01 | Dump logique `mariadb-dump --single-transaction` ; sauvegarde physique non retenue |
| B-02 | Cohérence par mode maintenance, workers arrêtés et cron neutralisé |
| B-03 | Racine de sauvegarde `/var/backups/c2me/<environnement>` |
| B-04 | Copie hors site **reportée** ; perte complète du serveur en NO-GO documenté |
| B-05 | Chiffrement `age`, clé publique seule sur le serveur |
| B-06 | Déchiffrabilité prouvée par test humain mensuel et par restauration réelle |
| B-07 | Secrets, configuration compilée et droits MySQL exclus ; procédure de conservation séparée |
| B-08 | `app/private` et `app/public` inclus ; `framework/` et `logs/` exclus |
| B-09 | Restauration sur le même serveur, base dédiée, isolation logique |
| B-10 | Comptes dédiés à créer par l'administrateur ; le lot 2 les documente et les vérifie |
| B-11 | Scripts et procédure manuelle ; aucune planification automatique |
| B-12 | RPO 24 h cible, RTO cible 4 h, RTO démontré inexistant |
| B-13 | Outil aaPanel non retenu comme mécanisme principal |
| B-14 | Configuration serveur inventoriée et exportée manuellement |

### 17.2 Prérequis avant le premier test réel de restauration

1. Créer `/var/backups/c2me/staging` et `/var/backups/c2me/production` avec les propriétaires et modes attendus.
2. Créer un compte Linux de sauvegarde par environnement, sans `sudo`, avec lecture sur `shared/storage`.
3. Créer un utilisateur MySQL de sauvegarde en lecture seule par environnement.
4. Créer un utilisateur MySQL de restauration limité aux bases `chantier_restore_*`.
5. Générer une paire de clés `age` par environnement ; ne déposer que la clé publique sur le serveur ; conserver la clé privée hors serveur avec deux détenteurs.
6. Renseigner le fichier d'options MySQL de sauvegarde, en `0600`.
7. Vérifier la présence de `mariadb-dump`, `mariadb`, `age`, `zstd` et `tar` sur le serveur.
8. Vérifier la version de MariaDB (10.11) et l'absence de table non InnoDB.
9. Confirmer le mode maintenance, l'arrêt des workers et la neutralisation du cron.
10. Préparer un jeu de données de recette synthétique comprenant des fichiers déposés via l'application.
11. Vérifier l'espace disque disponible.
12. Vérifier que l'identité d'hôte est stable, unique et non réservée (`hostname -s` différent de `unknown`, `localhost`, `localhost.localdomain`), ou définir `C2ME_HOST_ID` explicitement.
13. Vérifier la présence de `flock` (util-linux) : il est obligatoire en production pour la sauvegarde et la restauration. Le contournement de test `C2ME_ALLOW_MISSING_FLOCK=1` est interdit en exploitation et **refusé systématiquement lorsque `C2ME_ENV=production`**, même si la variable est positionnée.
14. Prévoir un ticket d'exploitation pour consigner manifeste, checksums, journaux et rapport.

### 17.3 Limites assumées

- Aucune sauvegarde réelle n'a été produite ; aucune restauration réelle n'a été réalisée.
- Aucune automatisation planifiée n'est fournie ; le RPO de 24 h reste une cible non garantie.
- Aucune copie hors site ; la perte complète du serveur reste un NO-GO.
- Aucun RTO démontré.
- Aucun test sur MariaDB 10.11 dans la CI.
- Aucun test de chiffrement réel : `age` est simulé dans les tests locaux.
- Aucune vérification de cohérence métier fine tant qu'aucune table de pièces jointes n'existe.
- La restauration sur le même serveur ne prouve pas la reprise après sinistre.
- La configuration serveur (aaPanel, Nginx, PHP-FPM, Supervisor, cron) n'est ni sauvegardée ni restaurée par ce lot.
- Les secrets et les droits MySQL relèvent d'une procédure de conservation séparée, non automatisée.
- L'isolation PHP entre staging et production reste incomplète (pool `www` commun), ce qui renforce l'exigence d'une clé privée hors serveur.

## 18. Références

- [`AGENTS.md`](../../AGENTS.md) — règles impératives du projet.
- [`backup-restore-runbook.md`](backup-restore-runbook.md) — procédure opérateur.
- [`database-migrations.md`](database-migrations.md) — migrations, compatibilité N/N-1 et rollback.
- [`deployment-process.md`](deployment-process.md) — releases et activation de `current`.
- [`environments.md`](environments.md) — environnements, isolation et permissions.
- [`release-process.md`](release-process.md) — versionnement et releases.
- [`git-workflow.md`](git-workflow.md) — branches, commits et Pull Requests.
- [`scripts/ops/schema/backup-manifest.schema.json`](../../scripts/ops/schema/backup-manifest.schema.json) — schéma du manifeste.
- [Laravel 13 — Maintenance mode](https://laravel.com/docs/13.x/configuration#maintenance-mode).
- [MariaDB 10.11 — mariadb-dump](https://mariadb.com/kb/en/mariadb-dump/).
- [MariaDB 10.11 — InnoDB](https://mariadb.com/kb/en/innodb/).
- [age — outil de chiffrement](https://age-encryption.org/).
