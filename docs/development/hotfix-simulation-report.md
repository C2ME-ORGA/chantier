# Rapport de simulation — processus de hotfix (CHAN-99, Lot 6)

- Date d’exécution : 18 novembre 2026.
- Périmètre : simulation locale et reproductible du processus décrit dans
  [`hotfix-process.md`](hotfix-process.md), [`hotfix-runbook.md`](hotfix-runbook.md),
  [`git-workflow.md`](git-workflow.md), [`release-process.md`](release-process.md),
  [`deployment-process.md`](deployment-process.md) et
  [`application-rollback-runbook.md`](application-rollback-runbook.md).
- Statut global : **PASS** (29 étapes/scénarios, 0 FAIL, 0 NOT RUN).
- Preuves : les preuves détaillées du run sont conservées localement dans le
  répertoire temporaire `chan99-lot6-final3/run` (hôte Windows), monté en
  `/out/run` dans le conteneur Ubuntu 24.04. Ce répertoire n’est pas versionné
  et n’est pas publié avec la PR. Le détail reproductible est régénéré par
  [`scripts/simulation/run-hotfix-simulation.sh`](../../scripts/simulation/run-hotfix-simulation.sh).

> Cette simulation n’a effectué aucun push vers le dépôt GitHub réel, aucune
> Pull Request réelle, aucun merge sur `main` ou `develop` du dépôt, aucun tag
> ou release réel, aucun déploiement, aucun rollback et aucune opération de
> base de données réelle.

## 1. Architecture de simulation

Tout est créé sous un répertoire de sortie dédié :

```text
<sortie>/
  repo/work/                 dépôt Git de travail
  remote.git/                remote bare local + hook pre-receive
  registry/                  registre d’artefacts consommé par un faux `gh`
  artifacts/                 paquets et manifestes
  envs/staging/              releases, current, shared
  envs/production/           releases, current, shared
  rollback/                  bac à sable du rollback applicatif
  scenarios/sync-conflict/   dépôt isolé du scénario de conflit
  state/pr/                  état des Pull Requests simulées
  evidence/                  preuves JSON, graphes, SHA, journaux
  report/                    results.tsv, summary.json, rapport
```

Éléments structurants :

- **Remote local** : dépôt bare créé sous la sortie. Un hook `pre-receive`
  refuse toute mise à jour de `refs/heads/main` et `refs/heads/develop` lorsque
  la branche existe déjà. Les fusions de PR sont appliquées côté « serveur »
  par mise à jour de référence après publication des objets, comme le ferait
  GitHub.
- **PR simulée** : ouverture avec source/destination, exécution CI, GO humain
  enregistré, refus du squash, fusion `--no-ff` avec deux parents.
- **CI simulée** : `php -l` sur l’application factice et exécution d’un runner
  de tests PHP minimal. Les jobs `ci`, `sqlite`, `mariadb-10.11` et
  `package-linux` partagent le même verdict, ce qui permet de tester le gate.
- **Artefact** : paquet réellement produit par `assemble-package.sh`, manifeste
  réellement validé par `manifest.php`, registre local et faux `gh` pour
  exécuter `resolve-promotion.sh` sans réseau.
- **Déploiement** : extraction du paquet, `release.json`, liens `shared`,
  bascule atomique de `current`, serveur PHP local et health check HTTP réel
  sur `/up`, `/version` et `/api/total`.
- **Rollback** : script réel `scripts/ops/rollback.sh`, avec `C2ME_ROOT`
  temporaire, faux `curl`, journal des appels PHP et attestation N/N-1.

## 2. Commandes et outils

Exécution principale (Docker Ubuntu 24.04, dépôt monté en lecture seule) :

```bash
docker run --rm \
  -v "$PWD:/src:ro" \
  -v "<sortie>:/out" \
  -w /src ubuntu:24.04 \
  bash -lc "apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    git php-cli curl ca-certificates && \
    bash scripts/simulation/run-hotfix-simulation.sh --output /out/run"
```

Outils : Git 2.43, PHP 8.3.6 (conteneur), PHP 8.4.27 (hôte), Bash 5.2, GNU tar
1.35, coreutils 9.4, Docker 29.1.3.

Validations complémentaires : `composer lint:check`, `composer types:check`,
`php artisan test`, `validate-workflows.php`, suites d’automatisation release,
déploiement, rollback et sauvegarde/restauration, `docs-check.php` et
`check-docs.ps1`.

## 3. Scénario nominal

### E01 — Qualification

Incident P1 qualifié **GO** avec responsable identifié, fiche d’incident
conservée. Un incident P3/P4 est refusé avec le motif « P1/P2 requis ».

### E02 — Préparation

- Tag de production `v1.4.2` annoté.
- `main` alignée sur le commit de production.
- `develop` en avance de deux commits.
- `release.json` de production cohérent (version, commit, environnement).
- Aucun tag cible existant.
- Un déplacement simulé de `main` fait échouer le préflight (S02), puis la
  référence est restaurée.

### E03 — Branche et correctif

- Branche `hotfix/CHAN-99-simulation` créée depuis `origin/main`.
- Vérification que la branche ne contient aucun commit de `develop`.
- Commit de test de non-régression (le test échoue avant correctif).
- Commit `fix(greeting): corriger le calcul du total`.
- Tests locaux verts après correctif, `php -l` et `git diff --check` verts.
- Périmètre limité à `app/Greeting.php` et
  `tests/GreetingRegressionTest.php`.

Commits :

| Commit | SHA | Sujet |
| --- | --- | --- |
| Test | `8e303908390dbcdd3e0ec4328eadb58adef1268d` | `test(greeting): ajouter un test de non-régression pour le total` |
| Correctif | `7d708e2a5a34b24c147442a5fd3b32a1ef4a433d` | `fix(greeting): corriger le calcul du total` |

### E04 — Pull Request vers main

- Push de la branche temporaire autorisé.
- Push direct sur `main` et `develop` refusé par le hook.
- PR `hotfix/CHAN-99-simulation` → `main`, CI verte.
- Fusion refusée sans GO humain.
- Fusion squash refusée.
- Fusion `--merge` avec deux parents : commit
  `a8c152a598440d50fb3dcba234a3f9ec4b201b30`.
- CI verte sur `main` après fusion.

### E05 — Synchronisation main → develop

- Préflight des SHA consigné.
- PR directe `main` → `develop` sans conflit.
- Commit de synchronisation :
  `318a5bd4e6767ea8d0f8caf5f83b0e30212cbe7c`.
- `develop` initial `c26822b387c8446cd8f187321594c53b237fc5ce` conservé.
- Développements propres à `develop` conservés.
- CI verte sur `develop`.

### E06 — Release candidate

- Tag annoté `v1.4.3-rc.1` sur `a8c152a598440d50fb3dcba234a3f9ec4b201b30`
  (HEAD de `main`, présent dans `develop`).
- `validate-release-tag.sh` : `release_type=release-candidate`,
  `hotfix_rc=true`, `head_matches=false`.
- Aucun tag stable sur ce commit.

### E07 — Artefact et staging

- Paquet `chantier-v1.4.3-rc.1.tar.gz` produit par `assemble-package.sh`.
- SHA-256 :
  `d9d6397f281eec9f5e46a0696fab62572f9c87e80c315a93bfd0ffdb42950aa5`.
- Archive sans `.env`, sans `.git`, sans `tests`, avec assets Vite.
- Manifeste staging valide : tag RC, commit
  `a8c152a598440d50fb3dcba234a3f9ec4b201b30`, arbre
  `b8fd1d50e36dd2bf6329694ac38d1bb8bc11483e`, run `1001`, artefact `5001`.
- Déploiement staging `v1.4.3-rc.1-1001`, health check `/up` = 200
  `{"status":"up"}`, version et test fonctionnel (`total=5`) vérifiés.
- Artefact intact après déploiement.

### E08 — Promotion production

- Tag stable annoté `v1.4.3` sur le même commit que la RC.
- `stable-candidate.sh` ajoute `Staging-Candidate: v1.4.3-rc.1`.
- `validate-release.sh` extrait la candidate.
- `resolve-promotion.sh` vérifie commit, arbre, exécution staging, manifeste
  et SHA-256, puis télécharge l’artefact d’origine.
- L’artefact promu est **byte pour byte** identique à celui de staging
  (`cmp` et SHA-256), sans reconstruction.
- Déploiement production simulé `v1.4.3-1002`, health check et test
  fonctionnel verts.

### E09 — Vérifications post-déploiement

- `/up` = 200 `{"status":"up"}`.
- Version `v1.4.3` et commit
  `a8c152a598440d50fb3dcba234a3f9ec4b201b30` confirmés par l’application.
- Test fonctionnel `GET /api/total?a=3&b=2` = `{"total":5}`.
- `release.json` cohérent avec le manifeste et l’empreinte de l’artefact.

### E10 — Clôture

- Correctif présent dans `main` et dans `develop`.
- Tags `v1.4.3-rc.1` et `v1.4.3` cohérents, annotés, sur le même commit.
- Manifeste et artefact traçables.
- Éléments de clôture conservés.

## 4. Scénarios d’échec

| ID | Scénario | Comportement attendu | Résultat observé |
| --- | --- | --- | --- |
| S01 | Incident non P1/P2 | Refus | PASS — NO-GO P4, motif « P1/P2 requis » |
| S02 | Références Git obsolètes | Arrêt du préflight | PASS — `main` avancée, préflight refusé |
| S03 | Branche hotfix créée depuis `develop` | Refus | PASS — branche contenant `develop` refusée |
| S04 | CI en échec | Interdiction de poursuivre | PASS — CI rouge, fusion refusée par le gate |
| S05 | RC sur un commit non autorisé | Refus | PASS — commit différent du HEAD de `main` |
| S06 | RC sur un commit déjà stable | Refus | PASS — `v1.4.2` pointe déjà sur ce commit |
| S07 | Tag stable sur un commit incorrect | Refus | PASS — tag stable hors HEAD de `main` |
| S08 | Manifeste altéré | Refus | PASS — `commit_sha` incohérent |
| S09 | SHA-256 incorrect | Refus | PASS — empreinte publiée non conforme |
| S10 | Artefact différent entre staging et production | Refus | PASS — artefact différent du manifeste staging |
| S11 | Health check en échec | Arrêt et décision de rollback | PASS — échec détecté, décision consignée, aucun rollback automatique |
| S12 | Migration destructive | NO-GO | PASS — opération destructrice sans `@contract`/`@destructive` |
| S13 | Migration incompatible N/N-1 | NO-GO | PASS — colonne NOT NULL sans défaut |
| S14 | Rollback avec risque sur les données | Arrêt et escalade | PASS — attestation `destructive_applied=true` refusée |
| S15 | Synchronisation avec conflit | Résolution sur branche temporaire | PASS — conflit détecté, résolu sur `bugfix/CHAN-99-simulation-synchronisation-hotfix`, historiques conservés |
| S16 | Push direct sur branche protégée | Refus | PASS — hook `pre-receive`, `main` et `develop` inchangées |

Chaque scénario a produit des preuves dans `evidence/` (JSON, journaux,
messages de refus) et aucune opération interdite n’a modifié le remote local :
les SHA de `main` et `develop` sont comparés avant/après les tentatives.

## 5. Rollback applicatif simulé (R01)

- Source : `v1.4.3-1002` (version activée).
- Cible : `v1.4.2-9000`.
- Attestation N/N-1 valide, SHA-256
  `01b66fa478e9dd1d4c55fe53cd81e37596265257fffd77e28912923e5baae532`.
- `--dry-run` : `PLAN=ok`, `MODE=dry-run`, `current` inchangé, aucun journal
  ni verrou écrit.
- Exécution réelle : `ROLLBACK=ok`, `HEALTH=ok`, `current` pointe sur
  `v1.4.2-9000`.
- Données simulées : fichier `shared/storage/app/private/document.txt`
  inchangé (SHA avant = SHA après), `.env` partagé inchangé, lien `storage`
  préservé.
- Journal : `result=success`, `health=ok`, `dry_run=false`.
- Aucun appel `artisan`, aucun `migrate:rollback`, `migrate:fresh`,
  `migrate:reset` ou `db:wipe` dans le journal des appels PHP.
- Workers et files : confirmations `--confirm-workers-stopped`,
  `--confirm-queues-paused`, `--confirm-jobs-triaged` ; le script ne modifie
  ni les workers ni les files (message explicite conservé).
- Opération : `rollback-production-20261118T083101Z-d8e29e56`.

## 6. Résultats des validations

| Contrôle | Résultat | Compteurs |
| --- | --- | --- |
| Simulation hotfix (conteneur Ubuntu 24.04) | PASS | 29 étapes/scénarios, 0 FAIL, 0 NOT RUN, 129 contrôles élémentaires |
| Liens documentaires | PASS | 223 liens, 7 documents (dont ce rapport) |
| Blocs Bash | PASS | 18 blocs (`bash -n`) |
| Blocs PowerShell | PASS | 66 blocs, 0 erreur (Windows PowerShell 5.1) |
| `test-release-automation.sh` | PASS | 54 assertions, 0 échec |
| `test-deployment-automation.sh` | PASS | 397 assertions, 0 échec, 3 SKIP (permissions non simulables en root) |
| `test-rollback.sh` | PASS | 160 tests, 0 échec, 0 ignoré |
| `test-backup-restore.sh` | PASS | 188 tests, 0 échec |
| `validate-workflows.php` | PASS | 271 contrôles, 0 échec |
| `composer lint:check` (Pint) | PASS | — |
| `composer types:check` (Larastan) | PASS | 0 erreur |
| `php artisan test` (Pest) | PASS | 171 tests, 1 221 assertions |
| `git diff --check` | PASS | aucun problème |
| `test-assemble-linux.sh` | PASS | paquet Linux SHA-256 `30a525a9913d3f31f4290ff3ffe68ed30cf9d65688b189bc6238ee4565679633` |

Les **trois** SKIP de `test-deployment-automation.sh` sont les contrôles de
permissions non simulables lorsque la suite tourne en root :

- `journal non inscriptible` (`deployment.log` en `chmod 400`) ;
- `journal sans permission` (`deployment.log` en `chmod 000`) ;
- `shared non inscriptible` (répertoire `shared` en `chmod 500`).

Root peut écrire malgré ces modes, donc les branches sont ignorées ; le total
reste 400 assertions (397 réussies + 3 SKIP). En exécution non-root avec
`umask 022`, les trois contrôles s’exécutent et la suite rapporte 400 assertions
réussies, 0 échec et 0 SKIP.

Le contrôle documentaire du run initial a porté sur les **six** documents de
processus : `evidence/docs/result.json` indique 216 liens et 17 blocs Bash. Le
contrôle final inclut en plus le présent rapport comme septième document :
il ajoute 7 liens et 1 bloc Bash, soit 223 liens et 18 blocs Bash, avec les
66 blocs PowerShell inchangés. Les deux résultats sont donc cohérents ; ils ne
portent pas sur le même périmètre.

Les preuves détaillées de ce run restent dans le répertoire temporaire local
`chan99-lot6-final3/run`. Elles ne sont ni versionnées ni publiées avec la PR ;
le présent rapport en reprend les valeurs contrôlées.

Le test `test-assemble-linux.sh` a été exécuté dans une image PHP 8.4 avec
extensions `intl`/`zip` et Node 22 ; il vérifie l’assemblage réel, l’exclusion
de `vendor/bin` et le refus des liens hors `vendor/bin`.

## 7. Traçabilité

### Branches finales (remote simulé)

| Branche | SHA |
| --- | --- |
| `main` | `a8c152a598440d50fb3dcba234a3f9ec4b201b30` |
| `develop` | `318a5bd4e6767ea8d0f8caf5f83b0e30212cbe7c` |
| `hotfix/CHAN-99-simulation` | `7d708e2a5a34b24c147442a5fd3b32a1ef4a433d` |

### Tags (annotés)

| Tag | Commit |
| --- | --- |
| `v1.4.2` | `a5c8fad2b61643afcc4eb69484597a0cb6fbfd55` |
| `v1.4.3-rc.1` | `a8c152a598440d50fb3dcba234a3f9ec4b201b30` |
| `v1.4.3` | `a8c152a598440d50fb3dcba234a3f9ec4b201b30` |

### Artefact

| Élément | Valeur |
| --- | --- |
| Paquet | `chantier-v1.4.3-rc.1.tar.gz` |
| SHA-256 | `d9d6397f281eec9f5e46a0696fab62572f9c87e80c315a93bfd0ffdb42950aa5` |
| Commit source | `a8c152a598440d50fb3dcba234a3f9ec4b201b30` |
| Arbre source | `b8fd1d50e36dd2bf6329694ac38d1bb8bc11483e` |
| Tag RC | `v1.4.3-rc.1` |
| Run staging | `1001` |
| Artefact staging | `5001` |
| Environnement final | `production`, release `v1.4.3-1002` |

Le manifeste staging et le `release.json` de production portent la même
empreinte ; le paquet promu est identique à celui de staging (comparaison
binaire).

## 8. Anomalies découvertes

Aucune anomalie fonctionnelle n’a été découverte dans les scripts et documents
du processus. Les points suivants sont des défauts du harnais, corrigés avant
l’exécution finale, et non des modifications du code de production :

- les blocs PowerShell émis sans BOM étaient mal décodés par Windows
  PowerShell 5.1 (tirets typographiques interprétés comme guillemets) ;
- la propagation des objets Git du commit de fusion vers le remote bare
  devait précéder la mise à jour de référence ;
- la branche `develop` initiale devait être publiée avant l’activation du
  hook de protection ;
- l’application factice utilisait `STDOUT`, non défini sous `php -S`.

Observation mineure : les six documents contrôlés commencent par un BOM UTF-8.
Cela n’affecte ni leur rendu ni les liens ; aucun fichier documentaire n’a été
modifié.

## 9. Corrections apportées

Aucun script existant, workflow, document de processus ou test existant n’a été
modifié. Le Lot 6 ajoute uniquement :

- `scripts/simulation/run-hotfix-simulation.sh`
- `scripts/simulation/lib/harness.sh`
- `scripts/simulation/lib/git-sim.sh`
- `scripts/simulation/lib/artifact-sim.sh`
- `scripts/simulation/migration-gate.php`
- `scripts/simulation/docs-check.php`
- `scripts/simulation/check-docs.ps1`
- `scripts/simulation/README.md`
- `docs/development/hotfix-simulation-report.md` (ce rapport)

Aucun de ces fichiers n’est committé : ils restent non suivis dans l’état Git
final, conformément à la consigne de ne pas committer sur le dépôt principal.

## 10. Limites restantes

- Le remote, les PR, la CI et le registre d’artefacts sont locaux : les
  protections GitHub réelles (rulesets, environnements, secrets) ne sont pas
  exercées.
- Le faux client `gh` ne couvre que les endpoints utilisés par
  `resolve-promotion.sh` ; les autres commandes GitHub ne sont pas testées.
- Les workflows `deploy-staging.yml` et `deploy-production.yml` ne sont pas
  exécutés : seuls leurs scripts de validation et de promotion sont exercés.
- L’application factice ne remplace ni Pest, ni MariaDB, ni les migrations
  réelles. Le gate de migration est un adaptateur de simulation ; les tests
  `MigrationPolicyTest` restent la référence.
- Le rollback utilise un health check simulé et un journal PHP instrumenté ;
  aucun worker, scheduler ou file réelle n’est lancé.
- La simulation ne prouve pas la configuration réelle des environnements
  GitHub, des secrets ou du serveur : elle valide la cohérence du processus et
  des scripts.

## 11. État Git final du dépôt réel

```text
Sur la branche feature/chan-99
Fichiers non suivis :
  docs/development/hotfix-simulation-report.md
  scripts/simulation/
```

Aucune branche `main` ou `develop` du dépôt réel n’a été modifiée. Aucun
commit, tag, push, merge ou changement d’index n’a été effectué.

## 12. Confirmation d’absence d’opération distante ou de production

- Remote utilisé : uniquement le dépôt bare local `<sortie>/remote.git`.
- Aucun appel réseau vers GitHub, aucun `gh` réel : le binaire `gh` du PATH
  est un faux client local.
- Aucun push, aucune PR, aucun merge, aucun tag et aucune release réels.
- Aucun accès au serveur de production, aucun déploiement, aucun rollback réel.
- Aucune base de données réelle, aucun `migrate:*`, aucune restauration.
- Aucun secret réel, aucune donnée personnelle réelle, aucune modification
  Jira.
