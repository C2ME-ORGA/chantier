# Simulation CHAN-99 — Lot 6

Ce répertoire contient le harnais de simulation du processus de hotfix. Il
rejoue, dans un environnement local isolé, la chaîne complète :

```text
qualification → branche hotfix → PR main → synchronisation develop
→ RC → artefact → staging → promotion stable → production → clôture
```

Il couvre également les scénarios d'échec obligatoires et le rollback
applicatif.

## Garanties

- Aucun dépôt distant réel, aucun GitHub, aucun secret, aucun serveur.
- Le remote Git est un dépôt bare créé sous le répertoire de sortie.
- Un hook `pre-receive` simule les rulesets : tout push direct sur `main` ou
  `develop` est refusé ; les fusions de PR sont appliquées côté « serveur »
  par mise à jour de référence.
- Les artefacts, manifestes, registres et environnements sont locaux.
- Le health check est un vrai appel HTTP vers un serveur PHP local `/up`.
- Le rollback utilise le script réel `scripts/ops/rollback.sh` avec un bac à
  sable, une fausse commande `curl` et un journal des appels PHP.

## Exécution

Sur un hôte Linux disposant de `git`, `php`, `tar`, `sha256sum` et `flock` :

```bash
bash scripts/simulation/run-hotfix-simulation.sh --output /tmp/chan-99-lot6
```

Sous Docker Ubuntu 24.04 :

```bash
docker run --rm \
  -v "$PWD:/src:ro" \
  -v "/tmp/chan-99-lot6:/out" \
  -w /src ubuntu:24.04 \
  bash -lc "apt-get update -qq && apt-get install -y -qq --no-install-recommends git php-cli curl ca-certificates && bash scripts/simulation/run-hotfix-simulation.sh --output /out/run"
```

Validations documentaires complémentaires :

```bash
# Liens relatifs, équilibre des blocs et syntaxe Bash
php scripts/simulation/docs-check.php --root . --emit /tmp/ps-blocks \
  docs/development/hotfix-process.md \
  docs/development/hotfix-runbook.md \
  docs/development/git-workflow.md \
  docs/development/release-process.md \
  docs/development/deployment-process.md \
  docs/development/application-rollback-runbook.md

# Syntaxe des blocs PowerShell (hôte Windows avec PowerShell 5.1+ ou pwsh)
powershell -NoProfile -ExecutionPolicy Bypass \
  -File scripts/simulation/check-docs.ps1 -Directory /tmp/ps-blocks
```

Les blocs PowerShell sont émis avec un BOM UTF-8 : Windows PowerShell 5.1
interprète sinon les tirets typographiques comme des guillemets et signale de
fausses erreurs de syntaxe.

## Répertoire de sortie

```text
<sortie>/
  repo/work/                 dépôt de travail
  remote.git/                remote bare local + hook pre-receive
  registry/                  registre d'artefacts (staging et variantes altérées)
  artifacts/                 paquets et manifestes
  envs/staging|production/   releases, current, shared
  scenarios/                 dépôt isolé du scénario de conflit
  state/pr/                  état des PR simulées
  evidence/                  preuves horodatées, JSON, graphes Git, SHA
  report/results.tsv         PASS / FAIL / NOT RUN par étape et scénario
  report/simulation-report.md
  report/summary.json
```

## Adaptateurs explicitement simulés

| Élément | Réutilisation | Limite |
| --- | --- | --- |
| `validate-release-tag.sh` | Script réel | Références `origin/*` locales |
| `validate-tag.sh` | Script réel | Non appelé ici, couvert par la suite existante |
| `stable-candidate.sh` | Script réel | Tags locaux |
| `validate-release.sh` | Script réel | Corps de release local |
| `resolve-promotion.sh` | Script réel | `gh` remplacé par un faux client local |
| `assemble-package.sh` | Script réel | Application factice minimale |
| `manifest.php` | Script réel | Manifestes locaux |
| `scripts/ops/rollback.sh` | Script réel | Racine, health check et PHP instrumentés |
| `check-workflow-migrations.php` | Non exécuté par le harnais | Couvert par la suite de tests existante |
| `migration-gate.php` | Adaptateur de simulation | Ne remplace pas `MigrationPolicyTest` |
| `docs-check.php` | Outil de simulation | Liens et blocs des six documents du lot |

Le harnais ne remplace ni les tests Pest, ni Pint, ni PHPStan, ni les suites
d'automatisation existantes : ces contrôles restent exécutés séparément.

## Limites

- La simulation est **locale** : elle ne contacte ni GitHub, ni Jira, ni un
  environnement de production.
- Elle **ne remplace pas la CI GitHub réelle** : les workflows
  `deploy-staging.yml` et `deploy-production.yml`, les rulesets, les
  environnements et les secrets GitHub ne sont pas exercés.
- `gh` et `curl` sont remplacés par des binaires locaux ; les résultats ne
  prouvent pas le comportement des services distants.
- Les preuves sont écrites sous le répertoire de sortie et ne sont pas
  versionnées ni publiées avec la PR.
- L'application factice, le registre local et le health check local ne
  remplacent ni les tests Pest, ni MariaDB, ni un déploiement réel.

## Scénarios

| ID | Scénario |
| --- | --- |
| S01 | Incident non P1/P2 : refus |
| S02 | Références Git obsolètes : arrêt du préflight |
| S03 | Branche hotfix créée depuis develop : refus |
| S04 | CI en échec : fusion interdite |
| S05 | RC sur un commit non autorisé : refus |
| S06 | RC sur un commit déjà stable : refus |
| S07 | Tag stable sur un commit incorrect : refus |
| S08 | Manifeste altéré : refus |
| S09 | SHA-256 incorrect : refus |
| S10 | Artefact différent entre staging et production : refus |
| S11 | Health check en échec : arrêt et décision de rollback |
| S12 | Migration destructive : NO-GO |
| S13 | Migration incompatible N/N-1 : NO-GO |
| S14 | Rollback avec risque sur les données : arrêt et escalade |
| S15 | Synchronisation avec conflit : branche temporaire |
| S16 | Push direct sur branche protégée : refus |

R01 couvre le rollback nominal : `--dry-run`, contrôles, bascule, health check,
préservation des données, absence de `migrate:rollback`.
