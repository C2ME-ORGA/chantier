#!/usr/bin/env bash
#
# Simulation Git locale pour CHAN-99 (Lot 6).
#
# Fournit :
# - un dépôt de travail et un remote bare local ;
# - un hook pre-receive qui refuse les pushes directs sur main et develop ;
# - un simulateur de Pull Request (ouverture, contrôles CI, GO, fusion) ;
# - les contrôles de préflight du processus hotfix.
#
# Aucun remote réel n'est utilisé : SIM_REMOTE_PATH pointe toujours vers un
# répertoire bare créé sous SIM_OUT.

set -uo pipefail

SIM_REMOTE_PATH=""
SIM_WORK_REPO=""
SIM_GIT_DATE_COUNTER=0
SIM_PR_COUNTER=0
SIM_LAST_PR=""

sim_git_identity() {
  local repo="$1"

  git -C "$repo" config user.name "Simulation CHAN-99"
  git -C "$repo" config user.email "simulation-chan-99@example.invalid"
  git -C "$repo" config commit.gpgsign false
  git -C "$repo" config core.autocrlf false
}

sim_git_date() {
  local base="2026-11-18T09:00:00Z"
  local seconds=$((SIM_GIT_DATE_COUNTER * 60))

  SIM_GIT_DATE_COUNTER=$((SIM_GIT_DATE_COUNTER + 1))

  date -u -d "$base + $seconds seconds" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
    || date -u '+%Y-%m-%dT%H:%M:%SZ'
}

sim_git_commit() {
  local repo="$1"
  local message="$2"
  shift 2
  local date

  date="$(sim_git_date)"

  git -C "$repo" add -A
  GIT_AUTHOR_DATE="$date" \
  GIT_COMMITTER_DATE="$date" \
  git -C "$repo" commit --quiet -m "$message" "$@"
}

sim_write_fixture_app() {
  local repo="$1"

  mkdir -p \
    "$repo/app" \
    "$repo/bootstrap/cache" \
    "$repo/public/build/assets" \
    "$repo/tests" \
    "$repo/vendor/composer" \
    "$repo/database/migrations"

  cat >"$repo/app/Greeting.php" <<'PHP'
<?php

declare(strict_types=1);

/**
 * Fonction métier de la simulation.
 *
 * La version de production v1.4.2 contient volontairement un défaut :
 * l'addition est remplacée par une soustraction.
 */
function greeting_total(int $left, int $right): int
{
    return $left - $right;
}
PHP

  cat >"$repo/tests/run.php" <<'PHP'
<?php

declare(strict_types=1);

$failures = [];

require __DIR__.'/../app/Greeting.php';

foreach (glob(__DIR__.'/*Test.php') ?: [] as $test) {
    require $test;
}

if ($failures !== []) {
    fwrite(STDERR, "ECHEC\n");

    foreach ($failures as $failure) {
        fwrite(STDERR, '- '.$failure."\n");
    }

    exit(1);
}

fwrite(STDOUT, "OK\n");
PHP

  cat >"$repo/tests/BaselineTest.php" <<'PHP'
<?php

declare(strict_types=1);

$failures = $failures ?? [];

if (greeting_total(0, 0) !== 0) {
    $failures[] = 'Le calcul de référence est cassé.';
}
PHP

  cat >"$repo/artisan" <<'PHP'
#!/usr/bin/env php
<?php

declare(strict_types=1);

fwrite(STDOUT, "artisan de simulation\n");
PHP

  cat >"$repo/bootstrap/app.php" <<'PHP'
<?php

declare(strict_types=1);

return [];
PHP

  cat >"$repo/public/index.php" <<'PHP'
<?php

declare(strict_types=1);

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

header('Content-Type: application/json');

if ($path === '/up') {
    echo '{"status":"up"}';

    return;
}

if ($path === '/version') {
    $release = dirname(__DIR__).'/release.json';
    echo is_file($release) ? (string) file_get_contents($release) : '{"version":"unknown"}';

    return;
}

if ($path === '/api/total') {
    require dirname(__DIR__).'/app/Greeting.php';
    $left = (int) ($_GET['a'] ?? 0);
    $right = (int) ($_GET['b'] ?? 0);
    echo json_encode(['total' => greeting_total($left, $right)]);

    return;
}

http_response_code(404);
echo '{"error":"not found"}';
PHP

  printf '{\n  "name": "c2me/chantier-simulation",\n  "type": "project"\n}\n' >"$repo/composer.json"
  printf '{"packages": [], "packages-dev": []}\n' >"$repo/composer.lock"
  printf '{"name": "chantier-simulation", "lockfileVersion": 3, "packages": {}}\n' >"$repo/package-lock.json"
  printf '{\n  "resources/js/app.js": {"file": "assets/app.js", "isEntry": true}\n}\n' >"$repo/public/build/manifest.json"
  printf '/* simulation */\n' >"$repo/public/build/assets/app.css"

  cat >"$repo/vendor/autoload.php" <<'PHP'
<?php

declare(strict_types=1);

require __DIR__.'/composer/autoload_real.php';
PHP

  printf '<?php\n\ndeclare(strict_types=1);\n' >"$repo/vendor/composer/autoload_real.php"
  printf '<?php\n\ndeclare(strict_types=1);\n' >"$repo/vendor/composer/autoload_static.php"
  printf '<?php\n\nreturn [];\n' >"$repo/vendor/composer/installed.php"

  cat >"$repo/database/migrations/2026_11_01_000000_create_greetings_table.php" <<'PHP'
<?php

declare(strict_types=1);

/**
 * @phase expand
 * @ticket CHAN-99
 */
return new class
{
    public function up(): void
    {
        // Migration de référence, non destructive.
    }
};
PHP

  chmod +x "$repo/artisan" || true
}

sim_init_repo() {
  local repo="$1"

  mkdir -p "$repo"
  git -C "$repo" init --quiet --initial-branch=main
  sim_git_identity "$repo"
  sim_write_fixture_app "$repo"
  sim_git_commit "$repo" "feat(chantier): initialiser l’application de simulation"
  git -C "$repo" tag -a v1.4.2 -m "Version stable v1.4.2"

  printf '%s\n' "$repo"
}

sim_init_remote() {
  local repo="$1"
  local remote="$2"

  mkdir -p "$remote"
  git -C "$remote" init --quiet --bare
  git -C "$remote" symbolic-ref HEAD refs/heads/main

  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push --quiet origin main --tags

  cat >"$remote/hooks/pre-receive" <<'HOOK'
#!/usr/bin/env bash
#
# Simulation des rulesets GitHub : aucun push direct sur main ou develop.
# Les fusions de Pull Request sont appliquées côté « serveur » par mise à jour
# de référence, jamais par un push client.

set -uo pipefail
status=0

while read -r old_sha new_sha ref; do
    case "$ref" in
        refs/heads/main|refs/heads/develop)
            if [[ "$old_sha" != "0000000000000000000000000000000000000000" ]]; then
                printf 'refus: push direct interdit sur %s (branche protégée simulée)\n' "$ref" >&2
                status=1
            fi
            ;;
    esac
done

exit "$status"
HOOK
  chmod +x "$remote/hooks/pre-receive"

  SIM_REMOTE_PATH="$remote"
  printf '%s\n' "$remote"
}

sim_server_update_ref() {
  local branch="$1"
  local sha="$2"

  git -C "$SIM_REMOTE_PATH" update-ref "refs/heads/${branch}" "$sha"
}

sim_fetch() {
  local repo="$1"

  git -C "$repo" fetch --quiet --prune origin '+refs/heads/*:refs/remotes/origin/*' --tags
}

sim_remote_sha() {
  local branch="$1"

  git -C "$SIM_REMOTE_PATH" rev-parse "refs/heads/${branch}^{commit}"
}

sim_run_ci() {
  local repo="$1"
  local sha="$2"
  local label="$3"
  local worktree="$SIM_OUT/tmp/ci-${label}-$$"
  local output_dir="$SIM_OUT/evidence/ci"
  local status=0
  local log="$output_dir/ci-${label}.log"

  mkdir -p "$output_dir"
  rm -rf "$worktree"

  if ! git -C "$repo" worktree add --quiet --detach "$worktree" "$sha" 2>>"$log"; then
    printf '{"sha":"%s","conclusion":"failure","reason":"worktree"}\n' "$sha" >"$output_dir/ci-${label}.json"
    printf '[%s] échec de création du worktree CI\n' "$(sim_timestamp)" >>"$log"
    return 1
  fi

  : >"$log"
  printf '[%s] CI simulée sur %s (%s)\n' "$(sim_timestamp)" "$sha" "$label" >>"$log"

  while IFS= read -r file; do
    if ! php -l "$file" >>"$log" 2>&1; then
      status=1
    fi
  done < <(find "$worktree" -type f -name '*.php' -not -path '*/vendor/*' | sort)

  if ! (cd "$worktree" && php tests/run.php >>"$log" 2>&1); then
    status=1
  fi

  git -C "$repo" worktree remove --force "$worktree" >/dev/null 2>&1 || true

  local conclusion="success"
  if ((status != 0)); then
    conclusion="failure"
  fi

  cat >"$output_dir/ci-${label}.json" <<JSON
{
  "sha": "$sha",
  "conclusion": "$conclusion",
  "jobs": {
    "ci": "$conclusion",
    "sqlite": "$conclusion",
    "mariadb-10.11": "$conclusion",
    "package-linux": "$conclusion"
  }
}
JSON

  [[ "$conclusion" == "success" ]]
}

sim_pr_create() {
  local repo="$1"
  local base="$2"
  local head="$3"
  local title="$4"
  local body_file="$5"
  local ci_label="$6"

  local counter_file="$SIM_OUT/state/pr/counter"
  mkdir -p "$SIM_OUT/state/pr"
  SIM_PR_COUNTER=$(( $(cat "$counter_file" 2>/dev/null || printf '0') + 1 ))
  printf '%s\n' "$SIM_PR_COUNTER" >"$counter_file"
  local number=$SIM_PR_COUNTER
  local state_dir="$SIM_OUT/state/pr"
  local head_sha base_sha ci

  mkdir -p "$state_dir"

  head_sha="$(git -C "$repo" rev-parse "origin/${head}^{commit}" 2>/dev/null || git -C "$repo" rev-parse "${head}^{commit}")"
  base_sha="$(sim_remote_sha "$base")"

  if sim_run_ci "$repo" "$head_sha" "$ci_label"; then
    ci="success"
  else
    ci="failure"
  fi

  cat >"$state_dir/pr-${number}.tsv" <<STATE
number	$number
repo	$repo
base	$base
head	$head
title	$title
body	$body_file
head_sha	$head_sha
base_sha	$base_sha
draft	false
ci	$ci
go	no
merge_sha	none
STATE

  SIM_LAST_PR="$number"
  printf '%s\n' "$number"
}

sim_pr_state() {
  local number="$1"
  local key="$2"

  awk -F '\t' -v key="$key" '$1 == key {print $2; exit}' "$SIM_OUT/state/pr/pr-${number}.tsv"
}

sim_pr_set() {
  local number="$1"
  local key="$2"
  local value="$3"
  local file="$SIM_OUT/state/pr/pr-${number}.tsv"
  local tmp="${file}.tmp"

  awk -F '\t' -v key="$key" -v value="$value" '
    BEGIN { OFS = "\t" }
    $1 == key { print key, value; next }
    { print }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

sim_pr_refuse_merge_reason() {
  local number="$1"
  local mode="$2"
  local state_file="$SIM_OUT/state/pr/pr-${number}.tsv"

  if [[ ! -f "$state_file" ]]; then
    printf 'PR %s inconnue\n' "$number"
    return 0
  fi

  if [[ "$(sim_pr_state "$number" ci)" != "success" ]]; then
    printf 'CI non verte pour la PR %s\n' "$number"
    return 0
  fi

  if [[ "$(sim_pr_state "$number" go)" != "yes" ]]; then
    printf 'autorisation humaine (GO) absente pour la PR %s\n' "$number"
    return 0
  fi

  if [[ "$(sim_pr_state "$number" draft)" != "false" ]]; then
    printf 'PR %s en brouillon\n' "$number"
    return 0
  fi

  if [[ "$mode" == "squash" ]]; then
    printf 'squash interdit sur main et develop\n'
    return 0
  fi

  if [[ "$mode" != "merge" ]]; then
    printf 'méthode de fusion non autorisée : %s\n' "$mode"
    return 0
  fi

  local base expected_base
  base="$(sim_pr_state "$number" base)"
  expected_base="$(sim_pr_state "$number" base_sha)"

  if [[ "$(sim_remote_sha "$base")" != "$expected_base" ]]; then
    printf 'la branche %s a avancé : la PR %s doit être mise à jour\n' "$base" "$number"
    return 0
  fi

  return 1
}

sim_pr_merge() {
  local number="$1"
  local mode="$2"
  local reason

  if reason="$(sim_pr_refuse_merge_reason "$number" "$mode")"; then
    printf 'REFUS: %s\n' "$reason" >&2
    return 1
  fi

  local base head head_sha merge_dir merge_sha
  base="$(sim_pr_state "$number" base)"
  head="$(sim_pr_state "$number" head)"
  head_sha="$(sim_pr_state "$number" head_sha)"
  merge_dir="$SIM_OUT/tmp/pr-merge-${number}-$$"

  rm -rf "$merge_dir"
  git clone --quiet "$SIM_REMOTE_PATH" "$merge_dir"
  sim_git_identity "$merge_dir"
  git -C "$merge_dir" checkout --quiet -B "$base" "origin/${base}"

  if ! git -C "$merge_dir" merge --no-ff \
    -m "Merge pull request #${number} from ${head} into ${base}" \
    "$head_sha" >>"$SIM_OUT/log/merge-${number}.log" 2>&1; then
    printf 'REFUS: conflit de fusion pour la PR %s ; utiliser une branche de synchronisation\n' "$number" >&2
    return 1
  fi

  merge_sha="$(git -C "$merge_dir" rev-parse HEAD)"
  local tmp_ref="refs/heads/tmp/pr-merge-${number}-$$"

  # Les objets du commit de fusion doivent exister dans le bare avant la mise à
  # jour de la branche protégée : c'est le rôle joué par GitHub côté serveur.
  if ! git -C "$merge_dir" push --quiet origin "${merge_sha}:${tmp_ref}" >>"$SIM_OUT/log/merge-${number}.log" 2>&1; then
    printf 'REFUS: impossible de publier le commit de fusion de la PR %s\n' "$number" >&2
    return 1
  fi

  if ! sim_server_update_ref "$base" "$merge_sha"; then
    printf 'REFUS: mise à jour serveur de %s impossible\n' "$base" >&2
    return 1
  fi

  git -C "$SIM_REMOTE_PATH" update-ref -d "$tmp_ref" 2>/dev/null || true
  sim_pr_set "$number" merge_sha "$merge_sha"

  rm -rf "$merge_dir"

  printf '%s\n' "$merge_sha"
}

sim_pr_comment_go() {
  local number="$1"
  local author="$2"
  local comment="$3"

  sim_pr_set "$number" go "yes"
  printf '%s — %s — %s\n' "$(sim_timestamp)" "$author" "$comment" \
    >>"$SIM_OUT/state/pr/pr-${number}.go.txt"
}

sim_tag_annotated() {
  local repo="$1"
  local tag="$2"
  local commit="${3:-}"

  if [[ -n "$commit" ]]; then
    git -C "$repo" tag -a "$tag" -m "$tag" "$commit"
  else
    git -C "$repo" tag -a "$tag" -m "$tag"
  fi
}

sim_tag_lightweight() {
  local repo="$1"
  local tag="$2"
  local commit="${3:-}"

  if [[ -n "$commit" ]]; then
    git -C "$repo" tag "$tag" "$commit"
  else
    git -C "$repo" tag "$tag"
  fi
}

sim_assert_annotated_tag() {
  local repo="$1"
  local tag="$2"

  [[ "$(git -C "$repo" cat-file -t "refs/tags/${tag}" 2>/dev/null || true)" == "tag" ]]
}

sim_commit_is_conventional() {
  local subject="$1"

  [[ "$subject" =~ ^(feat|fix|test|chore|docs|refactor|perf|build|ci)\([a-z0-9._-]+\):\ [a-z].*[^.]$ ]]
}

sim_check_production_reference() {
  local repo="$1"
  local prod_tag="$2"
  local release_json="$3"
  local expected_environment="${4:-production}"
  local failures=0
  local prod_commit main_sha stable_tags release_version release_commit release_environment

  if ! sim_assert_annotated_tag "$repo" "$prod_tag"; then
    printf 'Le tag %s n’est pas annoté.\n' "$prod_tag" >&2
    failures=$((failures + 1))
  fi

  prod_commit="$(git -C "$repo" rev-parse "${prod_tag}^{commit}" 2>/dev/null || true)"
  main_sha="$(sim_remote_sha main)"

  if [[ -z "$prod_commit" ]]; then
    printf 'Tag %s introuvable.\n' "$prod_tag" >&2
    return 1
  fi

  if [[ "$main_sha" != "$prod_commit" ]]; then
    printf 'origin/main (%s) n’est pas alignée sur la production %s (%s) : NO-GO.\n' \
      "$main_sha" "$prod_tag" "$prod_commit" >&2
    failures=$((failures + 1))
  fi

  stable_tags="$(git -C "$repo" tag --points-at "$prod_commit" | grep -Ec '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' || true)"

  if [[ "$stable_tags" != "1" ]]; then
    printf 'Nombre de tags stables sur %s : %s (attendu 1).\n' "$prod_commit" "$stable_tags" >&2
    failures=$((failures + 1))
  fi

  if [[ ! -f "$release_json" ]]; then
    printf 'release.json de production introuvable : %s\n' "$release_json" >&2
    failures=$((failures + 1))
  else
    release_version="$(php -r '$d=json_decode(file_get_contents($argv[1]),true);echo $d["version"]??"";' "$release_json")"
    release_commit="$(php -r '$d=json_decode(file_get_contents($argv[1]),true);echo $d["commit_sha"]??"";' "$release_json")"
    release_environment="$(php -r '$d=json_decode(file_get_contents($argv[1]),true);echo $d["environment"]??"";' "$release_json")"

    [[ "$release_version" == "$prod_tag" ]] || {
      printf 'release.json version %s != tag %s\n' "$release_version" "$prod_tag" >&2
      failures=$((failures + 1))
    }
    [[ "$release_commit" == "$prod_commit" ]] || {
      printf 'release.json commit %s != tag %s\n' "$release_commit" "$prod_commit" >&2
      failures=$((failures + 1))
    }
    [[ "$release_environment" == "$expected_environment" ]] || {
      printf 'release.json environnement %s inattendu\n' "$release_environment" >&2
      failures=$((failures + 1))
    }
  fi

  ((failures == 0))
}

sim_branch_starts_from_main() {
  local repo="$1"
  local branch="$2"
  local main_sha="$3"
  local develop_sha="$4"
  local branch_sha merge_base_develop

  branch_sha="$(git -C "$repo" rev-parse "${branch}^{commit}" 2>/dev/null || true)"

  [[ -n "$branch_sha" ]] || return 1
  git -C "$repo" merge-base --is-ancestor "$main_sha" "$branch_sha" || return 1

  merge_base_develop="$(git -C "$repo" merge-base "$branch_sha" "$develop_sha")"

  [[ "$merge_base_develop" == "$main_sha" ]]
}

sim_branch_contains_develop() {
  local repo="$1"
  local branch="$2"
  local develop_sha="$3"

  git -C "$repo" merge-base --is-ancestor "$develop_sha" "$branch" 2>/dev/null
}
