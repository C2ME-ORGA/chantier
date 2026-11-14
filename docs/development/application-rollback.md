# Rollback applicatif

Ce document définit le mécanisme de **rollback applicatif manuel** de C2ME Chantier : réactivation d'une release antérieure par bascule atomique du lien `current`.

- Ticket : CHAN-98 – lot 3.
- Ticket parent : CHAN-92 – workflow Git, releases et déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Portée : script de rollback, contrôles fail-closed, attestation de compatibilité N/N-1, gestion des workers et des files, health check, journalisation, tests.
- Hors portée : restauration de base de données (lot 2), correction en avant, modification du mécanisme de déploiement CHAN-97, automatisation du rollback.

> **Statut de ce lot.** Aucun rollback n'a été exécuté sur un serveur réel. Les tests sont exécutés sur des releases et un health check simulés, sur Linux. Les procédures de ce document constituent des règles à appliquer ; elles ne sont pas une preuve d'exécution en staging ou en production.
>
> **Un rollback applicatif ne restaure jamais la base de données.** Il ne défait ni un `ALTER`, ni un `DROP`, ni un backfill, ni un job exécuté, ni un email envoyé, ni un fichier écrit dans `shared/storage`. La restauration de données relève du lot 2 et reste une décision distincte, avec perte de données assumée.

## Sources de vérité

| Sujet | Référence |
| --- | --- |
| Rollback applicatif, attestation et journal | Ce document |
| Procédure opérateur | [`application-rollback-runbook.md`](application-rollback-runbook.md) |
| Migrations, compatibilité N/N-1 et rollback | [`database-migrations.md`](database-migrations.md) |
| Déploiements et activation de `current` | [`deployment-process.md`](deployment-process.md) |
| Sauvegarde et restauration | [`backup-restore.md`](backup-restore.md) |
| Environnements et permissions | [`environments.md`](environments.md) |
| Implémentation | [`scripts/ops/rollback.sh`](../../scripts/ops/rollback.sh) |
| Validateur d'attestation | [`scripts/ops/lib/rollback-attestation.php`](../../scripts/ops/lib/rollback-attestation.php) |
| Tests | [`scripts/ops/tests/test-rollback.sh`](../../scripts/ops/tests/test-rollback.sh) et [`tests/Unit/Rollback`](../../tests/Unit/Rollback) |

## 1. Principes directeurs

1. **Le rollback est manuel.** Aucun workflow, health check, déploiement ou script ne le déclenche automatiquement.
2. **Seul le code change.** Le lien `current` est rebasculé vers une release complète déjà présente. La base, les données, les jobs, les caches, `.env` et `shared/storage` restent en l'état.
3. **Fail-closed.** Toute condition non vérifiée refuse le rollback. Aucun argument `--force` n'existe.
4. **La compatibilité N/N-1 est déclarée explicitement.** Le script exige une attestation horodatée issue de la procédure de migrations.
5. **La bascule est atomique.** Elle reprend la technique CHAN-97 : `ln -sfn` vers un lien temporaire puis `mv -Tf` sur `current`.
6. **L'opération est traçable.** Un journal JSONL en ajout seul conserve l'état avant/après, le health check et le résultat.
7. **L'échec ne masque rien.** Un health check en échec laisse la release cible active, journalise l'échec et indique le retour manuel possible ; aucun retour automatique.
8. **Le compte technique de l'environnement exécute l'opération**, sans `sudo`, sans accès à l'autre environnement.

## 2. Périmètre exact

### 2.1 Ce que le rollback fait

- vérifie l'environnement, la racine, la release active et la release cible ;
- vérifie la complétude de la cible (`artisan`, `public/index.php`, configuration compilée, `release.json`, liens `.env`/`storage`/`public/storage`) ;
- valide une attestation de compatibilité N/N-1 ;
- exige la confirmation de l'arrêt des workers, de la pause des files et du traitement des jobs ;
- vérifie l'absence de déploiement concurrent et prend un verrou de rollback ;
- bascule `current` de façon atomique ;
- exécute un health check sur `/up` ;
- journalise l'opération et affiche les étapes de reprise manuelles.

### 2.2 Ce que le rollback ne fait jamais

| Opération | Interdiction |
| --- | --- |
| `migrate:rollback`, `migrate:fresh`, `db:wipe` | Jamais exécutés |
| Modification du schéma MariaDB | Hors périmètre |
| Restauration de sauvegarde | Hors périmètre (lot 2, décision distincte) |
| Écrasement ou suppression d'une release | Jamais |
| Modification de `shared/.env` ou `shared/storage` | Jamais |
| Suppression de jobs, `failed_jobs`, caches ou sessions | Jamais |
| Modification du cron, de Supervisor ou de PHP-FPM | Jamais par ce script |
| Rollback automatique sur échec de health check | Jamais |
| Contournement par `--force` | Aucun argument de ce type |

## 3. Architecture et réutilisation de CHAN-97

Le mécanisme ne réimplémente pas la gestion des releases :

- les releases restent des répertoires immuables `releases/<release-id>` ;
- la release active est désignée par le lien `current` ;
- `release.json` reste le marqueur de version, de commit et d'environnement ;
- la bascule reprend exactement la séquence de `remote-deploy.sh` ;
- `shared/.env` et `shared/storage` ne sont ni copiés ni modifiés.

Le script [`rollback.sh`](../../scripts/ops/rollback.sh) est un outil d'exploitation autonome, exécuté depuis une copie de travail maîtrisée avec le compte technique de l'environnement. Il réutilise [`common.sh`](../../scripts/ops/lib/common.sh) pour la table des environnements, l'identité d'hôte, les verrous, les signaux et l'exécution suivie des commandes critiques.

## 4. Prérequis

- Environnement `staging` ou `production`, racine correspondante, compte technique propriétaire de la racine.
- Releases complètes dans `releases/`, avec `release.json` cohérent et liens partagés valides.
- Binaire PHP 8.4 résolu (`C2ME_PHP_BIN` ou `php`).
- `curl` disponible pour le health check.
- Identité d'hôte stable, unique et non réservée (`hostname -s` ou `C2ME_HOST_ID`).
- Attestation de compatibilité N/N-1 récente (24 h par défaut).
- Workers arrêtés, files en pause, jobs triés.
- Aucun déploiement en cours (`releases/.incoming-*` absent).
- Accès en lecture aux releases et en écriture à `shared/` (journal et verrou).

## 5. Décision GO / NO-GO

### GO

- la cible est identifiée, complète et lisible ;
- l'attestation est valide et désigne exactement la source et la cible ;
- aucune migration n'est en cours, en attente, partielle ou destructive ;
- aucun Contract n'a été appliqué ;
- les workers sont arrêtés, les files en pause et les jobs traités selon la procédure ;
- le déploiement n'est pas en cours ;
- la raison du rollback est écrite et l'opérateur est habilité ;
- le health check est disponible ;
- le rollback est préféré à une correction en avant pour des raisons explicites (régression fonctionnelle, erreur de configuration, etc.).

### NO-GO

- schéma incompatible avec la cible, ou compatibilité non démontrée ;
- migration en cours, partielle, non vérifiée ou Contract appliqué ;
- release cible incomplète ou hors de `releases/` ;
- jobs en attente non triés ;
- workers non arrêtés ou files non mises en pause ;
- opération concurrente ;
- health check indisponible ;
- incident nécessitant une correction de données ou une restauration : le rollback ne suffira pas.

## 6. Compatibilité N/N-1 et attestation

Le script refuse toute cible sans **attestation de compatibilité** :

```json
{
  "schema_version": 1,
  "environment": "production",
  "source_release": "v1.4.0-1234-1",
  "target_release": "v1.3.0-1200-1",
  "database": "chantier_production",
  "checked_at": "2026-11-14T10:00:00Z",
  "checked_by": "c2me-deploy-production",
  "migrate_status_sha256": "<sha256 de la preuve migrate:status>",
  "migrations": {
    "in_progress": false,
    "pending": false,
    "partial": false,
    "destructive_applied": false,
    "contract_applied": false,
    "compatible_with_target": true
  }
}
```

Règles :

- l'attestation est produite après contrôle de `migrate:status` et application de la grille [`database-migrations.md`](database-migrations.md) ;
- **la preuve est un fichier conservé à côté de l'attestation** : `<attestation>.migrate-status.txt`. Il contient un en-tête (environnement, release, base, date de capture) puis la sortie exacte de `migrate:status` après une ligne `---`. Le champ `migrate_status_sha256` est le SHA-256 de ce fichier complet ;
- le validateur recalcule l'empreinte de la preuve et refuse une preuve absente, illisible, modifiée, symbolique ou incohérente avec l'environnement, la release et la base ;
- les permissions de la preuve sont contrôlées lorsque la plateforme applique les modes POSIX : écriture de groupe et des autres interdite, lecture propriétaire requise ;
- cette vérification garantit l'**intégrité** de la preuve, pas son **authenticité** : un opérateur peut produire une preuve et une attestation cohérentes mais inexactes. La responsabilité reste humaine et tracée ;
- la durée de validité est de 24 h par défaut, réglable par `--max-attestation-age` ;
- une attestation ne prouve pas à elle seule l'état du schéma : elle rend la décision explicite, bornée et traçable ;
- toute valeur `in_progress`, `pending`, `partial`, `destructive_applied`, `contract_applied` à `true` interdit le rollback ;
- `compatible_with_target` doit être `true` ;
- l'environnement, la base, la source et la cible doivent correspondre à l'opération réelle.

La fenêtre de rollback et les critères de Contract restent ceux du lot 1.

## 7. Workers, files et jobs

Avant la bascule, l'opérateur doit :

1. arrêter les workers supervisés ;
2. vérifier qu'aucun processus `queue:work`, `queue:listen` ou `horizon` ne subsiste pour la racine ;
3. mettre les files en pause ;
4. traiter ou conserver les jobs en attente selon leur compatibilité avec la release cible ;
5. fournir les trois confirmations explicites.

Le script vérifie les confirmations, l'état Supervisor lorsqu'un programme est configuré et l'absence de worker détectable. Il ne modifie ni Supervisor, ni les files, ni le cron.

Après un rollback réussi, la reprise des workers et des files est **manuelle**, selon le runbook. Les jobs déjà exécutés restent exécutés ; leurs effets ne sont pas annulés.

## 8. Health check

- Après la bascule, le script appelle `<URL de l'environnement>/up` avec `Accept: application/json`.
- Il exige un code HTTP de succès et la présence de `"status":"up"`.
- En cas d'échec : la release cible **reste active**, le rollback est marqué en échec, le journal conserve l'état, et le script indique le retour manuel possible vers la release source.
- Aucun retour automatique n'est effectué : il faudrait une nouvelle attestation et une nouvelle décision.

## 9. Traçabilité

Le journal `shared/rollback.log` est en ajout seul, au format JSONL. Chaque ligne contient au minimum :

- horodatage UTC, événement (`started`, `completed`, `failed`, `refused`, `interrupted`) ;
- identifiant d'opération unique ;
- environnement, opérateur, hôte ;
- release source et cible, versions, commits, empreinte de la cible ;
- raison, empreinte de l'attestation ;
- état de `current` avant et après ;
- état du health check, des workers, des files, des jobs, du mode maintenance ;
- résultat et erreur éventuelle ;
- indicateur `dry_run`.

Aucun secret, contenu de `.env` ou donnée métier n'y est écrit. Le mode `--dry-run` n'écrit ni journal, ni verrou, ni fichier temporaire. Une opération interrompue par un signal produit une entrée `interrupted` puis libère le verrou. Après un `SIGKILL` ou un arrêt brutal, une entrée `started` sans entrée finale signale une opération à analyser ; le verrou éventuel relève de la procédure de verrou orphelin de [`backup-restore-runbook.md`](backup-restore-runbook.md).

## 10. Interruptions et concurrence

- Les signaux `HUP`, `INT` et `TERM` sont traités : journalisation `interrupted`, arrêt des enfants suivis, nettoyage du fichier temporaire et du verrou, puis sortie avec `129`, `130` ou `143`.
- La bascule de `current` est protégée par un masquage court des signaux, comme dans CHAN-97.
- Le verrou `shared/.release-operation.lock` est **partagé avec le déploiement** (`remote-deploy.sh`). Les deux opérations utilisent le même mécanisme (répertoire créé atomiquement, PID, hôte, horodatage, opération, jeton) et la même section critique : publication d'une release et activation de `current`. Un seul déploiement ou rollback peut détenir ce verrou.
- Le verrou est acquis avant la création du répertoire `.incoming-*` côté déploiement et avant la bascule côté rollback ; il est conservé jusqu'à la fin de l'opération et libéré sur succès, erreur ou signal. Un verrou orphelin n'est jamais supprimé automatiquement.
- Un répertoire `releases/.incoming-*` interdit le rollback pendant un déploiement ; cette vérification reste un diagnostic, l'exclusion mutuelle étant assurée par le verrou partagé.
- `current` est revérifié juste avant la bascule ; tout changement interrompt l'opération.

## 11. Différence avec une restauration de données

| Situation | Rollback applicatif | Restauration de sauvegarde |
| --- | --- | --- |
| Code incorrect, schéma compatible | Oui | Non nécessaire |
| Schéma incompatible avec N-1 | Non | En dernier recours, avec perte de données |
| Données corrompues | Non | Oui, décision distincte |
| Effets métier déjà produits | Non annulés | Non annulés non plus |
| Migration destructive appliquée | Non | Restauration possible du lot 2 |
| Jobs déjà exécutés | Non annulés | Non annulés |

Un rollback applicatif n'est jamais une restauration de données.

## 12. Tests

- `scripts/ops/tests/test-rollback.sh` : rollback nominal staging et production, refus (release absente, hors racine, incomplète, symbolique, `current` invalide, cible active, `--from` incohérent), attestation (migrations en cours/attente/partielle, Contract, incompatibilité, périmètre, péremption, preuve modifiée/absente/d'un autre environnement ou d'une autre release), workers/files/jobs, verrou partagé déploiement/rollback, échec et signal du déploiement, concurrence de deux rollbacks, dry-run exact sans état, health check en échec, interruption SIGTERM, intégrité du journal, atomicité de `current` sous Linux, absence de modification de `.env` et du stockage.
- `tests/Unit/Rollback` : documentation, validateur d'attestation, gardes statiques du script.

Les tests utilisent des releases et un health check simulés. Ils ne prouvent pas un rollback réel sur staging ou production.

## 13. Limites et cas non couverts

- Aucun rollback réel n'a été exécuté.
- La compatibilité N/N-1 reste déclarative : le script ne se connecte pas à MariaDB et ne prouve pas l'état du schéma. L'attestation vérifie l'intégrité d'une preuve `migrate:status`, pas son authenticité.
- Le mode `--dry-run` n'écrit ni journal ni verrou : il ne laisse aucune trace de l'intention.
- Le health check HTTP ne prouve pas le bon fonctionnement métier.
- Les workers et files ne sont pas pilotés par le script.
- Aucun test sur le health check TLS réel, les vhosts ou PHP-FPM.
- Un rollback ne corrige pas les données écrites par la release retirée.
- Les cas nécessitant une correction en avant ou une restauration de données restent hors de ce mécanisme.

## 14. Références

- [`database-migrations.md`](database-migrations.md) — stratégie N/N-1, Expand/Migrate/Contract, rollback.
- [`deployment-process.md`](deployment-process.md) — releases, activation atomique, health check.
- [`backup-restore.md`](backup-restore.md) — sauvegarde et restauration de données.
- [`environments.md`](environments.md) — environnements, comptes et permissions.
- [`application-rollback-runbook.md`](application-rollback-runbook.md) — procédure opérateur.
