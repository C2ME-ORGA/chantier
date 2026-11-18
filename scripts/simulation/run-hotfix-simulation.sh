#!/usr/bin/env bash
#
# CHAN-99 — Lot 6 : simulation complète du processus de hotfix.
#
# Exécute le parcours nominal, les scénarios d'échec obligatoires et le
# rollback applicatif dans un environnement entièrement isolé :
# - dépôt Git temporaire + remote bare local ;
# - registre d'artefacts local et faux client `gh` ;
# - environnements staging / production simulés ;
# - health check HTTP réel sur 127.0.0.1.
#
# Aucun accès à GitHub, aucun push réel, aucun déploiement, aucune base réelle.
#
# Usage :
#   bash scripts/simulation/run-hotfix-simulation.sh [--output <dossier>]
#
# Le dossier de sortie contient les preuves et le rapport. Par défaut, un
# répertoire temporaire est créé.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/harness.sh
source "$script_dir/lib/harness.sh"
# shellcheck source=lib/git-sim.sh
source "$script_dir/lib/git-sim.sh"
# shellcheck source=lib/artifact-sim.sh
source "$script_dir/lib/artifact-sim.sh"

output=""

while (($#)); do
  case "$1" in
    --output) output="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,26p' "$0"
      exit 0
      ;;
    *)
      printf 'Argument inconnu : %s\n' "$1" >&2
      exit 64
      ;;
  esac
done

if [[ -z "$output" ]]; then
  output="$(mktemp -d "${TMPDIR:-/tmp}/chan-99-lot6-XXXXXX")"
fi

trap 'sim_cleanup' EXIT

sim_init_output "$output"
sim_fake_gh_init

sim_log "Sortie de simulation : $SIM_OUT"

for required in git php tar sha256sum awk sed grep; do
  if ! command -v "$required" >/dev/null 2>&1; then
    sim_not_run "ENV" "Prérequis de simulation" "commande obligatoire absente : $required"
    sim_write_report >/dev/null
    printf 'ERREUR: commande obligatoire absente : %s\n' "$required" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Préparation du dépôt de simulation
# ---------------------------------------------------------------------------

sim_section "Initialisation du dépôt de simulation"

repo="$SIM_OUT/repo/work"
remote="$SIM_OUT/remote.git"
SIM_WORK_REPO="$repo"

sim_init_repo "$repo" >/dev/null
sim_init_remote "$repo" "$remote" >/dev/null

mkdir -p "$SIM_OUT/evidence/production"
prod_sha="$(git -C "$repo" rev-parse 'v1.4.2^{commit}')"
prod_tree="$(git -C "$repo" rev-parse 'v1.4.2^{tree}')"
sim_release_json "$SIM_OUT/evidence/production/release-v1.4.2.json" \
  production "v1.4.2-9000" "v1.4.2" "$prod_sha" "$prod_tree" "9000" "$(printf 'a%.0s' $(seq 1 64))"

git -C "$repo" switch --quiet -c develop
printf 'fonctionnalité de develop\n' >"$repo/app/DevelopFeature.php"
sim_git_commit "$repo" "feat(chantier): ajouter une fonctionnalité prévue pour develop"
printf 'documentation de develop\n' >"$repo/docs-develop.md"
sim_git_commit "$repo" "docs(chantier): documenter la fonctionnalité de develop"
git -C "$repo" push --quiet origin develop
git -C "$repo" switch --quiet main

sim_fetch "$repo"

mkdir -p "$SIM_OUT/evidence/git"
git -C "$repo" log --graph --oneline --decorate --all >"$SIM_OUT/evidence/git/before-graph.txt"
git -C "$repo" show-ref --heads --tags >"$SIM_OUT/evidence/git/before-refs.txt" 2>/dev/null || true

main_before="$(sim_remote_sha main)"
develop_before="$(sim_remote_sha develop)"

sim_assert_contains "main et develop sont des branches distinctes" \
  "$(git -C "$repo" log --format='%H %s' main..develop)" "fonctionnalité prévue pour develop"

# ---------------------------------------------------------------------------
# Étape 1 — Qualification
# ---------------------------------------------------------------------------

sim_qualify() {
  local severity="$1"
  local production_known="$2"
  local reproducible="$3"
  local rollback_sufficient="$4"
  local migration_class="$5"
  local regression_test="$6"
  local approval="$7"
  local reasons=()

  case "$severity" in
    P1|P2) ;;
    *) reasons+=("sévérité $severity non éligible (P1/P2 requis)") ;;
  esac

  [[ "$production_known" == "oui" ]] || reasons+=("référence de production inconnue")
  [[ "$reproducible" == "oui" ]] || reasons+=("défaut non reproductible")
  [[ "$rollback_sufficient" == "non" ]] || reasons+=("rollback suffisant : hotfix non requis")
  [[ "$migration_class" == "aucune" || "$migration_class" == "A" || "$migration_class" == "B" ]] \
    || reasons+=("migration $migration_class interdite en hotfix")
  [[ "$regression_test" == "oui" ]] || reasons+=("test de non-régression absent")
  [[ "$approval" == "oui" ]] || reasons+=("autorisation humaine absente")

  if ((${#reasons[@]} == 0)); then
    printf 'GO'
  else
    printf 'NO-GO: %s' "$(IFS='; '; printf '%s' "${reasons[*]}")"
  fi
}

sim_step_begin "E01" "Qualification de l’incident et décision GO/NO-GO"

incident_dir="$(sim_evidence_dir "step-01-qualification")"
cat >"$incident_dir/incident-p1.json" <<JSON
{
  "ticket": "CHAN-99-SIMULATION",
  "detected_at": "$(sim_timestamp)",
  "environment": "production",
  "function": "calcul du total",
  "affected_users": "utilisateurs de la simulation",
  "data_or_security": "aucune donnée exposée ou corrompue (simulation)",
  "affected_version": "v1.4.2",
  "production_commit": "$prod_sha",
  "reproduction": "GET /api/total?a=3&b=2 retourne -1 au lieu de 5",
  "workaround": "aucun contournement raisonnable",
  "rollback": "rollback applicatif préféré si compatible",
  "severity": "P1",
  "severity_justification": "fonction métier critique indisponible en production",
  "owner": "Responsable Simulation",
  "approval": "GO écrit du responsable simulation"
}
JSON

nominal_decision="$(sim_qualify P1 oui oui non aucune oui oui)"
sim_assert_eq "incident P1 qualifié GO" "GO" "$nominal_decision"
sim_assert_eq "responsable identifié" "Responsable Simulation" \
  "$(php -r '$d=json_decode(file_get_contents($argv[1]),true);echo $d["owner"];' "$incident_dir/incident-p1.json")"
sim_assert_file "fiche d’incident conservée" "$incident_dir/incident-p1.json"

p3_decision="$(sim_qualify P3 oui oui non aucune oui oui)"
sim_assert_contains "incident P3 refusé" "$p3_decision" "NO-GO"
sim_assert_contains "motif P3 explicite" "$p3_decision" "P1/P2 requis"

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# Scénario d'échec S01
sim_step_begin "S01" "Incident non P1/P2 : refus du hotfix"
s01_decision="$(sim_qualify P4 oui oui non aucune oui oui)"
if [[ "$s01_decision" == NO-GO* ]]; then
  sim_record "S01" "Incident non P1/P2" "PASS" "décision : $s01_decision"
else
  sim_record "S01" "Incident non P1/P2" "FAIL" "décision inattendue : $s01_decision"
fi

# ---------------------------------------------------------------------------
# Étape 2 — Préparation et préflight
# ---------------------------------------------------------------------------

sim_step_begin "E02" "Préparation : production, tags et préflight Git"

sim_check_ok "tag de production annoté" sim_assert_annotated_tag "$repo" v1.4.2
sim_check_ok "préflight de la référence de production" \
  sim_check_production_reference "$repo" v1.4.2 "$SIM_OUT/evidence/production/release-v1.4.2.json" production
sim_assert_eq "main alignée sur la production" "$prod_sha" "$(sim_remote_sha main)"
sim_assert_eq "develop est en avance sur main" "2" \
  "$(git -C "$repo" rev-list --count "origin/main..origin/develop")"
sim_assert "aucun tag cible existant" test -z "$(git -C "$repo" tag -l 'v1.4.3*')"

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# Scénario d'échec S02 : références obsolètes
sim_step_begin "S02" "Références Git obsolètes : arrêt du préflight"

stale_commit="$(git -C "$repo" commit-tree \
  "$(git -C "$repo" rev-parse 'origin/main^{tree}')" \
  -m "chore(simulation): avancer main sans hotfix" \
  -p "$(sim_remote_sha main)")"
git -C "$repo" push --quiet origin "$stale_commit:refs/heads/tmp/preflight-stale"
sim_server_update_ref main "$stale_commit"
git -C "$repo" push --quiet origin --delete tmp/preflight-stale >/dev/null 2>&1 || true
sim_fetch "$repo"

if sim_check_production_reference "$repo" v1.4.2 "$SIM_OUT/evidence/production/release-v1.4.2.json" production >/dev/null 2>&1; then
  sim_record "S02" "Références Git obsolètes" "FAIL" "main avancée mais préflight accepté"
else
  sim_record "S02" "Références Git obsolètes" "PASS" "préflight refusé : main n’est plus alignée sur v1.4.2"
fi

sim_server_update_ref main "$prod_sha"
sim_fetch "$repo"
sim_assert_eq "référence main restaurée" "$prod_sha" "$(sim_remote_sha main)"

# ---------------------------------------------------------------------------
# Étape 3 — Branche hotfix, défaut, test et correctif
# ---------------------------------------------------------------------------

sim_step_begin "E03" "Création et correction du hotfix depuis main"

hotfix_branch="hotfix/CHAN-99-simulation"
git -C "$repo" switch --quiet main
git -C "$repo" switch --quiet -c "$hotfix_branch" "origin/main"

main_sha="$(sim_remote_sha main)"
develop_sha="$(sim_remote_sha develop)"

sim_assert "branche hotfix issue de main, sans commit de develop" \
  sim_branch_starts_from_main "$repo" "$hotfix_branch" "$main_sha" "$develop_sha"
sim_assert "branche hotfix ne contient pas develop" \
  bash -c "! git -C '$repo' merge-base --is-ancestor '$develop_sha' '$hotfix_branch'"

cat >"$repo/tests/GreetingRegressionTest.php" <<'PHP'
<?php

declare(strict_types=1);

$failures = $failures ?? [];

if (greeting_total(3, 2) !== 5) {
    $failures[] = 'Régression : greeting_total(3, 2) doit valoir 5.';
}
PHP

git -C "$repo" add tests/GreetingRegressionTest.php
sim_git_commit "$repo" \
  "test(greeting): ajouter un test de non-régression pour le total" \
  -m "Refs: CHAN-99"

ci_before_fix_sha="$(git -C "$repo" rev-parse HEAD)"
mkdir -p "$SIM_OUT/evidence/step-03-hotfix"
sim_save "$SIM_OUT/evidence/step-03-hotfix/ci-before-fix.log" \
  env -u GH_SIM_DIR bash -c "cd '$repo' && php tests/run.php"
if (cd "$repo" && php tests/run.php >/dev/null 2>&1); then
  sim_log "ANOMALIE: le test aurait dû échouer avant le correctif"
  (cd "$repo" && php tests/run.php) >>"$SIM_OUT/log/checks.log" 2>&1 || true
  SIM_STEP_FAILED=1
else
  sim_log "OK   le test de non-régression échoue avant le correctif"
fi

sed -i 's/return \$left - \$right;/return $left + $right;/' "$repo/app/Greeting.php"
git -C "$repo" add app/Greeting.php
sim_git_commit "$repo" \
  "fix(greeting): corriger le calcul du total" \
  -m "Refs: CHAN-99"

sim_check_ok "tests locaux après correctif" bash -c "cd '$repo' && php tests/run.php"
sim_check_ok "php -l sur les fichiers modifiés" bash -c "php -l '$repo/app/Greeting.php' >/dev/null && php -l '$repo/tests/GreetingRegressionTest.php' >/dev/null"
sim_check_ok "git diff --check" git -C "$repo" diff --check "origin/main...HEAD"

hotfix_commits="$(git -C "$repo" log --format='%s' 'origin/main..HEAD')"
commit_ok=1
while IFS= read -r subject; do
  [[ -z "$subject" ]] && continue
  if ! sim_commit_is_conventional "$subject"; then
    commit_ok=0
    sim_log "ANOMALIE: commit non conventionnel : $subject"
  fi
done <<<"$hotfix_commits"

if ((commit_ok == 1)) && printf '%s' "$hotfix_commits" | grep -Eq '^fix\([a-z0-9._-]+\): '; then
  sim_log "OK   commits du hotfix conformes aux Conventional Commits (dont un commit fix)"
else
  SIM_STEP_FAILED=1
  sim_log "FAIL commits du hotfix non conformes"
fi

changed_files="$(git -C "$repo" diff --name-only 'origin/main...HEAD' | sort)"
sim_assert_eq "périmètre du hotfix limité au correctif et au test" \
  $'app/Greeting.php\ntests/GreetingRegressionTest.php' "$changed_files"

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# Scénario d'échec S03 : branche créée depuis develop
sim_step_begin "S03" "Branche hotfix créée depuis develop : refus"

git -C "$repo" switch --quiet -c "hotfix/CHAN-99-simulation-depuis-develop" "origin/develop"
if sim_branch_starts_from_main "$repo" "hotfix/CHAN-99-simulation-depuis-develop" "$main_sha" "$develop_sha"; then
  sim_record "S03" "Branche hotfix depuis develop" "FAIL" "branche acceptée à tort"
else
  sim_record "S03" "Branche hotfix depuis develop" "PASS" "refus : la branche contient les commits de develop"
fi
git -C "$repo" switch --quiet "$hotfix_branch"
git -C "$repo" branch -D "hotfix/CHAN-99-simulation-depuis-develop" >/dev/null 2>&1 || true

# Scénario d'échec S04 : CI en échec
sim_step_begin "S04" "CI en échec : interdiction de poursuivre"

git -C "$repo" switch --quiet -c "hotfix/CHAN-99-simulation-ci-echec" "origin/main"
sed -i 's/return \$left - \$right;/return $left - $right;/' "$repo/app/Greeting.php"
cat >"$repo/tests/CiFailureTest.php" <<'PHP'
<?php

declare(strict_types=1);

$failures = $failures ?? [];
$failures[] = 'Échec CI volontaire pour la simulation.';
PHP
sim_git_commit "$repo" "test(ci): provoquer un échec volontaire" -m "Refs: CHAN-99"

git -C "$repo" push --quiet -u origin "hotfix/CHAN-99-simulation-ci-echec"
git -C "$repo" switch --quiet "$hotfix_branch"
sim_fetch "$repo"

ci_fail_sha="$(git -C "$repo" rev-parse 'origin/hotfix/CHAN-99-simulation-ci-echec')"
heat_dir="$(sim_evidence_dir "step-04-pr")"
printf '# PR de test\n\nÉchec CI volontaire.\n' >"$heat_dir/pull-request.md"
if sim_run_ci "$repo" "$ci_fail_sha" "ci-echec"; then
  sim_log "ANOMALIE: la CI aurait dû échouer"
  SIM_STEP_FAILED=1
else
  sim_log "OK   CI rouge sur la branche de test"
fi

pr_ci_fail="$(sim_pr_create "$repo" main "hotfix/CHAN-99-simulation-ci-echec" \
  "test(ci): échec volontaire (CHAN-99)" "$heat_dir/pull-request.md" "pr-ci-fail")"
sim_assert_eq "état CI de la PR" "failure" "$(sim_pr_state "$pr_ci_fail" ci)"
sim_pr_comment_go "$pr_ci_fail" "Responsable Simulation" "GO conditionnel $(sim_timestamp)"
sim_check_fail "fusion refusée avec CI rouge" "CI non verte" sim_pr_merge "$pr_ci_fail" merge

git -C "$repo" branch -D "hotfix/CHAN-99-simulation-ci-echec" >/dev/null 2>&1 || true
git -C "$repo" push --quiet origin --delete "hotfix/CHAN-99-simulation-ci-echec" >/dev/null 2>&1 || true

sim_step_record_current "S04" "CI en échec" "CI rouge, fusion refusée par le gate"
sim_step_end

# ---------------------------------------------------------------------------
# Étape 4 — Pull Request simulée vers main
# ---------------------------------------------------------------------------

sim_step_begin "E04" "Pull Request simulée vers main"

sim_check_ok "push de la branche hotfix autorisé" git -C "$repo" push --quiet -u origin "$hotfix_branch"
sim_fetch "$repo"

main_ref_before="$(sim_remote_sha main)"
sim_check_fail "push direct sur main refusé" "push direct interdit sur refs/heads/main" \
  git -C "$repo" push --quiet origin "HEAD:main"

git -C "$repo" switch --quiet -c "tmp/direct-develop" origin/develop
printf 'tentative de push direct\n' >>"$repo/docs-develop.md"
sim_git_commit "$repo" "chore(simulation): tentative de push direct sur develop"
sim_check_fail "push direct sur develop refusé" "push direct interdit sur refs/heads/develop" \
  git -C "$repo" push --quiet origin "HEAD:develop"
git -C "$repo" switch --quiet "$hotfix_branch"
git -C "$repo" branch -D "tmp/direct-develop" >/dev/null 2>&1 || true

sim_assert_eq "main inchangée après tentative de push direct" "$main_ref_before" "$(sim_remote_sha main)"

heat_dir="$(sim_evidence_dir "step-04-pr")"
cat >"$heat_dir/pull-request.md" <<MD
# Hotfix CHAN-99-simulation

- Sévérité : P1
- Version déployée : v1.4.2
- Commit de production : $prod_sha
- Version cible : v1.4.3
- Migration : aucune
- Rollback : applicatif, attestation N/N-1
- Validation staging : à exécuter après synchronisation
MD

pr="$(sim_pr_create "$repo" main "$hotfix_branch" "fix(greeting): corriger le total (CHAN-99)" "$heat_dir/pull-request.md" "pr-main")"
sim_assert_eq "source de la PR" "$hotfix_branch" "$(sim_pr_state "$pr" head)"
sim_assert_eq "destination de la PR" "main" "$(sim_pr_state "$pr" base)"
sim_assert_eq "CI de la PR verte" "success" "$(sim_pr_state "$pr" ci)"

sim_check_fail "fusion refusée sans GO humain" "GO" sim_pr_merge "$pr" merge

sim_pr_comment_go "$pr" "Responsable Simulation" "GO hotfix $(sim_timestamp) — version cible v1.4.3"
sim_check_fail "fusion squash refusée" "squash interdit" sim_pr_merge "$pr" squash

merge_main="$(sim_pr_merge "$pr" merge)"
sim_assert "commit de fusion créé" test -n "$merge_main"
sim_fetch "$repo"

sim_assert_eq "main pointe sur le commit de fusion" "$merge_main" "$(sim_remote_sha main)"
parent_count="$(( $(git -C "$repo" rev-list --parents -n 1 "$merge_main" | wc -w) - 1 ))"
sim_assert_eq "fusion conserve deux parents (historique préservé)" "2" "$parent_count"

hotfix_fix_commit="$(git -C "$repo" rev-parse "${hotfix_branch}^{commit}")"
sim_assert "commit hotfix présent dans main" \
  git -C "$repo" merge-base --is-ancestor "$hotfix_fix_commit" origin/main
sim_assert "commit de fusion présent dans main" \
  git -C "$repo" merge-base --is-ancestor "$merge_main" origin/main

sim_check_ok "CI verte sur main après fusion" sim_run_ci "$repo" "$merge_main" "main-after-merge"

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Étape 5 — Synchronisation main → develop
# ---------------------------------------------------------------------------

sim_step_begin "E05" "Synchronisation main → develop (PR directe)"

sim_fetch "$repo"
main_sync_sha="$(sim_remote_sha main)"
develop_sync_sha="$(sim_remote_sha develop)"

sim_assert "hotfix présent dans main" \
  git -C "$repo" merge-base --is-ancestor "$merge_main" origin/main
sim_assert "main pas encore intégrée dans develop" \
  bash -c "! git -C '$repo' merge-base --is-ancestor '$main_sync_sha' '$develop_sync_sha'"

sync_pr="$(sim_pr_create "$repo" develop main "chore(sync): reporter le hotfix CHAN-99 dans develop" "$heat_dir/pull-request.md" "sync-develop")"
sim_assert_eq "PR de synchronisation cible develop" "develop" "$(sim_pr_state "$sync_pr" base)"
sim_assert_eq "PR de synchronisation a pour source main" "main" "$(sim_pr_state "$sync_pr" head)"
sim_pr_comment_go "$sync_pr" "Responsable Simulation" "GO synchronisation $(sim_timestamp)"
sync_merge="$(sim_pr_merge "$sync_pr" merge)"
sim_assert "commit de synchronisation créé" test -n "$sync_merge"
sim_fetch "$repo"

sim_assert "hotfix présent dans develop" \
  git -C "$repo" merge-base --is-ancestor "$hotfix_fix_commit" origin/develop
sim_assert "develop initial conservé" \
  git -C "$repo" merge-base --is-ancestor "$develop_sync_sha" origin/develop
sim_assert "développements propres à develop conservés" \
  git -C "$repo" cat-file -e "origin/develop:app/DevelopFeature.php"
sim_assert "historique de main intégré dans develop" \
  git -C "$repo" merge-base --is-ancestor "$main_sync_sha" origin/develop

sim_check_ok "CI verte sur develop après synchronisation" sim_run_ci "$repo" "$sync_merge" "develop-after-sync"

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Étape 6 — Release candidate
# ---------------------------------------------------------------------------

sim_step_begin "E06" "Release candidate de hotfix"

git -C "$repo" switch --quiet main
git -C "$repo" pull --quiet --ff-only origin main
rc_tag="v1.4.3-rc.1"
sim_tag_annotated "$repo" "$rc_tag" "$merge_main"
git -C "$repo" push --quiet origin "$rc_tag"
sim_fetch "$repo"

rc_output="$(cd "$repo" && bash "$SIM_PROJECT_ROOT/.github/scripts/deploy/validate-release-tag.sh" \
  --tag "$rc_tag" --main-ref origin/main --develop-ref origin/develop 2>&1)"
sim_assert_eq "résultat validate-release-tag" "0" "$?"
sim_assert_contains "type de release" "$rc_output" "release_type=release-candidate"
sim_assert_contains "commit de la RC" "$rc_output" "commit_sha=$merge_main"
sim_assert_contains "RC de hotfix reconnue" "$rc_output" "hotfix_rc=true"
sim_assert_contains "RC non alignée sur le HEAD de develop" "$rc_output" "head_matches=false"

sim_assert "tag RC annoté" sim_assert_annotated_tag "$repo" "$rc_tag"
sim_assert_eq "tag RC pointe sur le commit de fusion du hotfix" "$merge_main" \
  "$(git -C "$repo" rev-parse "${rc_tag}^{commit}")"
sim_assert "commit de la RC présent dans develop" \
  git -C "$repo" merge-base --is-ancestor "$merge_main" origin/develop
sim_assert_eq "aucun tag stable sur le commit de la RC" "" \
  "$(git -C "$repo" tag --points-at "$merge_main" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"

cat >"$SIM_OUT/evidence/git/rc-validation.txt" <<TXT
$rc_output
TXT

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# Scénarios d'échec S05, S06, S07
sim_step_begin "S05-S07" "Tags de release invalides"

develop_only_commit="$(git -C "$repo" rev-parse 'origin/develop^')"
sim_tag_annotated "$repo" "v1.4.9-rc.1" "$develop_only_commit"
s05_output="$(cd "$repo" && bash "$SIM_PROJECT_ROOT/.github/scripts/deploy/validate-release-tag.sh" \
  --tag v1.4.9-rc.1 --main-ref origin/main --develop-ref origin/develop 2>&1)"
s05_status=$?
printf '%s\n' "$s05_output" >"$SIM_OUT/evidence/git/s05-rc-unauthorized.log"
if ((s05_status != 0)) && printf '%s' "$s05_output" | grep -Fq "release candidate de hotfix"; then
  sim_record "S05" "RC sur un commit non autorisé" "PASS" "RC refusée : le commit n’est pas le HEAD de main"
else
  sim_record "S05" "RC sur un commit non autorisé" "FAIL" "RC acceptée à tort ou motif inattendu"
fi
git -C "$repo" tag -d v1.4.9-rc.1 >/dev/null 2>&1 || true

sim_tag_annotated "$repo" "v1.4.9-rc.2" "$prod_sha"
s06_output="$(cd "$repo" && bash "$SIM_PROJECT_ROOT/.github/scripts/deploy/validate-release-tag.sh" \
  --tag v1.4.9-rc.2 --main-ref origin/main --develop-ref origin/develop 2>&1)"
s06_status=$?
printf '%s\n' "$s06_output" >"$SIM_OUT/evidence/git/s06-rc-stable-commit.log"
if ((s06_status != 0)) && printf '%s' "$s06_output" | grep -Fq "déjà pointé par un tag stable"; then
  sim_record "S06" "RC sur un commit déjà stable" "PASS" "RC refusée : v1.4.2 pointe déjà sur ce commit"
else
  sim_record "S06" "RC sur un commit déjà stable" "FAIL" "RC acceptée à tort ou motif inattendu"
fi
git -C "$repo" tag -d v1.4.9-rc.2 >/dev/null 2>&1 || true

sim_tag_annotated "$repo" "v1.4.4" "origin/develop"
s07_output="$(cd "$repo" && bash "$SIM_PROJECT_ROOT/.github/scripts/deploy/validate-release-tag.sh" \
  --tag v1.4.4 --main-ref origin/main --develop-ref origin/develop 2>&1)"
s07_status=$?
printf '%s\n' "$s07_output" >"$SIM_OUT/evidence/git/s07-stable-wrong-commit.log"
if ((s07_status != 0)) && printf '%s' "$s07_output" | grep -Fq "tag stable"; then
  sim_record "S07" "Tag stable sur un commit incorrect" "PASS" "tag stable refusé : il ne pointe pas sur le HEAD de main"
else
  sim_record "S07" "Tag stable sur un commit incorrect" "FAIL" "tag stable accepté à tort ou motif inattendu"
fi
git -C "$repo" tag -d v1.4.4 >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Étape 7 — Artefact et staging
# ---------------------------------------------------------------------------

sim_step_begin "E07" "Construction de l’artefact et déploiement staging"

artifact_dir="$SIM_OUT/artifacts/staging"
build_ok=0
if sim_build_package "$repo" "$rc_tag" "$rc_tag" "$artifact_dir"; then
  build_ok=1
fi
sim_assert "paquet staging construit" test "$build_ok" -eq 1

staging_package="$artifact_dir/chantier-${rc_tag}.tar.gz"
sim_assert_file "paquet staging présent" "$staging_package"
sim_assert_file "empreinte du paquet présente" "${staging_package}.sha256"

staging_sha="$(sim_sha256 "$staging_package")"
sim_assert_eq "empreinte SHA-256 de 64 caractères" "64" "${#staging_sha}"
sim_assert_contains "empreinte publiée identique" "$(cat "${staging_package}.sha256")" "$staging_sha"

archive_entries="$SIM_OUT/evidence/step-07-staging/archive-entries.txt"
mkdir -p "$(dirname "$archive_entries")"
tar -tzf "$staging_package" >"$archive_entries"
sim_assert "archive sans .env" bash -c "! grep -Eq '(^|/)\.env($|\.)' '$archive_entries'"
sim_assert "archive sans tests" bash -c "! grep -Eq '^\./tests/' '$archive_entries'"
sim_assert "archive sans .git" bash -c "! grep -Eq '(^|/)\.git/' '$archive_entries'"
sim_assert "archive contient les assets Vite" grep -q '^\./public/build/' "$archive_entries"

mkdir -p "$(sim_evidence_dir "step-07-staging")"
cp "$staging_package" "${staging_package}.sha256" "$(sim_evidence_dir "step-07-staging")/"

staging_release_id="v1.4.3-rc.1-1001"
if sim_deploy_release staging "$staging_release_id" "$staging_package" "$rc_tag" \
  "$merge_main" "$(git -C "$repo" rev-parse "${rc_tag}^{tree}")" "5001" "$staging_sha" 3 2 5; then
  sim_log "OK   déploiement staging et health check /up"
else
  SIM_STEP_FAILED=1
  sim_log "FAIL déploiement staging ou health check"
fi

sim_assert_eq "artefact intact après déploiement staging" \
  "$staging_sha" "$(sim_sha256 "$staging_package")"

staging_manifest="$SIM_OUT/artifacts/staging/manifest.json"
sim_manifest_create_staging "$staging_manifest" "$rc_tag" "$merge_main" \
  "$(git -C "$repo" rev-parse "${rc_tag}^{tree}")" "1001" "5001" "$staging_sha"
sim_check_ok "manifeste staging valide" sim_manifest_validate "$staging_manifest"
sim_assert_eq "manifeste : tag RC" "$rc_tag" "$(sim_manifest_get "$staging_manifest" tag)"
sim_assert_eq "manifeste : commit source" "$merge_main" "$(sim_manifest_get "$staging_manifest" commit_sha)"
sim_assert_eq "manifeste : empreinte" "$staging_sha" "$(sim_manifest_get "$staging_manifest" artifact.sha256)"

staging_registry="$SIM_OUT/registry/staging"
sim_registry_publish "$staging_registry" "$rc_tag" "$staging_package" "$staging_manifest" 1001 5001 5002 "$merge_main"

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# Scénario d'échec S11 : health check en échec
sim_step_begin "S11" "Health check en échec : arrêt et décision de rollback"

health_fail_package="$SIM_OUT/artifacts/staging/chantier-health-fail.tar.gz"
cp "$staging_package" "$health_fail_package"
if sim_deploy_fails_health staging "v1.4.9-rc.9-9999" "$health_fail_package" "v1.4.9-rc.9" \
  "$merge_main" "$(git -C "$repo" rev-parse "${rc_tag}^{tree}")" "9999" "$staging_sha" >/dev/null 2>&1; then
  sim_record "S11" "Health check en échec" "PASS" "échec détecté ; décision consignée : rollback applicatif, aucun rollback automatique"
  printf 'decision=rollback\nreason=health check /up en échec après activation\nsource=v1.4.9-rc.9-9999\nautomatic=false\n' \
    >"$SIM_OUT/evidence/step-07-staging/health-failure-decision.txt"
else
  sim_record "S11" "Health check en échec" "FAIL" "l’échec de santé n’a pas été détecté"
fi

# ---------------------------------------------------------------------------
# Étape 8 — Promotion production
# ---------------------------------------------------------------------------

sim_step_begin "E08" "Tag stable et promotion de l’artefact staging"

stable_tag="v1.4.3"
sim_tag_annotated "$repo" "$stable_tag" "$merge_main"
git -C "$repo" push --quiet origin "$stable_tag"
sim_fetch "$repo"

sim_assert_eq "tag stable pointe sur le commit du hotfix" "$merge_main" \
  "$(git -C "$repo" rev-parse "${stable_tag}^{commit}")"
sim_assert_eq "RC et tag stable désignent le même commit" \
  "$(git -C "$repo" rev-parse "${rc_tag}^{commit}")" "$(git -C "$repo" rev-parse "${stable_tag}^{commit}")"

notes="$SIM_OUT/evidence/step-08-promotion/release-notes.md"
mkdir -p "$(dirname "$notes")"
printf '# Version v1.4.3\n\nCorrectif du calcul du total.\n' >"$notes"
sim_check_ok "notes de release complétées avec la candidate staging" \
  bash -c "cd '$repo' && bash '$SIM_PROJECT_ROOT/.github/scripts/deploy/stable-candidate.sh' --tag '$stable_tag' --notes '$notes'"
sim_assert_contains "candidate staging référencée" "$(cat "$notes")" "Staging-Candidate: $rc_tag"

release_output="$(cd "$repo" && bash "$SIM_PROJECT_ROOT/.github/scripts/deploy/validate-release.sh" \
  --tag "$stable_tag" --draft false --prerelease false --body-file "$notes" 2>&1)"
sim_assert_contains "release publiée valide" "$release_output" "tag=$stable_tag"
sim_assert_contains "candidate extraite" "$release_output" "candidate_tag=$rc_tag"

promotion_dir="$SIM_OUT/tmp/promotion"
promotion_output="$(sim_promotion_run "$repo" "$staging_registry" "$stable_tag" "$rc_tag" "$promotion_dir")"
promotion_status=$?
sim_assert_eq "promotion staging → production réussie" "0" "$promotion_status"
sim_assert_contains "candidate promue" "$promotion_output" "candidate_tag=$rc_tag"
sim_assert_contains "commit stable promu" "$promotion_output" "release_commit=$merge_main"
sim_assert_contains "arbre identique" "$promotion_output" "release_tree=$(git -C "$repo" rev-parse "${rc_tag}^{tree}")"
sim_assert_contains "empreinte promue identique" "$promotion_output" "sha256=$staging_sha"

promoted_package="$(sim_kv_get "$promotion_output" package_path)"
promoted_manifest="$(sim_kv_get "$promotion_output" manifest_path)"
promoted_sha="$(sim_kv_get "$promotion_output" sha256)"
sim_assert_file "paquet promu téléchargé" "$promoted_package"
sim_assert "artefact staging exactement celui promu" sim_assert_artifact_identical "$staging_package" "$promoted_package"
sim_assert_eq "aucune reconstruction (SHA identique)" "$staging_sha" "$promoted_sha"

cp "$promoted_package" "$promoted_manifest" "$SIM_OUT/evidence/step-08-promotion/"

production_release_id="v1.4.3-1002"
if sim_deploy_release production "$production_release_id" "$promoted_package" "$stable_tag" \
  "$merge_main" "$(git -C "$repo" rev-parse "${stable_tag}^{tree}")" "5001" "$promoted_sha" 3 2 5; then
  sim_log "OK   déploiement production simulé et health check /up"
else
  SIM_STEP_FAILED=1
  sim_log "FAIL déploiement production simulé"
fi

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# Scénarios d'échec S08, S09, S10
sim_step_begin "S08-S10" "Manifeste et artefact altérés"

altered_manifest_registry="$SIM_OUT/registry/altered-manifest"
cp -R "$staging_registry" "$altered_manifest_registry"
php -r '
$file = $argv[1];
$data = json_decode(file_get_contents($file), true);
$data["commit_sha"] = str_repeat("0", 40);
file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
' "$altered_manifest_registry/manifest/manifest.json"

s08_output="$(sim_promotion_run "$repo" "$altered_manifest_registry" "$stable_tag" "$rc_tag" "$SIM_OUT/tmp/promotion-s08" 2>&1)"
s08_status=$?
printf '%s\n' "$s08_output" >"$SIM_OUT/evidence/step-08-promotion/s08-altered-manifest.log"
if ((s08_status != 0)) && printf '%s' "$s08_output" | grep -Fq "manifeste incohérent"; then
  sim_record "S08" "Manifeste altéré" "PASS" "refus : commit_sha du manifeste incohérent"
else
  sim_record "S08" "Manifeste altéré" "FAIL" "promotion acceptée à tort ou motif inattendu"
fi

bad_sha_registry="$SIM_OUT/registry/bad-sha"
cp -R "$staging_registry" "$bad_sha_registry"
printf '%064d  chantier-%s.tar.gz\n' 0 "$rc_tag" >"$bad_sha_registry/package/chantier-${rc_tag}.tar.gz.sha256"

s09_output="$(sim_promotion_run "$repo" "$bad_sha_registry" "$stable_tag" "$rc_tag" "$SIM_OUT/tmp/promotion-s09" 2>&1)"
s09_status=$?
printf '%s\n' "$s09_output" >"$SIM_OUT/evidence/step-08-promotion/s09-bad-sha.log"
if ((s09_status != 0)) && printf '%s' "$s09_output" | grep -Fq "empreinte publiée"; then
  sim_record "S09" "SHA-256 incorrect" "PASS" "refus : le paquet ne correspond pas à son empreinte publiée"
else
  sim_record "S09" "SHA-256 incorrect" "FAIL" "promotion acceptée à tort ou motif inattendu"
fi

different_artifact_registry="$SIM_OUT/registry/different-artifact"
cp -R "$staging_registry" "$different_artifact_registry"
printf 'substitution simulée\n' >>"$different_artifact_registry/package/chantier-${rc_tag}.tar.gz"
different_sha="$(sim_sha256 "$different_artifact_registry/package/chantier-${rc_tag}.tar.gz")"
printf '%s  chantier-%s.tar.gz\n' "$different_sha" "$rc_tag" \
  >"$different_artifact_registry/package/chantier-${rc_tag}.tar.gz.sha256"

s10_output="$(sim_promotion_run "$repo" "$different_artifact_registry" "$stable_tag" "$rc_tag" "$SIM_OUT/tmp/promotion-s10" 2>&1)"
s10_status=$?
printf '%s\n' "$s10_output" >"$SIM_OUT/evidence/step-08-promotion/s10-different-artifact.log"
if ((s10_status != 0)) && printf '%s' "$s10_output" | grep -Fq "artifact.sha256"; then
  sim_record "S10" "Artefact différent entre staging et production" "PASS" "refus : l’artefact ne correspond pas au manifeste staging"
else
  sim_record "S10" "Artefact différent entre staging et production" "FAIL" "promotion acceptée à tort ou motif inattendu"
fi

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Étape 9 — Vérifications post-déploiement
# ---------------------------------------------------------------------------

sim_step_begin "E09" "Vérifications post-déploiement en production"

prod_root="$SIM_OUT/envs/production"
prod_current="$prod_root/current/release.json"
sim_assert_file "release.json de production" "$prod_current"
sim_assert_eq "version déployée" "$stable_tag" \
  "$(php -r '$d=json_decode(file_get_contents($argv[1]),true);echo $d["version"];' "$prod_current")"
sim_assert_eq "commit déployé" "$merge_main" \
  "$(php -r '$d=json_decode(file_get_contents($argv[1]),true);echo $d["commit_sha"];' "$prod_current")"
sim_assert_eq "empreinte déployée" "$staging_sha" \
  "$(php -r '$d=json_decode(file_get_contents($argv[1]),true);echo $d["sha256"];' "$prod_current")"

server="$(sim_start_health_server "$prod_root/current/public")"
pid="${server%% *}"
port="${server##* }"
sleep 1
health_body="$(sim_http_get "$port" '/up')"
version_body="$(sim_http_get "$port" '/version')"
functional_body="$(sim_http_get "$port" '/api/total?a=3&b=2')"
sim_stop_health_server "$pid"

sim_assert_contains "health check /up production" "$health_body" '"status":"up"'
sim_assert_eq "version confirmée par l’application" "$stable_tag" \
  "$(printf '%s' "$version_body" | php -r '$d=json_decode(stream_get_contents(STDIN),true);echo $d["version"]??"";')"
sim_assert_eq "commit confirmé par l’application" "$merge_main" \
  "$(printf '%s' "$version_body" | php -r '$d=json_decode(stream_get_contents(STDIN),true);echo $d["commit_sha"]??"";')"
sim_assert_contains "test fonctionnel du correctif" "$functional_body" '"total":5'

mkdir -p "$SIM_OUT/evidence/step-09-post-deploy"
cat >"$SIM_OUT/evidence/step-09-post-deploy/post-deploy.json" <<JSON
{
  "health": "ok",
  "health_body": $(printf '%s' "$health_body" | php -r 'echo json_encode(stream_get_contents(STDIN));'),
  "version_body": $(printf '%s' "$version_body" | php -r 'echo json_encode(stream_get_contents(STDIN));'),
  "functional_body": $(printf '%s' "$functional_body" | php -r 'echo json_encode(stream_get_contents(STDIN));'),
  "release_json": $(cat "$prod_current"),
  "artifact_sha256": "$staging_sha",
  "recorded_at": "$(sim_timestamp)"
}
JSON

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Étape 10 — Clôture
# ---------------------------------------------------------------------------

sim_step_begin "E10" "Clôture et contrôle de cohérence final"

sim_assert "hotfix présent dans main" \
  git -C "$repo" merge-base --is-ancestor "$merge_main" origin/main
sim_assert "hotfix présent dans develop" \
  git -C "$repo" merge-base --is-ancestor "$merge_main" origin/develop
sim_assert "tag RC et tag stable cohérents" \
  test "$(git -C "$repo" rev-parse "${rc_tag}^{commit}")" = "$(git -C "$repo" rev-parse "${stable_tag}^{commit}")"
sim_assert "tag RC conservé sur le remote" \
  test "$(git -C "$SIM_REMOTE_PATH" cat-file -t "refs/tags/${rc_tag}")" = tag
sim_assert "tag stable conservé sur le remote" \
  test "$(git -C "$SIM_REMOTE_PATH" cat-file -t "refs/tags/${stable_tag}")" = tag
sim_assert_eq "manifeste final cohérent" "$staging_sha" "$(sim_manifest_get "$promoted_manifest" artifact.sha256)"
sim_assert_eq "manifeste final : tag de la RC promue" "$rc_tag" "$(sim_manifest_get "$promoted_manifest" version)"

mkdir -p "$SIM_OUT/evidence/step-10-closure"

cat >"$SIM_OUT/evidence/step-10-closure/closure.json" <<JSON
{
  "ticket": "CHAN-99-SIMULATION",
  "hotfix_commit": "$merge_main",
  "rc_tag": "$rc_tag",
  "stable_tag": "$stable_tag",
  "artifact_sha256": "$staging_sha",
  "present_in_main": true,
  "present_in_develop": true,
  "staging_artifact_promoted_without_rebuild": true,
  "closed_at": "$(sim_timestamp)"
}
JSON

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Scénarios de migration
# ---------------------------------------------------------------------------

sim_step_begin "S12-S13" "Migrations destructives et incompatibles N/N-1"

migration_dir="$SIM_OUT/evidence/migrations"
mkdir -p "$migration_dir/destructive" "$migration_dir/incompatible" "$migration_dir/safe"

cat >"$migration_dir/destructive/2026_11_18_000001_drop_orders.php" <<'PHP'
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * @phase contract
 * @ticket CHAN-99
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('orders');
    }

    public function down(): void
    {
        // Irréversible.
    }
};
PHP

cat >"$migration_dir/incompatible/2026_11_18_000002_add_required_code.php" <<'PHP'
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * @phase expand
 * @ticket CHAN-99
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('required_code');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('required_code');
        });
    }
};
PHP

cat >"$migration_dir/safe/2026_11_18_000003_add_optional_code.php" <<'PHP'
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * @phase expand
 * @ticket CHAN-99
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('optional_code')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn('optional_code');
        });
    }
};
PHP

php "$script_dir/migration-gate.php" --dir "$migration_dir/destructive" --json \
  >"$SIM_OUT/evidence/migrations/destructive-result.json" 2>&1
destructive_status=$?
if ((destructive_status != 0)); then
  sim_record "S12" "Migration destructive" "PASS" "NO-GO : opération destructrice sans annotation @contract"
else
  sim_record "S12" "Migration destructive" "FAIL" "migration destructive acceptée à tort"
fi

php "$script_dir/migration-gate.php" --dir "$migration_dir/incompatible" --json \
  >"$SIM_OUT/evidence/migrations/incompatible-result.json" 2>&1
incompatible_status=$?
if ((incompatible_status != 0)); then
  sim_record "S13" "Migration incompatible N/N-1" "PASS" "NO-GO : colonne NOT NULL sans défaut"
else
  sim_record "S13" "Migration incompatible N/N-1" "FAIL" "migration incompatible acceptée à tort"
fi

php "$script_dir/migration-gate.php" --dir "$migration_dir/safe" --json \
  >"$SIM_OUT/evidence/migrations/safe-result.json" 2>&1
safe_status=$?
if ((safe_status == 0)); then
  sim_log "OK   migration compatible acceptée (contrôle négatif du gate)"
else
  SIM_STEP_FAILED=1
  sim_log "FAIL migration compatible refusée à tort"
fi

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Scénario d'échec S14 : rollback avec risque sur les données
# ---------------------------------------------------------------------------

sim_step_begin "S14" "Rollback avec risque sur les données : arrêt et escalade"

rollback_fixture="$SIM_OUT/rollback"
rollback_root="$rollback_fixture/chantier.c2me.fr"
rollback_evidence="$SIM_OUT/evidence/rollback"
mkdir -p "$rollback_root"/releases "$rollback_root/shared/storage/app/private" \
  "$rollback_root/shared/storage/app/public" "$rollback_root/shared/storage/framework" \
  "$rollback_root/shared/storage/logs" "$rollback_evidence"
printf 'APP_ENV=production\n' >"$rollback_root/shared/.env"
printf 'donnée persistante simulée\n' >"$rollback_root/shared/storage/app/private/document.txt"

sim_rollback_release() {
  local id="$1"
  local version="$2"
  local commit="$3"
  local dir="$rollback_root/releases/$id"

  mkdir -p "$dir/public" "$dir/bootstrap/cache"
  : >"$dir/artisan"
  : >"$dir/public/index.php"
  : >"$dir/bootstrap/cache/config.php"
  chmod 0640 "$dir/bootstrap/cache/config.php"
  ln -s "$rollback_root/shared/.env" "$dir/.env"
  ln -s "$rollback_root/shared/storage" "$dir/storage"
  ln -s "$rollback_root/shared/storage/app/public" "$dir/public/storage"

  cat >"$dir/release.json" <<JSON
{
  "environment": "production",
  "release": "$id",
  "version": "$version",
  "commit_sha": "$commit",
  "tree_sha": "2222222222222222222222222222222222222222",
  "artifact_id": "9000",
  "sha256": "$(printf 'b%.0s' $(seq 1 64))",
  "deployed_at": "2026-11-18T08:00:00Z"
}
JSON
}

sim_rollback_release "v1.4.2-9000" "v1.4.2" "$prod_sha"
sim_rollback_release "v1.4.3-1002" "v1.4.3" "$merge_main"
ln -s "$rollback_root/releases/v1.4.3-1002" "$rollback_root/current"

sim_write_rollback_attestation() {
  local file="$1"
  local source="$2"
  local target="$3"
  local destructive="$4"
  local proof="$file.migrate-status.txt"
  local checked_at
  checked_at="$(sim_timestamp)"

  cat >"$proof" <<PROOF
C2ME-MIGRATE-STATUS-PROOF
version: 1
environment: production
release: $source
database: chantier_production
captured_at: $checked_at
---
 Migration name ......................................... Batch / Status
 0001_01_01_000000_create_users_table ................... [1] Ran
PROOF
  chmod 0600 "$proof"

  cat >"$file" <<JSON
{
  "schema_version": 1,
  "environment": "production",
  "source_release": "$source",
  "target_release": "$target",
  "database": "chantier_production",
  "checked_at": "$checked_at",
  "checked_by": "simulation-operator",
  "migrate_status_sha256": "$(sim_sha256 "$proof")",
  "migrations": {
    "in_progress": false,
    "pending": false,
    "partial": false,
    "destructive_applied": $destructive,
    "contract_applied": false,
    "compatible_with_target": true
  }
}
JSON
  chmod 0600 "$file"
}

risky_attestation="$rollback_fixture/attestation-risky.json"
sim_write_rollback_attestation "$risky_attestation" "v1.4.3-1002" "v1.4.2-9000" true

# Le script exige un binaire curl même en mode --dry-run.
fake_bin="$SIM_OUT/fake-bin"
cat >"$fake_bin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
printf '{"status":"up"}\n'
FAKE_CURL
chmod +x "$fake_bin/curl"

risky_output="$(C2ME_ROOT="$rollback_root" \
  C2ME_HOST_ID="simulation-host" \
  C2ME_OPERATOR="simulation-operator" \
  C2ME_CURL_BIN="$SIM_OUT/fake-bin/curl" \
  bash "$SIM_PROJECT_ROOT/scripts/ops/rollback.sh" \
  --env production --to "v1.4.2-9000" \
  --reason "test de risque données simulé" \
  --schema-attestation "$risky_attestation" \
  --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged \
  --dry-run 2>&1)"
risky_status=$?
printf '%s\n' "$risky_output" >"$rollback_evidence/risky-refusal.log"
if ((risky_status != 0)) && printf '%s' "$risky_output" | grep -Fq "destructive_applied"; then
  sim_record "S14" "Rollback avec risque sur les données" "PASS" "refus : migration destructive appliquée, escalade requise"
else
  sim_record "S14" "Rollback avec risque sur les données" "FAIL" "rollback accepté à tort (code $risky_status)"
fi

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Simulation du rollback nominal
# ---------------------------------------------------------------------------

sim_step_begin "R01" "Rollback applicatif simulé après échec post-déploiement"

fake_bin="$SIM_OUT/fake-bin"
real_php="$(command -v php)"

cat >"$fake_bin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
printf '%s\n' "curl $*" >>"${SIM_CURL_LOG:?}"
if [[ "${FAKE_CURL_RESULT:-ok}" == "fail" ]]; then
  printf 'health check simulé en échec\n' >&2
  exit 22
fi
printf '{"status":"up"}\n'
FAKE_CURL

cat >"$fake_bin/php" <<FAKE_PHP
#!/usr/bin/env bash
printf '%s\n' "php \$*" >>"\${SIM_PHP_LOG:?}"
exec "$real_php" "\$@"
FAKE_PHP

chmod +x "$fake_bin/curl" "$fake_bin/php"

valid_attestation="$rollback_fixture/attestation-valid.json"
sim_write_rollback_attestation "$valid_attestation" "v1.4.3-1002" "v1.4.2-9000" false

data_file="$rollback_root/shared/storage/app/private/document.txt"
env_file="$rollback_root/shared/.env"
data_sha_before="$(sim_sha256 "$data_file")"
env_sha_before="$(sim_sha256 "$env_file")"
current_before_rollback="$(basename "$(readlink -f "$rollback_root/current")")"

export SIM_CURL_LOG="$rollback_evidence/curl-calls.log"
export SIM_PHP_LOG="$rollback_evidence/php-calls.log"
: >"$SIM_CURL_LOG"
: >"$SIM_PHP_LOG"

dry_run_output="$(C2ME_ROOT="$rollback_root" \
  C2ME_HOST_ID="simulation-host" \
  C2ME_OPERATOR="simulation-operator" \
  C2ME_CURL_BIN="$fake_bin/curl" \
  C2ME_PHP_BIN="$fake_bin/php" \
  bash "$SIM_PROJECT_ROOT/scripts/ops/rollback.sh" \
  --env production --to "v1.4.2-9000" \
  --reason "régression constatée après activation (simulation)" \
  --schema-attestation "$valid_attestation" \
  --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged \
  --dry-run 2>&1)"
dry_run_status=$?
printf '%s\n' "$dry_run_output" >"$rollback_evidence/dry-run.log"

sim_assert_eq "mode --dry-run réussi" "0" "$dry_run_status"
sim_assert_contains "plan validé" "$dry_run_output" "PLAN=ok"
sim_assert_contains "mode dry-run confirmé" "$dry_run_output" "MODE=dry-run"
sim_assert_eq "current inchangé après --dry-run" "$current_before_rollback" \
  "$(basename "$(readlink -f "$rollback_root/current")")"
sim_assert_no_file "aucun journal écrit en dry-run" "$rollback_root/shared/rollback.log"
sim_assert_no_file "aucun verrou écrit en dry-run" "$rollback_root/shared/.release-operation.lock"

rollback_output="$(C2ME_ROOT="$rollback_root" \
  C2ME_HOST_ID="simulation-host" \
  C2ME_OPERATOR="simulation-operator" \
  C2ME_CURL_BIN="$fake_bin/curl" \
  C2ME_PHP_BIN="$fake_bin/php" \
  bash "$SIM_PROJECT_ROOT/scripts/ops/rollback.sh" \
  --env production --to "v1.4.2-9000" \
  --reason "régression constatée après activation (simulation)" \
  --schema-attestation "$valid_attestation" \
  --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged 2>&1)"
rollback_status=$?
printf '%s\n' "$rollback_output" >"$rollback_evidence/execution.log"

sim_assert_eq "rollback exécuté" "0" "$rollback_status"
sim_assert_contains "rollback réussi" "$rollback_output" "ROLLBACK=ok"
sim_assert_contains "health check après rollback" "$rollback_output" "HEALTH=ok"
sim_assert_eq "current pointe sur la version précédente" "v1.4.2-9000" \
  "$(basename "$(readlink -f "$rollback_root/current")")"
sim_assert "aucune restauration de données" \
  test "$data_sha_before" = "$(sim_sha256 "$data_file")"
sim_assert "configuration partagée conservée" \
  test "$env_sha_before" = "$(sim_sha256 "$env_file")"
sim_assert "stockage persistant toujours lié" \
  test "$(readlink -f "$rollback_root/current/storage")" = "$(readlink -f "$rollback_root/shared/storage")"

php_calls="$(cat "$SIM_PHP_LOG")"
printf '%s\n' "$php_calls" >"$rollback_evidence/php-calls-readonly.txt"
sim_assert "aucune commande artisan exécutée" \
  bash -c "! grep -Eq 'artisan' '$rollback_evidence/php-calls-readonly.txt'"
sim_assert "aucune migration demandée au PHP" \
  bash -c "! grep -Eq 'migrate:(rollback|fresh|refresh|reset)|db:wipe' '$rollback_evidence/php-calls-readonly.txt'"

rollback_log="$rollback_root/shared/rollback.log"
sim_assert_file "journal de rollback conservé" "$rollback_log"
sim_assert_contains "health ok journalisé" "$(cat "$rollback_log")" '"health":"ok"'
sim_assert_contains "rollback terminé journalisé" "$(cat "$rollback_log")" '"result":"success"'
sim_assert_contains "workers non modifiés par le script" "$rollback_output" "Workers et files non modifiés par le script"

cat >"$rollback_evidence/summary.json" <<JSON
{
  "dry_run": "PASS",
  "source": "v1.4.3-1002",
  "target": "v1.4.2-9000",
  "health": "ok",
  "data_preserved": true,
  "shared_env_preserved": true,
  "storage_symlink_preserved": true,
  "database_restore": false,
  "migrate_rollback": false,
  "workers_and_queues": "confirmés arrêtés / en pause, non modifiés par le script",
  "executed_at": "$(sim_timestamp)"
}
JSON

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Scénario d'échec S15 : conflit de synchronisation
# ---------------------------------------------------------------------------

sim_step_begin "S15" "Synchronisation avec conflit : branche temporaire"

saved_remote="$SIM_REMOTE_PATH"
saved_work="$SIM_WORK_REPO"
conflict_repo="$SIM_OUT/scenarios/sync-conflict/repo"
conflict_remote="$SIM_OUT/scenarios/sync-conflict/remote.git"

SIM_WORK_REPO="$conflict_repo"
sim_init_repo "$conflict_repo" >/dev/null
sim_init_remote "$conflict_repo" "$conflict_remote" >/dev/null
SIM_REMOTE_PATH="$conflict_remote"

git -C "$conflict_repo" tag -a v2.0.0 -m "Version stable v2.0.0"
git -C "$conflict_repo" push --quiet origin v2.0.0

git -C "$conflict_repo" switch --quiet -c develop
sed -i 's/return \$left - \$right;/return $left + $right + 0;/' "$conflict_repo/app/Greeting.php"
printf 'évolution develop\n' >"$conflict_repo/app/DevelopEvolution.php"
sim_git_commit "$conflict_repo" "feat(chantier): faire évoluer le calcul sur develop"
conflict_develop_sha="$(git -C "$conflict_repo" rev-parse HEAD)"

git -C "$conflict_repo" switch --quiet -c hotfix/CHAN-99-simulation-conflit main
sim_tag_annotated "$conflict_repo" v2.0.1-rc.1
sed -i 's/return \$left - \$right;/return $left + $right;/' "$conflict_repo/app/Greeting.php"
cat >"$conflict_repo/tests/GreetingRegressionTest.php" <<'PHP'
<?php

declare(strict_types=1);

$failures = $failures ?? [];

if (greeting_total(3, 2) !== 5) {
    $failures[] = 'Régression : greeting_total(3, 2) doit valoir 5.';
}
PHP
sim_git_commit "$conflict_repo" "fix(greeting): corriger le calcul du total" -m "Refs: CHAN-99"
conflict_hotfix_sha="$(git -C "$conflict_repo" rev-parse HEAD)"

git -C "$conflict_repo" push --quiet origin develop
git -C "$conflict_repo" push --quiet -u origin hotfix/CHAN-99-simulation-conflit
merge_clone="$SIM_OUT/tmp/conflict-merge-$$"
rm -rf "$merge_clone"
git clone --quiet "$conflict_remote" "$merge_clone"
sim_git_identity "$merge_clone"
git -C "$merge_clone" checkout --quiet -B main origin/main
git -C "$merge_clone" merge --quiet --no-ff --no-edit "$conflict_hotfix_sha"
conflict_main_merge="$(git -C "$merge_clone" rev-parse HEAD)"
git -C "$merge_clone" push --quiet origin "${conflict_main_merge}:refs/heads/tmp/conflict-main-$$"
sim_server_update_ref main "$conflict_main_merge"
git -C "$conflict_remote" update-ref -d "refs/heads/tmp/conflict-main-$$" 2>/dev/null || true
rm -rf "$merge_clone"

sim_fetch "$conflict_repo"

direct_clone="$SIM_OUT/tmp/conflict-direct-$$"
rm -rf "$direct_clone"
git clone --quiet "$conflict_remote" "$direct_clone"
sim_git_identity "$direct_clone"
git -C "$direct_clone" checkout --quiet -B develop origin/develop
if git -C "$direct_clone" merge --no-edit origin/main >"$SIM_OUT/evidence/step-04-pr/s15-direct-conflict.log" 2>&1; then
  sim_log "ANOMALIE: la fusion directe aurait dû entrer en conflit"
  direct_conflict=0
else
  direct_conflict=1
  git -C "$direct_clone" merge --abort >/dev/null 2>&1 || true
fi
rm -rf "$direct_clone"
sim_assert_eq "PR directe main → develop en conflit" "1" "$direct_conflict"

sync_branch="bugfix/CHAN-99-simulation-synchronisation-hotfix"
git -C "$conflict_repo" switch --quiet -c "$sync_branch" origin/develop
if git -C "$conflict_repo" merge --no-edit origin/main >"$SIM_OUT/evidence/step-04-pr/s15-sync-branch-conflict.log" 2>&1; then
  sim_log "ANOMALIE: la branche de synchronisation aurait dû entrer en conflit"
  sync_conflict=0
else
  sync_conflict=1
fi
sim_assert_eq "conflit détecté sur la branche de synchronisation" "1" "$sync_conflict"

cat >"$conflict_repo/app/Greeting.php" <<'PHP'
<?php

declare(strict_types=1);

/**
 * Résolution de simulation : le correctif de production est conservé et
 * l'évolution de develop (fichier dédié) reste présente.
 */
function greeting_total(int $left, int $right): int
{
    return $left + $right;
}
PHP
git -C "$conflict_repo" add app/Greeting.php
git -C "$conflict_repo" commit --quiet --no-edit

sim_assert "correctif conservé après résolution" \
  git -C "$conflict_repo" merge-base --is-ancestor "$conflict_hotfix_sha" HEAD
sim_assert "develop initial conservé après résolution" \
  git -C "$conflict_repo" merge-base --is-ancestor "$conflict_develop_sha" HEAD
sim_assert "évolution de develop toujours présente" test -f "$conflict_repo/app/DevelopEvolution.php"

sync_sha="$(git -C "$conflict_repo" rev-parse HEAD)"
git -C "$conflict_repo" push --quiet -u origin "$sync_branch"

if sim_run_ci "$conflict_repo" "$sync_sha" "sync-conflict"; then
  sim_log "OK   CI verte sur la branche de résolution"
else
  SIM_STEP_FAILED=1
  sim_log "FAIL CI rouge sur la branche de résolution"
fi

sync_pr="$(sim_pr_create "$conflict_repo" develop "$sync_branch" "chore(sync): reporter le hotfix après résolution" \
  "$heat_dir/pull-request.md" "sync-conflict-pr")"
sim_assert_eq "PR de résolution cible develop" "develop" "$(sim_pr_state "$sync_pr" base)"
sim_pr_comment_go "$sync_pr" "Responsable Simulation" "GO résolution $(sim_timestamp)"
conflict_sync_merge="$(sim_pr_merge "$sync_pr" merge)"
sim_assert "fusion de la branche de résolution" test -n "$conflict_sync_merge"
sim_fetch "$conflict_repo"

sim_assert "hotfix présent dans develop après résolution" \
  git -C "$conflict_repo" merge-base --is-ancestor "$conflict_hotfix_sha" origin/develop
sim_assert "develop initial conservé après fusion" \
  git -C "$conflict_repo" merge-base --is-ancestor "$conflict_develop_sha" origin/develop

sim_step_record_current "S15" "Synchronisation avec conflit" \
  "conflit détecté puis résolu sur $sync_branch, historiques conservés"
sim_step_end

SIM_REMOTE_PATH="$saved_remote"
SIM_WORK_REPO="$saved_work"

# ---------------------------------------------------------------------------
# Scénario d'échec S16 : push direct sur branche protégée
# ---------------------------------------------------------------------------

sim_step_begin "S16" "Push direct sur branche protégée simulée : refus"

main_before_push="$(sim_remote_sha main)"
develop_before_push="$(sim_remote_sha develop)"

# Commit divergent local uniquement : il ne modifie aucune branche du remote.
divergent_commit="$(git -C "$repo" commit-tree \
  "$(git -C "$repo" rev-parse 'origin/main^{tree}')" \
  -m "chore(simulation): tentative de push direct" \
  -p "$(sim_remote_sha main)")"

# Commit en avance rapide sur develop pour atteindre le hook serveur.
develop_divergent_commit="$(git -C "$repo" commit-tree \
  "$(git -C "$repo" rev-parse 'origin/develop^{tree}')" \
  -m "chore(simulation): tentative de push direct sur develop" \
  -p "$(sim_remote_sha develop)")"

if git -C "$repo" push --quiet origin "${divergent_commit}:main" >"$SIM_OUT/evidence/step-04-pr/push-main.log" 2>&1; then
  sim_log "FAIL push direct sur main accepté"
  SIM_STEP_FAILED=1
else
  sim_log "OK   push direct sur main refusé"
fi

if git -C "$repo" push --quiet origin "${develop_divergent_commit}:develop" >"$SIM_OUT/evidence/step-04-pr/push-develop.log" 2>&1; then
  sim_log "FAIL push direct sur develop accepté"
  SIM_STEP_FAILED=1
else
  sim_log "OK   push direct sur develop refusé"
fi

sim_check_ok "message de refus du hook pour main" \
  grep -q "push direct interdit sur refs/heads/main" "$SIM_OUT/evidence/step-04-pr/push-main.log"
sim_check_ok "message de refus du hook pour develop" \
  grep -q "push direct interdit sur refs/heads/develop" "$SIM_OUT/evidence/step-04-pr/push-develop.log"

sim_assert_eq "branche main inchangée" "$main_before_push" "$(sim_remote_sha main)"
sim_assert_eq "branche develop inchangée" "$develop_before_push" "$(sim_remote_sha develop)"

sim_step_record_current "S16" "Push direct sur branche protégée" \
  "hook pre-receive : pushes directs sur main et develop refusés"
sim_step_end

# ---------------------------------------------------------------------------
# Traçabilité finale
# ---------------------------------------------------------------------------

sim_section "Traçabilité finale"

git -C "$repo" fetch --quiet --tags origin
git -C "$repo" log --graph --oneline --decorate --all >"$SIM_OUT/evidence/git/final-graph.txt"
git -C "$repo" show-ref --heads --tags >"$SIM_OUT/evidence/git/final-refs.txt" 2>/dev/null || true
git -C "$repo" log --all --format='%H%x09%ad%x09%s' --date=iso-strict >"$SIM_OUT/evidence/git/commits.tsv"

{
  printf 'tag\tsha\ttype\n'
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    printf '%s\t%s\t%s\n' "$tag" "$(git -C "$repo" rev-parse "${tag}^{commit}")" \
      "$(git -C "$repo" cat-file -t "refs/tags/${tag}")"
  done < <(git -C "$repo" tag -l | sort -V)
} >"$SIM_OUT/evidence/git/tags.tsv"

{
  printf 'branch\tsha\n'
  for branch in main develop "$hotfix_branch"; do
    printf '%s\t%s\n' "$branch" "$(git -C "$SIM_REMOTE_PATH" rev-parse "refs/heads/${branch}^{commit}" 2>/dev/null || echo absent)"
  done
} >"$SIM_OUT/evidence/git/branches.tsv"

sim_record "TRACE" "Traçabilité Git et artefacts" "PASS" \
  "SHA consignés, graphe final, tags, manifestes et sommes dans $SIM_OUT/evidence"

# ---------------------------------------------------------------------------
# Vérifications documentaires
# ---------------------------------------------------------------------------

sim_step_begin "D01" "Liens documentaires et blocs Bash"

docs=(
  docs/development/hotfix-process.md
  docs/development/hotfix-runbook.md
  docs/development/git-workflow.md
  docs/development/release-process.md
  docs/development/deployment-process.md
  docs/development/application-rollback-runbook.md
)

# Les documents sont vérifiés depuis le dépôt réel, en lecture seule.
docs_result="$(php "$script_dir/docs-check.php" \
  --root "$SIM_PROJECT_ROOT" \
  --emit "$SIM_OUT/evidence/docs/powershell" \
  "${docs[@]}" 2>&1)"
docs_status=$?
printf '%s\n' "$docs_result" >"$SIM_OUT/evidence/docs/result.json"

if ((docs_status == 0)); then
  sim_log "OK   liens documentaires et blocs Bash valides"
  sim_log "     $(printf '%s' "$docs_result" | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo json_encode($d["stats"] ?? []);')"
else
  SIM_STEP_FAILED=1
  sim_log "FAIL vérification documentaire"
  printf '%s\n' "$docs_result" | sed 's/^/     /' >&2
fi

sim_step_end "$SIM_STEP_CHECKS contrôle(s)"

# ---------------------------------------------------------------------------
# Rapport final
# ---------------------------------------------------------------------------

sim_section "Synthèse"

report_path="$(sim_write_report)"

printf '\nPASS : %d\n' "$SIM_PASS"
printf 'FAIL : %d\n' "$SIM_FAIL"
printf 'NOT RUN : %s\n' "$(awk -F '\t' '$3 == "NOT RUN" {count++} END {print count + 0}' "$SIM_OUT/report/results.tsv")"
printf 'Rapport : %s\n' "$report_path"
printf 'Preuves : %s\n' "$SIM_OUT"

if ((SIM_FAIL > 0)); then
  exit 1
fi

exit 0
