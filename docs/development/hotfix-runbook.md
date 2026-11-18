# Runbook — hotfix de production

Procédure opérationnelle du **hotfix** de C2ME Chantier, de la qualification de l'incident à la clôture et à la synchronisation `main` → `develop`.

- Ticket : CHAN-99 – lot 5.
- Ticket parent : CHAN-92 – workflow Git, releases et déploiements.
- Dépôt : [`C2ME-ORGA/chantier`](https://github.com/C2ME-ORGA/chantier).
- Références : [`hotfix-process.md`](hotfix-process.md), [`git-workflow.md`](git-workflow.md), [`release-process.md`](release-process.md), [`deployment-process.md`](deployment-process.md), [`database-migrations.md`](database-migrations.md), [`application-rollback.md`](application-rollback.md), [`application-rollback-runbook.md`](application-rollback-runbook.md), [`backup-restore.md`](backup-restore.md) et [`backup-restore-runbook.md`](backup-restore-runbook.md).
- Statut : **procédure cible, non exécutée**. Aucune commande de ce runbook n'a été exécutée sur un serveur, aucune release n'a été publiée et aucun déploiement, rollback ou restauration n'a été réalisé dans le cadre de CHAN-99.

> **État actuel de l'infrastructure.**
>
> À la date de rédaction, le dépôt ne dispose pas encore d'une version stable publiée et déployée, ni d'environnements GitHub `staging`/`production` configurés, ni de secrets SSH, ni d'une sauvegarde/restauration réellement vérifiée, ni d'un rollback réellement exécuté, ni d'une protection de tags.
>
> **En conséquence, ce runbook n'est pas exécutable en production aujourd'hui.** Il décrit la procédure à appliquer **après** la mise en service décrite en section 1. Tant que les prérequis ne sont pas satisfaits, tout hotfix réel est **NO-GO**. Les commandes de déploiement, de rollback, de migration et de restauration sont documentées pour préparation et exercice ; elles ne doivent jamais être lancées par simple copier-coller.

## Rôles et règles de décision

| Rôle | Responsabilité |
| --- | --- |
| **Responsable de l'incident** | Qualifie l'impact, la sévérité P1/P2, l'urgence et la décision GO/NO-GO. |
| **Responsable release/production** | Autorise la version, la PR, le tag, la publication, le déploiement et le rollback. |
| **Auteur du hotfix** | Prépare la branche depuis `main`, le correctif minimal, le test de non-régression et la PR. |
| **Relecteur technique** | Vérifie le périmètre, la sécurité, les tests, les migrations et le risque. |
| **Opérateur** | Exécute les opérations serveur autorisées : migration manuelle, rollback, contrôles. |
| **Approbateur de l'environnement `production`** | Approuve le job protégé de déploiement ; l'absence d'environnement configuré bloque le hotfix. |

Règles :

- Une même personne peut tenir plusieurs rôles, mais chaque décision GO/NO-GO doit être écrite, datée et attribuée.
- Les rulesets GitHub n'exigent aucune approbation pour les commits attribués ; le GO humain reste obligatoire et est enregistré dans la PR et/ou Jira.
- Aucun push direct sur `main` ou `develop`, aucun force-push, aucun squash sur les branches protégées, aucun contournement de ruleset.
- Aucun déploiement, rollback, `migrate:rollback`, `db:wipe` ou restauration de production sans décision humaine explicite.
- En cas de doute sur la sécurité, les données, la migration ou la compatibilité N/N-1, la décision est **NO-GO**.

## 1. Prérequis de mise en service

Ces prérequis doivent être satisfaits **avant** d'utiliser ce runbook pour un incident réel.

- [ ] Une release stable a été publiée depuis `develop` vers `main` et déployée en production.
- [ ] Le tag stable, la release publiée, le déploiement en production et `release.json` sont cohérents.
- [ ] Les environnements GitHub `staging` et `production` existent avec leurs variables et secrets.
- [ ] L'approbateur de `production` est configuré ; `Prevent self-review` et le bypass administrateur sont réglés conformément à [`environments.md`](environments.md).
- [ ] Les clés SSH, les empreintes `SSH_KNOWN_HOSTS` et `DEPLOY_PHP_BIN` ont été relevés et vérifiés.
- [ ] Un déploiement staging et une promotion production ont déjà été exercés avec succès.
- [ ] Une sauvegarde complète a été produite, vérifiée et restaurée dans un environnement isolé ; le RTO a été mesuré.
- [ ] Une copie hors site et une politique de rétention sont définies, ou leur absence est explicitement acceptée.
- [ ] Un rollback applicatif a été exercé sur staging avec attestation N/N-1, workers et files.
- [ ] Le superviseur des workers, les files et l'entrée cron `schedule:run` sont confirmés sur le serveur.
- [ ] Les tags sont protégés, ou une mesure compensatoire est documentée et appliquée.
- [ ] Le canal privé de traitement des incidents de sécurité est défini.
- [ ] La durée de conservation des preuves et les critères de post-mortem sont définis.
- [ ] La surveillance, les alertes et les contacts d'escalade sont opérationnels.

Tant que ces points ne sont pas satisfaits, les sections C à G sont des procédures de préparation, pas des actions autorisées.

## 2. Conventions et variables

```powershell
$Ticket = "CHAN-xxx"                 # ticket du hotfix
$ProdTag = "v1.4.2"                  # version stable réellement déployée
$Version = "v1.4.3"                  # prochain PATCH cible
$RcVersion = "v1.4.3-rc.1"           # release candidate staging
$Branch = "hotfix/$Ticket-description"
$FixedFile = "app/Domains/.../Fichier.php"
$RegressionTest = "tests/Feature/.../RegressionTest.php"
$SyncTicket = "CHAN-xxx"             # ticket de la synchronisation
$SyncBranch = "bugfix/$SyncTicket-synchronisation-hotfix"
$HotfixCommit = "<sha-du-commit-de-fusion-hotfix>"
$MainSha = ""
$DevelopSha = ""
$PrBody = "<chemin-du-corps-de-pr-hotfix.md>"
$SyncBody = "<chemin-du-corps-de-pr-synchronisation.md>"
$RcCommit = "<sha-du-commit-de-la-rc>"
$RunId = "<id-execution-github>"
$ReleaseRunId = "<id-execution-release>"
$StagingRunId = "<id-execution-staging>"
$ProductionRunId = "<id-execution-production>"
```

Variables serveur utilisées par les procédures de rollback, de sauvegarde et de migration : voir [`application-rollback-runbook.md`](application-rollback-runbook.md) et [`backup-restore-runbook.md`](backup-restore-runbook.md). Les valeurs `ENV`, `ROOT`, `PHP`, `DB_NAME`, `TARGET_RELEASE`, `WORKER_PROGRAM`, `SET` et les chemins sont fournies par l'opérateur ; ne jamais les deviner.

## A. Qualification de l'incident

### A.1 Fiche d'incident

| Information | Contenu attendu |
| --- | --- |
| Ticket Jira | `CHAN-xxx`, lien vers l'incident. |
| Date et heure | Détection, début d'impact, fuseau. |
| Environnement | Production uniquement pour un hotfix. |
| Fonction affectée | Parcours, écran, API ou traitement. |
| Utilisateurs impactés | Nombre, profils, zones, organisations. |
| Données et sécurité | Données exposées, perdues, corrompues ou financières. |
| Version affectée | Version stable déployée et commit de production. |
| Reproduction | Étapes, résultat attendu, résultat observé, logs sans secret. |
| Contournement | Existe-t-il un workaround acceptable ? |
| Rollback | Un retour à la release précédente est-il possible et suffisant ? |
| Sévérité | P1 ou P2, avec justification. |
| Responsable | Nom du responsable de l'intervention. |

### A.2 Critères P1 / P2

| Niveau | Critères | Décision |
| --- | --- | --- |
| **P1 — Critique** | Production indisponible, perte ou corruption de données, faille de sécurité active, impact financier/légal majeur. | Hotfix éligible après qualification et GO. |
| **P2 — Majeure** | Fonction métier critique bloquée ou fortement dégradée, sans contournement raisonnable. | Hotfix éligible après qualification et GO. |
| **P3 — Modérée** | Impact limité ou contournement acceptable. | Pas de hotfix : `bugfix/*` depuis `develop`. |
| **P4 — Mineure** | Défaut cosmétique ou sans impact opérationnel. | Backlog ou prochaine livraison. |

Un hotfix est réservé aux incidents **P1/P2** conformément à [`hotfix-process.md`](hotfix-process.md).

### A.3 Décision

1. Évaluer d'abord le rollback applicatif (section F) : s'il est sûr, compatible N/N-1 et suffisant, il est préféré au hotfix.
2. Si le rollback est impossible ou insuffisant, qualifier le hotfix.
3. Si le correctif exige une fonctionnalité, une rupture de compatibilité, un refactoring large ou une migration destructive, ce n'est pas un hotfix : suivre le processus normal de release.
4. Rendre et consigner la décision GO/NO-GO.

### A.4 NO-GO de qualification

- Aucune version stable réellement déployée.
- Référence de production inconnue ou incohérente.
- Défaut non présent en production ou non reproductible.
- Cause racine insuffisamment comprise.
- Correctif non minimal, non rétrocompatible ou accompagné d'une fonctionnalité.
- Migration destructive, Contract, classe C/D/E ou schéma incompatible.
- Test de non-régression absent.
- Staging indisponible ou validation impossible.
- Rollback suffisant et préférable.
- Autorisation humaine absente.
- Incident exclusivement infrastructurel.
- Canal de sécurité non défini pour un correctif sensible.

**Preuve à conserver :** fiche d'incident, sévérité, décision GO/NO-GO, nom du responsable et horodatage.

## B. Préparation de l'intervention

### B.1 Vérifier la production

À exécuter par l'opérateur habilité, en lecture seule :

```bash
readlink -f "$ROOT/current"
cat "$ROOT/current/release.json"
ls -1 "$ROOT/releases"
curl -fsS -H 'Accept: application/json' "https://chantier.c2me.fr/up"
find "$ROOT/releases" -maxdepth 1 -name '.incoming-*' -print
```

Contrôles :

- `release.json` contient `version`, `commit_sha`, `environment`, `artifact_id` et `sha256` attendus ;
- `current` pointe vers une release complète ;
- `/up` répond `200` avec `{"status":"up"}` ; si la production est indisponible, le contrôle est documenté mais ne bloque pas la qualification de l'incident ;
- aucun répertoire `.incoming-*` n'indique un déploiement en cours.

### B.2 Identifier la référence de production

```powershell
gh release view $ProdTag --json tagName,isDraft,isPrerelease,publishedAt,url
git fetch origin main develop
if ($LASTEXITCODE -ne 0) { throw "Impossible de récupérer main et develop." }
$ProdCommit = (git rev-parse "$ProdTag^{commit}").Trim()
$MainSha = (git rev-parse origin/main).Trim()
$DevelopSha = (git rev-parse origin/develop).Trim()
git cat-file -t "refs/tags/$ProdTag"
git tag --points-at $ProdCommit
git merge-base --is-ancestor $ProdCommit origin/main
if ($LASTEXITCODE -ne 0) { throw "Le commit de production n'est pas dans origin/main : NO-GO." }
if ($MainSha -ne $ProdCommit) { throw "origin/main n'est pas alignée sur la production : NO-GO." }
```

Contrôles :

- le tag est annoté ;
- la release est publiée, ni brouillon ni prérelease ;
- `release.json` et le tag désignent le même commit ;
- un seul tag stable pointe sur le commit de production ;
- `main` est alignée sur `$ProdCommit` ; si `main` a avancé, le hotfix est NO-GO jusqu'à régularisation ;
- `origin/develop` est à jour et son SHA est consigné.

### B.3 Vérifier les branches et les opérations en cours

```powershell
git status --short
gh pr list --base main --state open --json number,title,url
gh pr list --base develop --state open --json number,title,url
gh run list --limit 20 --json databaseId,name,status,conclusion,headBranch,createdAt
$ExistingTargetTag = git ls-remote --tags --refs origin "refs/tags/$Version"
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier le tag $Version sur le dépôt distant." }
$ExistingRcTag = git ls-remote --tags --refs origin "refs/tags/$RcVersion"
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier le tag $RcVersion sur le dépôt distant." }
if ($ExistingTargetTag -or $ExistingRcTag) { throw "Un tag cible existe déjà." }
```

Aucune release, aucun déploiement et aucun rollback ne doit être en cours. Aucun tag `$Version` ou `$RcVersion` ne doit déjà exister.

Vérifier aussi la disponibilité des informations et accès nécessaires : ticket et décision, accès en lecture au dépôt et à GitHub, accès opérateur au serveur, identifiants des environnements, contacts d'escalade et canal d'incident. Une information manquante bloque le démarrage.

### B.4 Sauvegardes et restauration

- [ ] Une sauvegarde complète récente existe et son intégrité est vérifiée.
- [ ] Une restauration isolée a déjà été démontrée, ou son absence est explicitement acceptée.
- [ ] Le RTO et la perte de données maximale sont connus.
- [ ] Une copie hors site existe, ou son absence est acceptée et documentée.

Commandes de contrôle, à exécuter sur le serveur sous le compte technique et en lecture seule, depuis le répertoire qui contient `scripts/ops`, selon le runbook de sauvegarde :

```bash
bash scripts/ops/backup.sh preflight --env "$ENV"
bash scripts/ops/backup.sh verify --env "$ENV" --set "$SET"
```

Règles :

- aucune restauration sur `chantier_production` ou `chantier_staging` ;
- une restauration se fait uniquement sur une cible isolée, selon [`backup-restore-runbook.md`](backup-restore-runbook.md) ;
- l'absence de sauvegarde vérifiée interdit tout hotfix avec migration ;
- pour un hotfix purement code, l'absence de sauvegarde vérifiée doit être consignée et acceptée explicitement avant le GO.

### B.5 Migrations

- [ ] La migration est classée : aucune, A ou B. Les classes C, D et E sont refusées.
- [ ] Aucune migration destructive, aucun Contract.
- [ ] La compatibilité N/N-1 est démontrée.
- [ ] La migration a été répétée en staging sur MariaDB 10.11.
- [ ] Le schéma actuel est lu avec `migrate:status`.
- [ ] Le code ne dépend pas d'une migration absente de la release déployée.

Si une migration destructive ou boot-critical est nécessaire, le hotfix est **NO-GO** et suit le processus normal de release.

### B.6 Rollback

- [ ] La release cible du rollback existe, est complète et est antérieure à la release active.
- [ ] La compatibilité N/N-1 peut être attestée.
- [ ] Les workers peuvent être arrêtés et les files mises en pause.
- [ ] Les jobs en attente peuvent être triés.
- [ ] Aucun déploiement n'est en cours.
- [ ] Le rollback a déjà été exercé, ou son absence de preuve est acceptée et documentée.

### B.7 Conditions empêchant de commencer

- Production indisponible sans diagnostic.
- Référence de production inconnue ou `main` non alignée.
- Tag/release/`release.json` incohérents.
- Environnements GitHub ou secrets absents.
- Staging indisponible.
- Sauvegarde absente ou non vérifiée pour un hotfix avec migration.
- Migration destructive ou incompatible.
- Rollback impossible sans risque pour les données.
- CI de référence rouge ou indisponible.
- Autorisation humaine absente.
- Informations, accès ou contacts d'escalade indisponibles.
- Release/déploiement/rollback en cours.

**Preuves :** sorties de contrôle, SHA, version, `release.json`, état de sauvegarde, classification de migration, décision de rollback.

## C. Exécution du hotfix

> **Ordre important.** La synchronisation `main` → `develop` (section G) est exécutée **avant** la création de la RC, conformément aux Lots 3 et 4. La section G est placée après les sections de déploiement pour la lecture, mais son exécution intervient à l'étape C.6.

### C.1 Créer la branche depuis `main`

**Action**

```powershell
git switch main
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw "Impossible de mettre main à jour." }
git status --short
if ((git rev-parse HEAD).Trim() -ne $ProdCommit.Trim()) { throw "main n'est pas sur le commit de production." }
git rev-parse --verify --quiet "refs/heads/$Branch"
if ($LASTEXITCODE -eq 0) { throw "La branche locale existe déjà." }
$ExistingRemote = git ls-remote --heads origin $Branch
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier la branche sur le dépôt distant." }
if ($ExistingRemote) { throw "La branche distante existe déjà." }
git switch -c $Branch
git rev-parse --abbrev-ref HEAD
git merge-base --is-ancestor $ProdCommit HEAD
```

**Contrôle :** la branche part exactement du commit de production, jamais de `develop` ; le dépôt local est propre.

**Preuve :** nom de branche, SHA de base, sortie des contrôles.

**Passage :** base correcte, dépôt propre.

**Arrêt :** branche existante, base incorrecte, modifications locales.

### C.2 Analyser et corriger

**Action**

- reproduire le défaut ;
- identifier la cause racine ;
- appliquer uniquement le correctif minimal ;
- ajouter ou adapter le test de non-régression ;
- ne pas inclure de fonctionnalité, de refactoring large ou de dépendance majeure.

**Contrôle :** le test échoue sans le correctif et passe avec ; le diff est limité au périmètre.

**Preuve :** reproduction, cause racine, diff, résultat du test avant/après.

**Passage :** test de non-régression fonctionnel.

**Arrêt :** cause inconnue, correctif large, rupture de compatibilité, test impossible.

### C.3 Vérifications locales

```powershell
composer lint:check
composer types:check
php artisan test
composer ci:check --no-interaction
git diff --check
git status --short
```

Si SQL, migration ou contrainte :

```powershell
vendor\bin\pest --configuration=phpunit.mariadb.xml
```

Si frontend :

```powershell
npm ci
npm run build
php scripts/ci/verify-vite-build.php
```

**Contrôle :** tous les contrôles applicables sont verts ; aucun test supprimé ou ignoré.

**Preuve :** commandes, résultats, commit exact.

**Passage :** CI locale verte.

**Arrêt :** échec, test manquant, build cassé, modification hors périmètre.

### C.4 Préparer la Pull Request vers `main`

```powershell
$PrUrl = gh pr create --base main --head $Branch --title "fix(scope): ... ($Ticket)" --body-file $PrBody
$Pr = gh pr view $PrUrl --json number --jq '.number'
gh pr view $Pr --json number,baseRefName,headRefName,isDraft,mergeable,mergeStateStatus,statusCheckRollup,url
```

Le corps contient : ticket, sévérité, version déployée, commit de production, tag/release, version cible, cause racine, correctif, test, migration, rollback, plan staging et preuves.

**Preuve :** URL de PR, base `main`, tête `$Branch`, corps complet.

**Passage :** PR ouverte, non brouillon.

**Arrêt :** base incorrecte, corps incomplet, secret dans le diff.

### C.5 CI, revue et autorisation humaine

```powershell
gh pr diff $Pr
gh pr checks $Pr --watch
```

Contrôles :

- `ci` vert et tous les jobs du workflow verts ;
- revue technique selon [`pull-request-review.md`](pull-request-review.md) ;
- commentaires résolus ;
- email de commit attribué au compte GitHub ;
- branche à jour avec `main` (fusion, jamais rebase) ;
- autorisation humaine explicite :

```powershell
gh pr comment $Pr --body "GO hotfix — $(Get-Date -Format o) — VOTRE_NOM — version cible $Version"
```

**Preuve :** commentaire GO, CI verte, revue, SHA du dernier commit.

**Passage :** GO enregistré et CI verte.

**Arrêt :** CI rouge, revue incomplète, GO absent, branche non à jour, release/déploiement en cours.

### C.6 Fusionner et synchroniser `main` → `develop`

**Action**

```powershell
gh pr merge $Pr --merge
if ($LASTEXITCODE -ne 0) { throw "La fusion de la PR hotfix a échoué." }
git switch main
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw "Impossible de mettre main à jour après la fusion." }
$HotfixCommit = (git rev-parse HEAD).Trim()
gh pr view $Pr --json mergeCommit --jq '.mergeCommit.oid'
```

Attendre la CI sur `main` :

```powershell
$RunId = gh run list --workflow tests.yml --branch main --commit $HotfixCommit --limit 1 --json databaseId --jq '.[0].databaseId'
if (-not $RunId) { throw "Exécution CI introuvable pour $HotfixCommit." }
gh run view $RunId --json headSha,status,conclusion,url
gh run watch $RunId
if ($LASTEXITCODE -ne 0) { throw "La CI de main a échoué." }
```

Puis exécuter la synchronisation détaillée en section G **avant** la RC. Ne pas créer le tag RC avant que `$HotfixCommit` soit présent dans `origin/develop`.

**Contrôle :** fusion `merge` (jamais squash), CI verte sur `main`, `$HotfixCommit` identifié.

**Preuve :** PR fusionnée, commit de fusion, CI `main`.

**Passage :** CI `main` verte et synchronisation `develop` terminée.

**Arrêt :** CI `main` rouge, fusion incorrecte, synchronisation impossible.

### C.7 Préparer la RC staging

La synchronisation G doit être terminée. Vérifier :

```powershell
git fetch origin main develop
if ($LASTEXITCODE -ne 0) { throw "Impossible de récupérer main et develop." }
git rev-parse origin/main
git rev-parse origin/develop
git merge-base --is-ancestor $HotfixCommit origin/main
if ($LASTEXITCODE -ne 0) { throw "Le hotfix n'est pas dans origin/main : NO-GO." }
git merge-base --is-ancestor $HotfixCommit origin/develop
if ($LASTEXITCODE -ne 0) { throw "Le hotfix n'est pas dans origin/develop : synchronisation incomplète." }
```

Créer et pousser le tag RC annoté sur le HEAD de `main` :

```powershell
git switch main
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw "Impossible de mettre main à jour." }
if ((git rev-parse HEAD).Trim() -ne $HotfixCommit.Trim()) { throw "main a avancé : nouvelle synchronisation et nouvelle RC requises." }
git rev-parse --verify --quiet "refs/tags/$RcVersion"
if ($LASTEXITCODE -eq 0) { throw "Le tag RC existe déjà en local." }
$ExistingRcTag = git ls-remote --tags --refs origin "refs/tags/$RcVersion"
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier le tag RC sur le dépôt distant." }
if ($ExistingRcTag) { throw "Le tag RC existe déjà sur le dépôt distant." }
$StableTagsAtCommit = git tag --points-at $HotfixCommit | Where-Object { $_ -match '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' }
if ($StableTagsAtCommit) { throw "Un tag stable pointe déjà sur le commit." }
git tag -a $RcVersion -m $RcVersion
git push origin $RcVersion
$RcCommit = git rev-parse "$RcVersion^{commit}"
git tag --points-at $RcCommit
```

Le push du tag déclenche deux workflows : `release`, qui valide la RC via `validate-release-tag.sh` et crée la prérelease, et `deploy-staging`, qui construit et déploie le paquet. Les deux doivent réussir. Attendre l'apparition de l'exécution `release`, puis :

```powershell
$ReleaseRunId = gh run list --workflow release.yml --branch $RcVersion --limit 1 --json databaseId --jq '.[0].databaseId'
if (-not $ReleaseRunId) { throw "Exécution release introuvable pour la RC." }
gh run view $ReleaseRunId --json headSha,status,conclusion,url
gh run watch $ReleaseRunId
if ($LASTEXITCODE -ne 0) { throw "Le workflow release de la RC a échoué." }
```

**Contrôle :** tag annoté, RC sur le HEAD de `main`, présente dans `develop`, aucun tag stable sur le commit, version PATCH correcte.

**Preuve :** tag, release prérelease, exécution `deploy-staging`.

**Passage :** staging déployé avec succès.

**Arrêt :** tag existant, tag non annoté, `main` avancée, RC absente de `develop`, staging en échec.

### C.8 Déployer en staging et exécuter la recette

Attendre l'apparition de l'exécution `deploy-staging`, puis :

```powershell
$StagingRunId = gh run list --workflow deploy-staging.yml --branch $RcVersion --limit 1 --json databaseId --jq '.[0].databaseId'
if (-not $StagingRunId) { throw "Exécution staging introuvable pour la RC." }
gh run view $StagingRunId --json headSha,status,conclusion,url
gh run watch $StagingRunId
if ($LASTEXITCODE -ne 0) { throw "Le déploiement staging a échoué." }
```

Contrôles :

- exécution staging réussie pour le commit de la RC ;
- paquet `chantier-package-$RcVersion` et manifeste `chantier-manifest-$RcVersion` publiés ;
- staging répond `/up` ;
- si migration : appliquée manuellement en staging selon la section D.3, après contrôles et GO, puis vérifiée ;
- recette du correctif, test de non-régression, fonctions adjacentes ;
- files, workers, planificateur et journaux vérifiés ;
- aucun email réel envoyé depuis staging.

**Preuve :** exécution staging, artefact, manifeste, résultat de recette, `/up`.

**Passage :** recette staging réussie.

**Arrêt :** staging en échec, recette en échec, artefact absent, manifeste incohérent.

### C.9 Créer le tag stable et publier la release

Vérifier que `main` n'a pas avancé et que la RC est toujours valide :

```powershell
git switch main
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw "Impossible de mettre main à jour." }
$MainHead = (git rev-parse HEAD).Trim()
if ($MainHead -ne $RcCommit.Trim()) { throw "main a avancé depuis la RC : arrêt et nouvelle RC requise." }
git merge-base --is-ancestor "$RcVersion^{commit}" HEAD
git rev-parse --verify --quiet "refs/tags/$Version"
if ($LASTEXITCODE -eq 0) { throw "Le tag stable existe déjà en local." }
$ExistingStableTag = git ls-remote --tags --refs origin "refs/tags/$Version"
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier le tag stable sur le dépôt distant." }
if ($ExistingStableTag) { throw "Le tag stable existe déjà sur le dépôt distant." }
$StableTagsAtCommit = git tag --points-at $HotfixCommit | Where-Object { $_ -match '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' }
if ($StableTagsAtCommit) { throw "Un tag stable pointe déjà sur le commit." }
git tag --points-at $HotfixCommit
```

Créer le tag stable sur `main` :

```powershell
git tag -a $Version -m $Version
git push origin $Version
```

Attendre l'apparition de l'exécution `release` qui crée la release en brouillon, puis :

```powershell
$ReleaseRunId = gh run list --workflow release.yml --branch $Version --limit 1 --json databaseId --jq '.[0].databaseId'
if (-not $ReleaseRunId) { throw "Exécution release introuvable pour le tag stable." }
gh run view $ReleaseRunId --json headSha,status,conclusion,url
gh run watch $ReleaseRunId
if ($LASTEXITCODE -ne 0) { throw "Le workflow release du tag stable a échoué." }
```

Vérifier la release en brouillon :

```powershell
gh release view $Version --json tagName,isDraft,isPrerelease,body,url
```

Contrôles :

- tag stable annoté sur le HEAD de `main` ;
- release brouillon, pas prérelease ;
- ligne `Staging-Candidate: $RcVersion` présente ;
- notes correctes, aucun changement non prévu, aucun secret ;
- arbre Git de la RC identique à celui du tag stable.

Enregistrer le GO de publication dans la PR du hotfix, puis publier :

```powershell
gh pr comment $Pr --body "GO publication production — $(Get-Date -Format o) — VOTRE_NOM — $Version"
# La commande suivante publie la release et déclenche deploy-production : GO préalable obligatoire.
gh release edit $Version --draft=false
```

**Preuve :** tag stable, release brouillon vérifiée, ligne `Staging-Candidate`, GO de publication.

**Passage :** release publiée.

**Arrêt :** candidate absente, arbre différent, `main` avancée, notes incorrectes, secret détecté.

### C.10 Promouvoir et vérifier en production

La publication de la release déclenche `deploy-production`. L'approbation de l'environnement `production` est obligatoire ; si l'environnement n'est pas configuré, le hotfix est NO-GO. Attendre l'apparition de l'exécution, puis :

```powershell
$ProductionRunId = gh run list --workflow deploy-production.yml --branch $Version --limit 1 --json databaseId --jq '.[0].databaseId'
if (-not $ProductionRunId) { throw "Exécution production introuvable pour le tag stable." }
gh run view $ProductionRunId --json headSha,status,conclusion,url
gh run watch $ProductionRunId
if ($LASTEXITCODE -ne 0) { throw "Le déploiement production a échoué." }
```

Contrôles :

- `validate-promotion` retrouve la RC, l'exécution staging, l'artefact et le manifeste ;
- le paquet téléchargé est exactement celui de staging, sans reconstruction ;
- SHA-256, manifeste, commit et arbre sont cohérents ;
- le job protégé revalide le tag stable et l'artefact ;
- `/up` production répond `200` avec `{"status":"up"}` ;
- `release.json` contient la version et le commit attendus ;
- test de fumée du correctif et fonctions adjacentes ;
- journaux, files, workers et planificateur vérifiés.

**Preuve :** exécution production, artefact réutilisé, manifeste, `release.json`, `/up`, test de fumée, journaux.

**Passage :** production saine et correctif vérifié.

**Arrêt :** promotion refusée, artefact incohérent, health check en échec, régression, erreur critique.

## D. Gestion des migrations

### D.1 Décision

| Cas | Décision |
| --- | --- |
| Aucune migration | Poursuivre ; `migrate:status` est une lecture, à consigner. |
| Migration additive A/B, N/N-1 démontrée, testée MariaDB, sauvegarde vérifiée | Poursuivre avec plan manuel et GO. |
| Migration C, D ou E, destructive, Contract, boot-critical ou N/N-1 non démontrée | **NO-GO** : processus normal de release. |

### D.2 Avant déploiement

- [ ] Classification de la migration et justification.
- [ ] Aucune opération destructive.
- [ ] Compatibilité N/N-1 démontrée.
- [ ] Test en staging sur MariaDB 10.11.
- [ ] Sauvegarde complète vérifiée et restaurabilité connue.
- [ ] Fenêtre d'exécution et impact estimés.
- [ ] Plan de reprise et rollback décidés.
- [ ] `migrate:status` de la release active lu et consigné.

```bash
cd "$ROOT/current"
"$PHP" artisan migrate:status --no-ansi
```

`migrate:status` exécuté depuis la release active ne montre que les migrations connues de cette release ; il ne prouve pas à lui seul l'état complet du schéma. La migration du hotfix n'est pas encore présente dans `current` avant le déploiement.

### D.3 Après déploiement et avant migration

La migration n'est exécutée qu'après activation de la nouvelle release, lorsque `current` contient le fichier de migration, et avant l'usage de la fonctionnalité corrigée. Vérifier d'abord que `current` pointe bien vers la nouvelle release et que `release.json` est cohérent.

- [ ] `current` pointe vers la release attendue ; `release.json` est cohérent.
- [ ] `migrate:status` relu depuis la nouvelle release.
- [ ] `--pretend` exécuté et SQL relu.
- [ ] `SHOW PROCESSLIST` vérifié, aucune transaction longue.
- [ ] Sauvegarde vérifiée et GO explicite enregistrés.

```bash
cd "$ROOT/current"
"$PHP" artisan migrate:status --no-ansi
"$PHP" artisan migrate --force --pretend \
  --path="$ROOT/current/database/migrations/<migration>.php" --realpath
```

La commande `--pretend` est une simulation ; elle ne doit pas être confondue avec une validation réelle.

Exécuter ensuite la migration manuellement, avec le compte technique, après GO :

```bash
# Après GO explicite et sauvegarde vérifiée uniquement.
"$PHP" artisan migrate --force --isolated \
  --path="$ROOT/current/database/migrations/<migration>.php" --realpath
```

- Surveiller la sortie, les journaux et `SHOW PROCESSLIST`.
- Vérifier `migrate:status`, `SHOW CREATE TABLE`, les invariants, `/up`, les journaux et les files.
- Consigner l'heure, l'opérateur, la migration, le résultat et le ticket.
- Ne jamais exécuter `migrate:rollback`, `migrate:fresh`, `migrate:refresh`, `migrate:reset`, `db:wipe`.
- Ne jamais restaurer la base pour « annuler » une migration dans le cadre du hotfix.

### D.4 Migrations interdites dans un hotfix

- Suppression ou renommage de table/colonne.
- `TRUNCATE`, suppression massive de lignes.
- Rétrécissement de type, `NOT NULL` sans défaut sur table non vide.
- Index unique non préparé, clé étrangère rejetant N-1.
- Charset/collation/moteur/partitionnement.
- Contract ou migration dont l'absence empêche le démarrage de la release.

Si la correction nécessite l'un de ces changements, le hotfix est **NO-GO**. Une procédure spécifique, avec Expand/Migrate/Contract et validation séparée, est obligatoire.

## E. Déploiement et vérifications

### E.1 Provenance de l'artefact

L'artefact de production doit être **exactement** celui publié par l'exécution staging de la RC.

| Contrôle | Valeur attendue |
| --- | --- |
| Tag RC | `$RcVersion`, annoté, sur le commit de la RC |
| Exécution staging | Terminée avec succès pour le commit de la RC |
| Paquet | `chantier-package-$RcVersion` |
| Manifeste | `chantier-manifest-$RcVersion` |
| Commit / arbre | Identiques entre la RC et le tag stable |
| SHA-256 | Identique au manifeste et à l'artefact |
| Reconstruction | **Aucune** en production |

Commandes de vérification, sans redéploiement :

```powershell
gh release view $Version --json tagName,isDraft,isPrerelease,body,url
$ManifestDir = Join-Path $env:TEMP "manifest-$RcVersion"
gh run download $StagingRunId --name "chantier-manifest-$RcVersion" --dir $ManifestDir
$ManifestPath = Join-Path $ManifestDir "manifest.json"
php .github/scripts/lib/manifest.php validate $ManifestPath
php .github/scripts/lib/manifest.php get $ManifestPath version
php .github/scripts/lib/manifest.php get $ManifestPath commit_sha
php .github/scripts/lib/manifest.php get $ManifestPath tree_sha
php .github/scripts/lib/manifest.php get $ManifestPath artifact.sha256
```

Télécharger le paquet staging et vérifier son empreinte, sans reconstruction :

```powershell
$PackageDir = Join-Path $env:TEMP "package-$RcVersion"
gh run download $StagingRunId --name "chantier-package-$RcVersion" --dir $PackageDir
$PackagePath = Get-ChildItem $PackageDir -Filter *.tar.gz | Select-Object -First 1 -ExpandProperty FullName
Get-FileHash -Algorithm SHA256 $PackagePath
```

```bash
sha256sum chantier-$RcVersion.tar.gz
```

L'empreinte doit être identique à `artifact.sha256` du manifeste et à celle vérifiée par `deploy-production`.

### E.2 Health check et vérifications fonctionnelles

```bash
curl -fsS -H 'Accept: application/json' "https://chantier.c2me.fr/up"
```

Attendu : code `200` et `{"status":"up"}`.

Vérifier ensuite :

- `release.json` : `version` = `$Version`, `commit_sha` = `$HotfixCommit`, `environment` = `production`, `artifact_id` et `sha256` cohérents avec le manifeste ;
- test de fumée du correctif ;
- fonctions critiques adjacentes ;
- journaux applicatifs : aucune nouvelle erreur critique ;
- files, workers et planificateur ;
- absence de données sensibles dans les sorties et journaux.

### E.3 Surveillance post-déploiement

Surveillance renforcée pendant la fenêtre définie dans le ticket : erreurs, latence, files, jobs échoués, logs, retours utilisateurs. Toute anomalie critique déclenche la section F ou une décision de correction en avant. Aucun rollback automatique n'est exécuté.

## F. Rollback applicatif

La procédure de référence est [`application-rollback-runbook.md`](application-rollback-runbook.md). En cas de divergence, les règles de [`application-rollback.md`](application-rollback.md) prévalent.

### F.1 Déclencheurs

- health check production en échec après activation ;
- régression fonctionnelle critique ;
- erreur de configuration ou de permissions ;
- artefact incohérent ou version/commit erronés ;
- risque de sécurité ou de données.

### F.2 Décision et autorisation

- Décision humaine explicite du responsable release/production.
- Aucun rollback automatique.
- Vérifier que le rollback est préféré à une correction en avant.
- Vérifier la compatibilité N/N-1 et l'attestation.
- Si le rollback nécessite une restauration de données, s'arrêter : ce n'est pas un rollback applicatif.

### F.3 Préflight

```bash
readlink -f "$ROOT/current"
cat "$ROOT/current/release.json"
ls -1 "$ROOT/releases"
find "$ROOT/releases" -maxdepth 1 -name '.incoming-*' -print
supervisorctl status
# Après décision de rollback uniquement.
supervisorctl stop "$WORKER_PROGRAM"
pgrep -af 'queue:work|queue:listen|horizon'
test -f "$ROOT/shared/storage/framework/down" && echo 'maintenance actif' || echo 'maintenance inactif'
```

Contrôles :

- release cible antérieure, complète et lisible ;
- workers arrêtés, files en pause, jobs triés ;
- aucun déploiement en cours ;
- attestation N/N-1 valide ;
- schéma compatible avec la release cible ;
- jobs et fichiers persistants pris en compte.

### F.4 Contrôle à blanc

```bash
bash scripts/ops/rollback.sh \
  --env "$ENV" \
  --to "$TARGET_RELEASE" \
  --reason "régression constatée sur <fonctionnalité>" \
  --schema-attestation "/tmp/attestation-$ENV.json" \
  --confirm-workers-stopped \
  --confirm-queues-paused \
  --confirm-jobs-triaged \
  --dry-run
```

Le mode `--dry-run` valide la cible, les liens, l'attestation, les confirmations et la concurrence sans modifier `current`. Il n'écrit ni journal, ni verrou, ni fichier temporaire.

### F.5 Exécution et contrôles

Retirer `--dry-run` et exécuter la même commande après GO explicite. Le script prend le verrou partagé, bascule `current`, appelle `/up` et journalise.

Après l'exécution :

```bash
readlink -f "$ROOT/current"
cat "$ROOT/current/release.json"
ls -l "$ROOT/current/.env" "$ROOT/current/storage" "$ROOT/current/public/storage"
curl -fsS -H 'Accept: application/json' "https://chantier.c2me.fr/up"
tail -n 100 "$ROOT/shared/storage/logs/laravel.log"
```

Redémarrer les workers et reprendre les files manuellement selon la procédure de l'environnement. Vérifier les lectures/écritures représentatives, les files et le planificateur. Consigner source, cible, raison, attestation, health check, état des workers/files/jobs.

### F.6 Règles absolues

- Le rollback ne restaure **jamais** la base de données.
- Aucun `migrate:rollback`, `migrate:fresh`, `db:wipe` ou restauration improvisée.
- Une restauration de données est une opération distincte, isolée, avec perte de données assumée.
- Si le schéma n'est pas compatible avec la cible, le rollback est **NO-GO**.
- Si le health check échoue après bascule, la release cible reste active ; la décision est humaine.
- Si le rollback ne peut pas être effectué sans risque pour les données, arrêter et escalader.

## G. Synchronisation `main` → `develop`

La procédure détaillée et les commandes exactes sont définies dans [`hotfix-process.md`](hotfix-process.md), section 12 et section 17.10-17.12. Cette section reprend les points de contrôle opérationnels.

> **Ordre obligatoire.** La synchronisation est exécutée **avant** la RC, conformément à l'option A validée aux Lots 3 et 4. Ne pas créer le tag RC tant que `$HotfixCommit` n'est pas présent dans `origin/develop`.

### G.1 Préflight

```powershell
git fetch origin main develop
if ($LASTEXITCODE -ne 0) { throw "Impossible de récupérer main et develop." }
$MainSha = git rev-parse origin/main
$DevelopSha = git rev-parse origin/develop
$DevelopBeforeSync = $DevelopSha
git merge-base --is-ancestor $HotfixCommit origin/main
if ($LASTEXITCODE -ne 0) { throw "Le hotfix n'est pas dans origin/main : NO-GO." }
git merge-base --is-ancestor $HotfixCommit origin/develop
$HotfixInDevelop = $LASTEXITCODE -eq 0
git merge-base --is-ancestor origin/main origin/develop
$MainInDevelop = $LASTEXITCODE -eq 0
$HotfixInDevelop
$MainInDevelop
```

`git merge-base --is-ancestor` renvoie `1` lorsque la relation testée est fausse ; ce n'est pas une erreur d'exécution. Interpréter les booléens produits, pas le message. Ensuite :

- si `$HotfixInDevelop` et `$MainInDevelop` sont vrais : aucune PR n'est nécessaire ; vérifier le contenu et la CI de `develop`.
- si `$HotfixInDevelop` est faux ou `$MainInDevelop` est faux : poursuivre la synchronisation.
- vérifier que les SHA locaux correspondent aux SHA distants (`git ls-remote`) ; si les références ont changé, refaire le fetch et recommencer.

### G.2 PR directe ou branche de synchronisation

- **PR directe `main` → `develop`** : uniquement si la fusion est propre et qu'aucune résolution locale n'est nécessaire.
- **Branche `bugfix/CHAN-<numéro>-synchronisation-hotfix` depuis `develop`** : obligatoire en cas de conflit, de résolution locale ou de vérification sur branche.

**Variante PR directe** (aucune branche intermédiaire, aucun push sur `develop`) :

```powershell
$SyncUrl = gh pr create --base develop --head main --title "chore(sync): reporter le hotfix $Ticket dans develop" --body-file $SyncBody
$SyncPr = gh pr view $SyncUrl --json number --jq '.number'
gh pr view $SyncPr --json number,baseRefName,headRefName,isDraft,mergeable,mergeStateStatus,statusCheckRollup,url
```

Si GitHub signale un conflit ou si une résolution locale est nécessaire, abandonner cette variante et utiliser la branche de synchronisation ci-dessous. Sinon, passer à la CI et à la fusion en section G.4, sans push de branche.

**Variante branche de synchronisation** :

```powershell
git fetch origin main develop
if ($LASTEXITCODE -ne 0) { throw "Impossible de récupérer main et develop." }
git rev-parse --verify --quiet "refs/heads/$SyncBranch"
if ($LASTEXITCODE -eq 0) { throw "La branche locale existe déjà." }
$ExistingSyncBranch = git ls-remote --heads origin $SyncBranch
if ($LASTEXITCODE -ne 0) { throw "Impossible de vérifier la branche de synchronisation sur le dépôt distant." }
if ($ExistingSyncBranch) { throw "La branche distante existe déjà." }
git switch -c $SyncBranch origin/develop
git merge-base --is-ancestor origin/develop HEAD
if ($LASTEXITCODE -ne 0) { throw "La branche n'est pas basée sur origin/develop." }
git merge --no-edit origin/main
$MergeStatus = $LASTEXITCODE
$MergeStatus
git status --short
git diff --name-only --diff-filter=U
```

Un `$MergeStatus` non nul signale un conflit à traiter en section G.3 ; ne pas supprimer la branche ni forcer la fusion.

### G.3 Résolution des conflits

- Résoudre fichier par fichier.
- Ne pas supprimer le hotfix.
- Ne pas écraser les évolutions de `develop`.
- Ne pas utiliser `-X ours`, `-X theirs`, `git checkout --ours` ou `git checkout --theirs` globalement sans revue.
- Vérifier que le hotfix et le `DEVELOP_SHA` initial sont ancêtres de la branche.
- Vérifier que le diff ne supprime pas de fichier propre à `develop`.
- Exécuter les tests et `composer ci:check`.
- Si la résolution exige de choisir arbitrairement entre deux évolutions, s'arrêter et escalader.

### G.4 PR, CI et fusion

```powershell
# Variante branche de synchronisation uniquement.
git push -u origin $SyncBranch
$SyncUrl = gh pr create --base develop --head $SyncBranch --title "chore(sync): reporter le hotfix $Ticket dans develop" --body-file $SyncBody
$SyncPr = gh pr view $SyncUrl --json number --jq '.number'
gh pr view $SyncPr --json number,baseRefName,headRefName,isDraft,mergeable,mergeStateStatus,statusCheckRollup,url
gh pr checks $SyncPr --watch
if ($LASTEXITCODE -ne 0) { throw "La CI de synchronisation n'est pas verte." }
gh pr merge $SyncPr --merge
if ($LASTEXITCODE -ne 0) { throw "La fusion de la synchronisation a échoué." }
```

Pour la variante PR directe, ne pas exécuter `git push` ni recréer la PR : réutiliser le `$SyncPr` de la section G.2, puis exécuter `gh pr checks` et `gh pr merge`.

Avant la fusion, appliquer la revue technique selon [`pull-request-review.md`](pull-request-review.md), résoudre les commentaires et vérifier que la PR ne contient que la synchronisation attendue. Aucun rebase, aucun squash, aucun push direct sur `develop`.

### G.5 Vérification

```powershell
git fetch origin develop
if ($LASTEXITCODE -ne 0) { throw "Impossible de récupérer develop." }
git merge-base --is-ancestor $HotfixCommit origin/develop
if ($LASTEXITCODE -ne 0) { throw "Le hotfix n'est pas dans origin/develop." }
git merge-base --is-ancestor $DevelopBeforeSync origin/develop
if ($LASTEXITCODE -ne 0) { throw "Une évolution de develop a été perdue pendant la synchronisation." }
git log --oneline --decorate --graph -15
git show --stat $HotfixCommit
php artisan test $RegressionTest
if ($LASTEXITCODE -ne 0) { throw "Le test de non-régression échoue dans develop." }
```

La synchronisation n'est terminée que si les deux SHA sont ancêtres de `origin/develop`, que le correctif est présent, que le test est vert, que l'historique contient les deux branches et que la CI de `develop` est verte. Aucune nouvelle release depuis `develop` avant ces vérifications.

## H. Clôture de l'incident

- [ ] Le correctif fonctionne en production pendant la fenêtre de surveillance convenue.
- [ ] `release.json` contient la version et le commit attendus.
- [ ] Le tag stable, la release publiée et le déploiement production sont cohérents.
- [ ] La synchronisation `main` → `develop` est terminée et vérifiée.
- [ ] Les preuves sont conservées dans Jira et/ou la PR :
  - ticket, sévérité, décision GO/NO-GO, responsable ;
  - version de production, `release.json`, tag/release ;
  - PR hotfix, CI, GO, commit de fusion ;
  - PR de synchronisation, CI, vérification des historiques ;
  - tag RC, exécution staging, artefact, manifeste, SHA-256 ;
  - tag stable, release publiée, notes, `Staging-Candidate` ;
  - exécution production, approbation, `/up`, `release.json`, test de fumée ;
  - décision de rollback ou de correction en avant, si applicable ;
  - post-mortem.
- [ ] Les tickets Jira sont mis à jour avec les liens et le statut final.
- [ ] La documentation impactée est mise à jour.
- [ ] Les personnes concernées sont informées via le canal défini par l'organisation.
- [ ] Un post-mortem est rédigé pour tout P1/P2.
- [ ] Les actions préventives sont identifiées, attribuées et datées.

Aucun secret, token, mot de passe, clé privée ou donnée personnelle réelle ne doit apparaître dans les preuves.

## I. Checklist opérationnelle

### Qualification

- [ ] Incident identifié et ticket Jira ouvert.
- [ ] Impact, sévérité P1/P2 et responsable consignés.
- [ ] Rollback évalué avant le hotfix.
- [ ] Décision GO/NO-GO écrite et attribuée.
- [ ] Aucun critère NO-GO de la section A.4.

### Préparation

- [ ] `release.json`, tag, release et commit de production cohérents.
- [ ] `main` alignée sur la production ; `develop` identifiée.
- [ ] Aucun tag `$Version` ou `$RcVersion` existant.
- [ ] Aucune release, déploiement ou rollback en cours.
- [ ] Environnements et secrets disponibles.
- [ ] Sauvegarde vérifiée, ou absence acceptée pour un hotfix code-only.
- [ ] Migration classée A/B, N/N-1 démontrée, MariaDB testée.
- [ ] Rollback possible et attestation disponible.
- [ ] Aucun critère NO-GO de la section B.7.

### Correctif

- [ ] Branche créée depuis le commit de production.
- [ ] Correctif minimal, test de non-régression ajouté.
- [ ] `composer lint:check`, `types:check`, `php artisan test` et `ci:check` verts.
- [ ] MariaDB et build frontend si concernés.
- [ ] `git diff --check` et périmètre vérifiés.
- [ ] PR vers `main` avec les informations obligatoires.
- [ ] CI verte, revue traitée, email attribué.
- [ ] GO humain enregistré.
- [ ] Fusion `merge`, CI `main` verte, `$HotfixCommit` consigné.

### Synchronisation avant RC

- [ ] `main` et `develop` récupérés et SHA consignés.
- [ ] `$HotfixCommit` présent dans `main`.
- [ ] PR directe ou branche `bugfix/CHAN-<numéro>-synchronisation-hotfix`.
- [ ] Conflits résolus sans écraser `develop`.
- [ ] CI de synchronisation verte.
- [ ] `$HotfixCommit` et `$DevelopBeforeSync` ancêtres de `origin/develop`.
- [ ] Test de non-régression vert dans `develop`.

### Release et staging

- [ ] Tag RC annoté sur le HEAD de `main`, présent dans `develop`.
- [ ] Aucun tag stable sur le commit.
- [ ] Release prérelease créée.
- [ ] `deploy-staging` réussi pour le commit de la RC.
- [ ] Paquet et manifeste publiés ; SHA-256 vérifié.
- [ ] Staging `/up` et recette du correctif réussis.

### Production

- [ ] Tag stable annoté sur le HEAD de `main`.
- [ ] Release brouillon vérifiée, `Staging-Candidate` présente.
- [ ] Arbre Git RC/stable identique.
- [ ] Release publiée après GO.
- [ ] `deploy-production` réussi, même artefact, aucune reconstruction.
- [ ] Approbation de l'environnement `production` obtenue.
- [ ] `/up` production, `release.json`, test de fumée, journaux, files et planificateur vérifiés.
- [ ] Surveillance post-déploiement effectuée.
- [ ] Aucun rollback automatique déclenché.

### Clôture

- [ ] Synchronisation `develop` vérifiée après le hotfix et avant la RC.
- [ ] Preuves complètes conservées.
- [ ] Jira mis à jour.
- [ ] Documentation mise à jour si nécessaire.
- [ ] Communication effectuée.
- [ ] Post-mortem et actions préventives pour P1/P2.

## Références

- [`AGENTS.md`](../../AGENTS.md) — règles impératives.
- [`README.md`](../../README.md) — présentation et démarrage.
- [`hotfix-process.md`](hotfix-process.md) — processus de hotfix et commandes Git détaillées.
- [`git-workflow.md`](git-workflow.md) — branches, commits, PR et protections.
- [`release-process.md`](release-process.md) — versionnement, tags et releases.
- [`deployment-process.md`](deployment-process.md) — artefacts, promotion et déploiement.
- [`environments.md`](environments.md) — environnements, secrets et protections.
- [`database-migrations.md`](database-migrations.md) — migrations et compatibilité N/N-1.
- [`application-rollback.md`](application-rollback.md) — politique de rollback.
- [`application-rollback-runbook.md`](application-rollback-runbook.md) — procédure opérateur de rollback.
- [`backup-restore.md`](backup-restore.md) — stratégie de sauvegarde et de restauration.
- [`backup-restore-runbook.md`](backup-restore-runbook.md) — procédure opérateur de sauvegarde/restauration.
- [`pull-request-review.md`](pull-request-review.md) — revue technique.
- [`testing.md`](testing.md) — suites de tests et commandes.
- [`tests.yml`](../../.github/workflows/tests.yml) — CI.
- [`release.yml`](../../.github/workflows/release.yml) — release.
- [`deploy-staging.yml`](../../.github/workflows/deploy-staging.yml) — staging.
- [`deploy-production.yml`](../../.github/workflows/deploy-production.yml) — production.
- [`validate-release-tag.sh`](../../.github/scripts/deploy/validate-release-tag.sh) — validation des tags de release.
- [`stable-candidate.sh`](../../.github/scripts/deploy/stable-candidate.sh) — référence de la candidate staging.
- [`resolve-promotion.sh`](../../.github/scripts/deploy/resolve-promotion.sh) — promotion staging → production.
- [`rollback.sh`](../../scripts/ops/rollback.sh) — rollback applicatif.
- [`backup.sh`](../../scripts/ops/backup.sh) — sauvegarde.
- [`restore.sh`](../../scripts/ops/restore.sh) — restauration isolée.
