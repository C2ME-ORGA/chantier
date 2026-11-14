#!/usr/bin/env bash
#
# Tests du rollback applicatif CHAN-98 (lot 3).
#
# Aucun serveur, aucune base, aucun déploiement réel. Les releases, le lien
# current, le health check et les attestations sont simulés dans un bac à sable.
#
# Exécution : bash scripts/ops/tests/test-rollback.sh

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ops_dir="$project_root/scripts/ops"
work_dir="$(mktemp -d)"
fake_bin="$work_dir/bin"
passed=0
failed=0
skipped=0

cleanup() {
  rm -rf "$work_dir"
  return 0
}
trap cleanup EXIT

pass() {
  passed=$((passed + 1))
}

fail() {
  failed=$((failed + 1))
  printf 'FAIL: %s\n' "$*" >&2
}

skip() {
  skipped=$((skipped + 1))
  printf 'SKIP: %s\n' "$*" >&2
}

assert_status() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass
  else
    fail "$label : code $actual au lieu de $expected."
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    pass
  else
    fail "$label : sortie sans '$needle'."
  fi
}

assert_file() {
  local path="$1"
  local label="$2"

  if [[ -f "$path" ]]; then
    pass
  else
    fail "$label : fichier absent $path."
  fi
}

mkdir -p "$fake_bin"

# ---------------------------------------------------------------------------
# Doubles de test
# ---------------------------------------------------------------------------

real_curl="$(command -v curl || true)"

cat >"$fake_bin/curl" <<FAKE
#!/usr/bin/env bash
if [[ -n "\${FAKE_CURL_SLEEP:-}" ]]; then
  printf '%s\n' "\$\$" >"\${FAKE_CURL_PID:?}"
  trap 'printf stopped >"\${FAKE_CURL_STOP:?}"; exit 143' TERM
  sleep "\${FAKE_CURL_SLEEP}"
fi
if [[ "\${FAKE_CURL_RESULT:-ok}" == 'fail' ]]; then
  echo 'health check factice en échec' >&2
  exit 22
fi
if [[ "\${FAKE_CURL_RESULT:-ok}" == 'invalid' ]]; then
  printf 'page inattendue\n'
  exit 0
fi
printf '{"status":"up"}\n'
FAKE
chmod +x "$fake_bin/curl"

export PATH="$fake_bin:$PATH"
export C2ME_HOST_ID="test-host"
export C2ME_OPERATOR="test-operator"
export C2ME_CURL_BIN="$fake_bin/curl"

if ! command -v flock >/dev/null 2>&1; then
  export C2ME_ALLOW_MISSING_FLOCK=1
fi

# ---------------------------------------------------------------------------
# Bac à sable
# ---------------------------------------------------------------------------

SOURCE_ID='v0.2.0-2-1'
TARGET_ID='v0.1.0-1-1'
CASE_ROOT=''
CASE_DIR=''
ATTESTATION=''

create_release() {
  local root="$1"
  local id="$2"
  local version="$3"
  local commit="$4"
  local environment="$5"
  local dir="$root/releases/$id"

  mkdir -p "$dir/public" "$dir/bootstrap/cache"
  : >"$dir/artisan"
  : >"$dir/public/index.php"
  : >"$dir/bootstrap/cache/config.php"
  chmod 0640 "$dir/bootstrap/cache/config.php"

  ln -s "$root/shared/.env" "$dir/.env"
  ln -s "$root/shared/storage" "$dir/storage"
  ln -s "$root/shared/storage/app/public" "$dir/public/storage"

  cat >"$dir/release.json" <<JSON
{
    "environment": "$environment",
    "release": "$id",
    "version": "$version",
    "commit_sha": "$commit",
    "tree_sha": "1111111111111111111111111111111111111111",
    "artifact_id": "1",
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "deployed_at": "2026-11-13T00:00:00Z"
}
JSON
}

env_root_name() {
  case "$1" in
    staging) printf 'chantier-staging.c2me.ovh\n' ;;
    production) printf 'chantier.c2me.fr\n' ;;
  esac
}

env_database() {
  case "$1" in
    staging) printf 'chantier_staging\n' ;;
    production) printf 'chantier_production\n' ;;
  esac
}

setup_case() {
  local name="$1"
  local environment="$2"
  local source_id="${3:-$SOURCE_ID}"
  local target_id="${4:-$TARGET_ID}"

  CASE_DIR="$work_dir/$name"
  CASE_ROOT="$CASE_DIR/$(env_root_name "$environment")"
  ATTESTATION="$CASE_DIR/attestation.json"

  mkdir -p "$CASE_ROOT/releases" \
    "$CASE_ROOT/shared/storage/app/private" \
    "$CASE_ROOT/shared/storage/app/public" \
    "$CASE_ROOT/shared/storage/framework"

  printf 'APP_ENV=%s\n' "$environment" >"$CASE_ROOT/shared/.env"
  printf 'fichier privé\n' >"$CASE_ROOT/shared/storage/app/private/document.txt"

  create_release "$CASE_ROOT" "$target_id" 'v0.1.0' '1111111111111111111111111111111111111111' "$environment"
  create_release "$CASE_ROOT" "$source_id" 'v0.2.0' '2222222222222222222222222222222222222222' "$environment"

  ln -s "$CASE_ROOT/releases/$source_id" "$CASE_ROOT/current"

  write_attestation "$ATTESTATION" "$environment" "$source_id" "$target_id" "$(env_database "$environment")" \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    '{"in_progress":false,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}'

  export C2ME_ROOT="$CASE_ROOT"
}

write_attestation() {
  local file="$1"
  local environment="$2"
  local source="$3"
  local target="$4"
  local database="$5"
  local checked_at="$6"
  local migrations="$7"
  local proof="$file.migrate-status.txt"

  cat >"$proof" <<PROOF
C2ME-MIGRATE-STATUS-PROOF
version: 1
environment: $environment
release: $source
database: $database
captured_at: $checked_at
---
 Migration name ......................................... Batch / Status
 0001_01_01_000000_create_users_table ................... [1] Ran
 0001_01_01_000001_create_cache_table ................... [1] Ran
PROOF
  chmod 0600 "$proof"

  local digest
  digest="$(sha256sum "$proof" | awk '{print $1}')"

  cat >"$file" <<JSON
{
  "schema_version": 1,
  "environment": "$environment",
  "source_release": "$source",
  "target_release": "$target",
  "database": "$database",
  "checked_at": "$checked_at",
  "checked_by": "test-operator",
  "migrate_status_sha256": "$digest",
  "migrations": $migrations
}
JSON
  chmod 0600 "$file"
}

rollback() {
  bash "$ops_dir/rollback.sh" "$@" 2>&1
}

rollback_args() {
  local environment="$1"
  local target="$2"

  printf '%s\n' \
    --env "$environment" \
    --to "$target" \
    --reason 'test de rollback simulé' \
    --schema-attestation "$ATTESTATION" \
    --confirm-workers-stopped \
    --confirm-queues-paused \
    --confirm-jobs-triaged
}

run_rollback() {
  local environment="$1"
  local target="$2"
  shift 2

  local args=()
  while IFS= read -r line; do
    args+=("$line")
  done < <(rollback_args "$environment" "$target")

  rollback "${args[@]}" "$@"
}

current_id() {
  basename "$(readlink -f "$CASE_ROOT/current")"
}

current_target() {
  printf '%s\n' "$CASE_ROOT/releases/$1"
}

BLOCKED_PID=""
BLOCKED_CURL_PID_FILE=""
BLOCKED_CURL_STOP_FILE=""

# Démarre un rollback bloqué dans le health check, donc après acquisition du
# verrou et bascule de current.
start_blocked_rollback() {
  local label="$1"

  BLOCKED_CURL_PID_FILE="$work_dir/$label-curl.pid"
  BLOCKED_CURL_STOP_FILE="$work_dir/$label-curl.stop"
  rm -f "$BLOCKED_CURL_PID_FILE" "$BLOCKED_CURL_STOP_FILE"

  FAKE_CURL_SLEEP=30 FAKE_CURL_PID="$BLOCKED_CURL_PID_FILE" FAKE_CURL_STOP="$BLOCKED_CURL_STOP_FILE" \
    bash "$ops_dir/rollback.sh" --env staging --to "$TARGET_ID" \
    --reason "test verrou $label" --schema-attestation "$ATTESTATION" \
    --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged \
    >"$CASE_DIR/$label.log" 2>&1 &
  BLOCKED_PID=$!

  for attempt in $(seq 1 150); do
    [[ -s "$BLOCKED_CURL_PID_FILE" ]] && return 0
    sleep 0.1
  done

  return 1
}

stop_blocked_rollback() {
  local status

  kill -TERM "$BLOCKED_PID" 2>/dev/null
  wait "$BLOCKED_PID" 2>/dev/null
  status=$?

  return "$status"
}

# ---------------------------------------------------------------------------
# 1. Rollback nominal staging
# ---------------------------------------------------------------------------

if ! ln -s "$work_dir" "$work_dir/link-probe" 2>/dev/null; then
  skip 'les liens symboliques ne sont pas disponibles : tests de rollback non exécutés.'
  printf '\n%d test(s) réussi(s), %d échec(s), %d ignoré(s).\n' "$passed" "$failed" "$skipped"
  exit 0
fi
rm -f "$work_dir/link-probe"

setup_case 'nominal-staging' staging
env_hash_before="$(sha256sum "$CASE_ROOT/shared/.env" | awk '{print $1}')"
storage_hash_before="$(find "$CASE_ROOT/shared/storage" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

assert_status 0 "$status" 'rollback nominal staging'
assert_contains "$output" 'ROLLBACK=ok' 'confirmation du rollback'
assert_status "$TARGET_ID" "$(current_id)" 'current pointe vers la cible'

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'le verrou subsiste après un rollback réussi.'
fi

env_hash_after="$(sha256sum "$CASE_ROOT/shared/.env" | awk '{print $1}')"
storage_hash_after="$(find "$CASE_ROOT/shared/storage" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')"

if [[ "$env_hash_before" == "$env_hash_after" ]]; then
  pass
else
  fail '.env a été modifié par le rollback.'
fi

if [[ "$storage_hash_before" == "$storage_hash_after" ]]; then
  pass
else
  fail 'shared/storage a été modifié par le rollback.'
fi

if [[ -f "$CASE_ROOT/shared/rollback.log" ]]; then
  pass
else
  fail 'journal de rollback absent.'
fi

assert_contains "$(cat "$CASE_ROOT/shared/rollback.log")" '"event":"started"' 'entrée started'
assert_contains "$(cat "$CASE_ROOT/shared/rollback.log")" '"event":"completed"' 'entrée completed'
assert_contains "$(cat "$CASE_ROOT/shared/rollback.log")" '"health":"ok"' 'health check journalisé'
assert_contains "$(cat "$CASE_ROOT/shared/rollback.log")" '"result":"success"' 'résultat journalisé'

# Aucune modification de .env ni du stockage.
env_hash_before="$(sha256sum "$CASE_ROOT/shared/.env" | awk '{print $1}')"
storage_hash_before="$(find "$CASE_ROOT/shared/storage" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')"

setup_case 'nominal-production' production
output="$(run_rollback production "$TARGET_ID")"
status=$?

assert_status 0 "$status" 'rollback nominal production'
assert_status "$TARGET_ID" "$(current_id)" 'current production pointe vers la cible'

# ---------------------------------------------------------------------------
# 2. Refus fail-closed
# ---------------------------------------------------------------------------

setup_case 'refus-release-inexistante' staging
output="$(run_rollback staging 'v9.9.9-9-9')"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'introuvable' 'release inexistante refusée'
else
  fail 'une release inexistante doit être refusée.'
fi

assert_status "$SOURCE_ID" "$(current_id)" 'current inchangé après refus'
assert_contains "$(cat "$CASE_ROOT/shared/rollback.log" 2>/dev/null)" '"result":"refused"' 'refus journalisé'

setup_case 'refus-hors-racine' staging
output="$(run_rollback staging '../evil')"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'identifiant de release invalide' 'release hors racine refusée'
else
  fail 'une release hors racine doit être refusée.'
fi

setup_case 'refus-incomplete' staging
rm -f "$CASE_ROOT/releases/$TARGET_ID/bootstrap/cache/config.php"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'incomplète' 'release incomplète refusée'
else
  fail 'une release incomplète doit être refusée.'
fi

setup_case 'refus-current-invalide' staging
rm -f "$CASE_ROOT/current"
mkdir "$CASE_ROOT/current"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'lien current' 'current invalide refusé'
else
  fail 'un current invalide doit être refusé.'
fi

setup_case 'refus-cible-active' staging
output="$(run_rollback staging "$SOURCE_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'déjà active' 'cible déjà active refusée'
else
  fail 'une cible déjà active doit être refusée.'
fi

setup_case 'refus-from-different' staging
output="$(run_rollback staging "$TARGET_ID" --from 'v0.0.1-1-1')"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'ne correspond pas à --from' 'from incohérent refusé'
else
  fail 'un --from incohérent doit être refusé.'
fi

setup_case 'refus-release-symbolique' staging
ln -s "$CASE_ROOT/releases/$SOURCE_ID" "$CASE_ROOT/releases/v0.3.0-3-1"
output="$(run_rollback staging 'v0.3.0-3-1')"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'symbolique' 'release symbolique refusée'
else
  fail 'une release symbolique doit être refusée.'
fi

setup_case 'refus-force' staging
output="$(run_rollback staging "$TARGET_ID" --force)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'option inconnue' 'argument --force refusé'
else
  fail '--force doit être refusé.'
fi

# ---------------------------------------------------------------------------
# 3. Attestation de compatibilité
# ---------------------------------------------------------------------------

attestation_refusal() {
  local name="$1"
  local expected="$2"
  local migrations="$3"
  local checked_at="${4:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}"
  local environment="${5:-staging}"
  local database="${6:-chantier_staging}"

  setup_case "$name" staging
  write_attestation "$ATTESTATION" "$environment" "$SOURCE_ID" "$TARGET_ID" "$database" "$checked_at" "$migrations"
  local output
  output="$(run_rollback staging "$TARGET_ID")"
  local status=$?

  if ((status != 0)); then
    pass
    assert_contains "$output" "$expected" "$name refusé"
  else
    fail "$name doit être refusé."
  fi

  assert_status "$SOURCE_ID" "$(current_id)" "$name : current inchangé"
}

attestation_refusal 'refus-migration-en-cours' 'in_progress doit être false' \
  '{"in_progress":true,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}'

attestation_refusal 'refus-migration-en-attente' 'pending doit être false' \
  '{"in_progress":false,"pending":true,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}'

attestation_refusal 'refus-migration-partielle' 'partial doit être false' \
  '{"in_progress":false,"pending":false,"partial":true,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}'

attestation_refusal 'refus-contract' 'contract_applied doit être false' \
  '{"in_progress":false,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":true,"compatible_with_target":true}'

attestation_refusal 'refus-incompatible' 'compatible_with_target doit être true' \
  '{"in_progress":false,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":false}'

attestation_refusal 'refus-attestation-perimee' 'durée de validité' \
  '{"in_progress":false,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}' \
  '2020-01-01T00:00:00Z'

attestation_refusal 'refus-attestation-environnement' 'environment ne correspond pas' \
  '{"in_progress":false,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}' \
  "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" production chantier_staging

attestation_refusal 'refus-attestation-database' 'database ne correspond pas' \
  '{"in_progress":false,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}' \
  "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" staging chantier_production

setup_case 'refus-attestation-absente' staging
rm -f "$ATTESTATION"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'attestation' 'attestation absente refusée'
else
  fail 'une attestation absente doit être refusée.'
fi

# Preuve migrate:status : modification, absence et incohérence de périmètre.
setup_case 'refus-preuve-modifiee' staging
printf 'ligne ajoutée après attestation\n' >>"$ATTESTATION.migrate-status.txt"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'ne correspond pas à la preuve conservée' 'preuve modifiée refusée'
else
  fail 'une preuve modifiée doit invalider l attestation.'
fi

setup_case 'refus-preuve-absente' staging
rm -f "$ATTESTATION.migrate-status.txt"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'Preuve migrate:status absente' 'preuve absente refusée'
else
  fail 'une preuve absente doit invalider l attestation.'
fi

setup_case 'refus-preuve-environnement' staging
proof="$ATTESTATION.migrate-status.txt"
sed -i 's/^environment: staging$/environment: production/' "$proof"
php -r '
    $attestation = $argv[1];
    $proof = $argv[2];
    $data = json_decode(file_get_contents($attestation), true);
    $data["migrate_status_sha256"] = hash_file("sha256", $proof);
    file_put_contents($attestation, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
' "$ATTESTATION" "$proof"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'environnement incohérent' 'preuve d un autre environnement refusée'
else
  fail 'une preuve d un autre environnement doit être refusée.'
fi

setup_case 'refus-preuve-release' staging
proof="$ATTESTATION.migrate-status.txt"
sed -i "s/^release: $SOURCE_ID$/release: v9.9.9-9-9/" "$proof"
php -r '
    $attestation = $argv[1];
    $proof = $argv[2];
    $data = json_decode(file_get_contents($attestation), true);
    $data["migrate_status_sha256"] = hash_file("sha256", $proof);
    file_put_contents($attestation, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
' "$ATTESTATION" "$proof"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'release incohérente' 'preuve d une autre release refusée'
else
  fail 'une preuve d une autre release doit être refusée.'
fi

# ---------------------------------------------------------------------------
# 4. Workers, files et concurrence
# ---------------------------------------------------------------------------

confirmation_refusal() {
  local name="$1"
  local expected="$2"
  shift 2

  setup_case "$name" staging
  local args=()
  while IFS= read -r line; do
    args+=("$line")
  done < <(rollback_args staging "$TARGET_ID")

  local filtered=()
  local arg

  for arg in "${args[@]}"; do
    local drop=0

    for excluded in "$@"; do
      if [[ "$arg" == "$excluded" ]]; then
        drop=1
      fi
    done

    ((drop == 1)) || filtered+=("$arg")
  done

  local output
  output="$(rollback "${filtered[@]}")"
  local status=$?

  if ((status != 0)); then
    pass
    assert_contains "$output" "$expected" "$name refusé"
  else
    fail "$name doit être refusé."
  fi

  assert_status "$SOURCE_ID" "$(current_id)" "$name : current inchangé"
}

confirmation_refusal 'refus-workers' 'workers non confirmés' '--confirm-workers-stopped'
confirmation_refusal 'refus-files' 'files non confirmées' '--confirm-queues-paused'
confirmation_refusal 'refus-jobs' 'jobs non confirmés' '--confirm-jobs-triaged'

setup_case 'refus-concurrence' staging
mkdir "$CASE_ROOT/shared/.release-operation.lock"
printf '%s\n' "$$" >"$CASE_ROOT/shared/.release-operation.lock/pid"
printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$CASE_ROOT/shared/.release-operation.lock/started_at"
printf 'test-host\n' >"$CASE_ROOT/shared/.release-operation.lock/host"
printf 'deploy\n' >"$CASE_ROOT/shared/.release-operation.lock/operation"
printf 'jeton-detenu-ailleurs\n' >"$CASE_ROOT/shared/.release-operation.lock/token"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'déjà en cours' 'opération concurrente refusée'
else
  fail 'une opération concurrente doit être refusée.'
fi

if [[ -f "$CASE_ROOT/shared/.release-operation.lock/token" && "$(cat "$CASE_ROOT/shared/.release-operation.lock/token")" == 'jeton-detenu-ailleurs' ]]; then
  pass
else
  fail 'le verrou d un autre processus a été modifié ou supprimé.'
fi

rm -rf "$CASE_ROOT/shared/.release-operation.lock"

# Verrou partagé : un verrou de déploiement bloque le rollback et n'est pas
# supprimé par le refus.
setup_case 'refus-lock-deploiement' staging
mkdir "$CASE_ROOT/shared/.release-operation.lock"
printf '%s\n' "$$" >"$CASE_ROOT/shared/.release-operation.lock/pid"
printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$CASE_ROOT/shared/.release-operation.lock/started_at"
printf 'test-host\n' >"$CASE_ROOT/shared/.release-operation.lock/host"
printf 'deploy\n' >"$CASE_ROOT/shared/.release-operation.lock/operation"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'déjà en cours' 'verrou de déploiement bloque le rollback'
else
  fail 'un verrou de déploiement doit bloquer le rollback.'
fi

if [[ -d "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'un verrou de déploiement a été supprimé par le rollback.'
fi

rm -rf "$CASE_ROOT/shared/.release-operation.lock"

# Verrou partagé : le déploiement refuse un verrou détenu par le rollback.
setup_case 'deploiement-bloque-par-rollback' staging
mkdir "$CASE_ROOT/shared/.release-operation.lock"
printf '%s\n' "$$" >"$CASE_ROOT/shared/.release-operation.lock/pid"
printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$CASE_ROOT/shared/.release-operation.lock/started_at"
printf 'test-host\n' >"$CASE_ROOT/shared/.release-operation.lock/host"
printf 'rollback\n' >"$CASE_ROOT/shared/.release-operation.lock/operation"
deploy_output="$(
  (
    source "$project_root/.github/scripts/deploy/remote-deploy.sh"
    shared="$CASE_ROOT/shared"
    current_host="test-host"
    acquire_operation_lock
  ) 2>&1
)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$deploy_output" 'concurrente en cours' 'rollback bloque le déploiement'
else
  fail 'un verrou de rollback doit bloquer le déploiement.'
fi

if [[ -d "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'le verrou de rollback a été supprimé par le déploiement.'
fi

rm -rf "$CASE_ROOT/shared/.release-operation.lock"

# Un déploiement qui détient le verrou le libère sur signal.
setup_case 'deploiement-verrou-signal' staging
(
  source "$project_root/.github/scripts/deploy/remote-deploy.sh"
  shared="$CASE_ROOT/shared"
  resolve_host_identity
  install_traps
  acquire_operation_lock
  printf 'ready\n' >"$CASE_DIR/deploy-lock-ready"
  sleep 30
) >"$CASE_DIR/deploy-lock.out" 2>&1 &
deploy_pid=$!

for attempt in $(seq 1 150); do
  [[ -f "$CASE_DIR/deploy-lock-ready" ]] && break
  sleep 0.1
done

if [[ -f "$CASE_DIR/deploy-lock-ready" && -d "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  live_host="$(hostname -s 2>/dev/null || hostname)"
  output="$(C2ME_HOST_ID="$live_host" run_rollback staging "$TARGET_ID")"
  status=$?

  if ((status != 0)); then
    pass
    assert_contains "$output" 'déjà en cours' 'déploiement actif bloque le rollback'
  else
    fail 'un déploiement actif doit bloquer le rollback.'
  fi
else
  fail 'le déploiement simulé n a pas pris le verrou.'
fi

kill -TERM "$deploy_pid" 2>/dev/null
wait "$deploy_pid" 2>/dev/null
status=$?

assert_status 143 "$status" 'déploiement interrompu : code 143'

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'le verrou du déploiement n a pas été libéré après le signal.'
fi

# Un échec du déploiement libère le verrou.
setup_case 'deploiement-echec-libere' staging
(
  source "$project_root/.github/scripts/deploy/remote-deploy.sh"
  shared="$CASE_ROOT/shared"
  resolve_host_identity
  install_traps
  acquire_operation_lock
  die 'échec simulé du déploiement'
) >"$CASE_DIR/deploy-failure.out" 2>&1 || true

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'un déploiement en échec n a pas libéré le verrou.'
fi

# Deux rollbacks concurrents ne basculent jamais current simultanément.
setup_case 'rollback-concurrent' staging
curl_pid_file="$work_dir/concurrent-curl.pid"
curl_stop_file="$work_dir/concurrent-curl.stop"
rm -f "$curl_pid_file" "$curl_stop_file"

FAKE_CURL_SLEEP=30 FAKE_CURL_PID="$curl_pid_file" FAKE_CURL_STOP="$curl_stop_file" \
  bash "$ops_dir/rollback.sh" --env staging --to "$TARGET_ID" \
  --reason 'premier rollback concurrent' --schema-attestation "$ATTESTATION" \
  --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged \
  >"$CASE_DIR/first-rollback.log" 2>&1 &
first_pid=$!

for attempt in $(seq 1 150); do
  [[ -s "$curl_pid_file" ]] && break
  sleep 0.1
done

if [[ -s "$curl_pid_file" ]]; then
  second_attestation="$CASE_DIR/attestation-second.json"
  write_attestation "$second_attestation" staging "$TARGET_ID" "$SOURCE_ID" 'chantier_staging' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    '{"in_progress":false,"pending":false,"partial":false,"destructive_applied":false,"contract_applied":false,"compatible_with_target":true}'

  second_output="$(run_rollback staging "$SOURCE_ID" --schema-attestation "$second_attestation")"
  second_status=$?

  if ((second_status != 0)); then
    pass
    assert_contains "$second_output" 'déjà en cours' 'second rollback concurrent refusé'
  else
    fail "un second rollback concurrent doit être refusé. Sortie : $second_output"
  fi

  kill -TERM "$first_pid" 2>/dev/null
  wait "$first_pid" 2>/dev/null
  first_status=$?

  assert_status 143 "$first_status" 'premier rollback interrompu proprement'
  assert_status "$TARGET_ID" "$(current_id)" 'une seule bascule de current malgré la concurrence'
else
  fail 'le premier rollback ne s est pas bloqué pour le test de concurrence.'
  kill -KILL "$first_pid" 2>/dev/null || true
  wait "$first_pid" 2>/dev/null || true
fi

# Libération sûre : un jeton remplacé, absent ou illisible interdit toute
# suppression du verrou par le processus initial.
for token_case in remplace absent repertoire; do
  setup_case "verrou-token-$token_case" staging
  lock_dir="$CASE_ROOT/shared/.release-operation.lock"

  if start_blocked_rollback "token-$token_case"; then
    case "$token_case" in
      remplace)
        printf 'jeton-remplace-par-un-autre-processus\n' >"$lock_dir/token"
        ;;
      absent)
        rm -f "$lock_dir/token"
        ;;
      repertoire)
        rm -f "$lock_dir/token"
        mkdir "$lock_dir/token"
        ;;
    esac

    stop_blocked_rollback
    token_status=$?
    assert_status 143 "$token_status" "verrou $token_case : interruption propre"

    if [[ -d "$lock_dir" ]]; then
      pass
    else
      fail "verrou $token_case : le verrou a été supprimé malgré un jeton non détenu."
    fi

    case "$token_case" in
      remplace)
        if [[ -f "$lock_dir/token" && "$(cat "$lock_dir/token")" == 'jeton-remplace-par-un-autre-processus' ]]; then
          pass
        else
          fail 'verrou remplacé : le jeton étranger a été modifié ou supprimé.'
        fi
        ;;
      absent)
        if [[ ! -e "$lock_dir/token" ]]; then
          pass
        else
          fail 'verrou sans jeton : un jeton a été recréé ou le verrou modifié.'
        fi
        ;;
      repertoire)
        if [[ -d "$lock_dir/token" ]]; then
          pass
        else
          fail 'verrou avec jeton non régulier : le chemin du jeton a été modifié.'
        fi
        ;;
    esac

    rm -rf "$lock_dir"
  else
    fail "verrou $token_case : le rollback bloqué n a pas démarré."
    kill -KILL "$BLOCKED_PID" 2>/dev/null || true
    wait "$BLOCKED_PID" 2>/dev/null || true
  fi
done

# Récupération explicite du verrou orphelin : confirmation obligatoire,
# refus d'un verrou actif, libération contrôlée d'un verrou mort.
setup_case 'unlock-orphelin' staging
sleep 0.1 &
dead_pid=$!
wait "$dead_pid" 2>/dev/null || true
mkdir "$CASE_ROOT/shared/.release-operation.lock"
printf '%s\n' "$dead_pid" >"$CASE_ROOT/shared/.release-operation.lock/pid"
printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$CASE_ROOT/shared/.release-operation.lock/started_at"
printf 'test-host\n' >"$CASE_ROOT/shared/.release-operation.lock/host"
printf 'deploy\n' >"$CASE_ROOT/shared/.release-operation.lock/operation"
printf 'jeton-etranger\n' >"$CASE_ROOT/shared/.release-operation.lock/token"

output="$(bash "$ops_dir/rollback.sh" unlock --env staging 2>&1)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'confirm-stale-lock' 'unlock sans confirmation refusé'
else
  fail 'unlock sans --confirm-stale-lock doit être refusé.'
fi

if [[ -d "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'unlock sans confirmation a supprimé le verrou.'
fi

output="$(bash "$ops_dir/rollback.sh" unlock --env staging --confirm-stale-lock 2>&1)"
status=$?

if ((status == 0)) && [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
  assert_contains "$output" 'UNLOCK=ok' 'unlock orphelin confirmé'
else
  fail "unlock confirmé doit libérer le verrou orphelin. Sortie : $output"
fi

setup_case 'unlock-actif' staging
mkdir "$CASE_ROOT/shared/.release-operation.lock"
printf '%s\n' "$$" >"$CASE_ROOT/shared/.release-operation.lock/pid"
printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$CASE_ROOT/shared/.release-operation.lock/started_at"
printf 'test-host\n' >"$CASE_ROOT/shared/.release-operation.lock/host"
printf 'rollback\n' >"$CASE_ROOT/shared/.release-operation.lock/operation"
printf 'jeton-actif\n' >"$CASE_ROOT/shared/.release-operation.lock/token"
output="$(bash "$ops_dir/rollback.sh" unlock --env staging --confirm-stale-lock 2>&1)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'actif' 'unlock refuse un verrou actif'
else
  fail 'unlock ne doit pas libérer un verrou actif.'
fi

if [[ -d "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'unlock a supprimé un verrou actif.'
fi

rm -rf "$CASE_ROOT/shared/.release-operation.lock"

# Le message du déploiement doit indiquer la commande réellement disponible.
setup_case 'deploiement-message-unlock' staging
sleep 0.1 &
dead_pid=$!
wait "$dead_pid" 2>/dev/null || true
live_host="$(hostname -s 2>/dev/null || hostname)"
mkdir "$CASE_ROOT/shared/.release-operation.lock"
printf '%s\n' "$dead_pid" >"$CASE_ROOT/shared/.release-operation.lock/pid"
printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$CASE_ROOT/shared/.release-operation.lock/started_at"
printf '%s\n' "$live_host" >"$CASE_ROOT/shared/.release-operation.lock/host"
printf 'rollback\n' >"$CASE_ROOT/shared/.release-operation.lock/operation"
printf 'jeton-orphan\n' >"$CASE_ROOT/shared/.release-operation.lock/token"
deploy_output="$(
  (
    source "$project_root/.github/scripts/deploy/remote-deploy.sh"
    shared="$CASE_ROOT/shared"
    environment="staging"
    current_host="$live_host"
    acquire_operation_lock
  ) 2>&1
)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$deploy_output" "scripts/ops/rollback.sh unlock --env staging --confirm-stale-lock" 'message de déploiement avec commande unlock réelle'
else
  fail 'le déploiement doit refuser un verrou orphelin.'
fi

if [[ -d "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'le déploiement a supprimé un verrou orphelin.'
fi

rm -rf "$CASE_ROOT/shared/.release-operation.lock"

# Verrou remplacé par un autre répertoire : inode différent, aucune suppression.
setup_case 'verrou-remplace-repertoire' staging
lock_dir="$CASE_ROOT/shared/.release-operation.lock"
if start_blocked_rollback 'replace-dir'; then
  mv "$lock_dir" "$lock_dir.original"
  mkdir "$lock_dir"
  printf '%s\n' "$$" >"$lock_dir/pid"
  printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$lock_dir/started_at"
  printf '%s\n' "$(hostname -s 2>/dev/null || hostname)" >"$lock_dir/host"
  printf 'rollback\n' >"$lock_dir/operation"
  printf 'jeton-nouveau-verrou\n' >"$lock_dir/token"

  stop_blocked_rollback
  token_status=$?
  assert_status 143 "$token_status" 'verrou remplacé : interruption propre'

  if [[ -d "$lock_dir" && "$(cat "$lock_dir/token" 2>/dev/null || true)" == 'jeton-nouveau-verrou' ]]; then
    pass
  else
    fail 'le verrou de remplacement a été supprimé ou modifié.'
  fi

  rm -rf "$lock_dir" "$lock_dir.original"
else
  fail 'le rollback bloqué n a pas démarré pour le remplacement de répertoire.'
  kill -KILL "$BLOCKED_PID" 2>/dev/null || true
  wait "$BLOCKED_PID" 2>/dev/null || true
fi

# Verrou remplacé par un lien symbolique : aucune suppression.
setup_case 'verrou-symbolique' staging
lock_dir="$CASE_ROOT/shared/.release-operation.lock"
if start_blocked_rollback 'replace-symlink'; then
  mv "$lock_dir" "$lock_dir.original"
  mkdir "$CASE_ROOT/shared/autre-cible"
  ln -s "$CASE_ROOT/shared/autre-cible" "$lock_dir"

  stop_blocked_rollback
  token_status=$?
  assert_status 143 "$token_status" 'verrou symbolique : interruption propre'

  if [[ -L "$lock_dir" ]]; then
    pass
  else
    fail 'le lien symbolique du verrou a été supprimé ou remplacé.'
  fi

  rm -rf "$lock_dir" "$lock_dir.original" "$CASE_ROOT/shared/autre-cible"
else
  fail 'le rollback bloqué n a pas démarré pour le verrou symbolique.'
  kill -KILL "$BLOCKED_PID" 2>/dev/null || true
  wait "$BLOCKED_PID" 2>/dev/null || true
fi

# Garde flock : une opération concurrente ne peut pas entrer dans la section
# critique tant que le garde est détenu.
if command -v flock >/dev/null 2>&1; then
  setup_case 'garde-verrou' staging
  guard="$CASE_ROOT/shared/.release-operation.lock.guard"
  mkdir "$guard"
  flock -x "$guard" -c 'sleep 3' &
  guard_holder=$!
  sleep 0.3

  output="$(C2ME_LOCK_GUARD_TIMEOUT=1 run_rollback staging "$TARGET_ID")"
  status=$?

  if ((status != 0)); then
    pass
    assert_contains "$output" 'garde de verrou indisponible' 'garde flock bloque l acquisition'
  else
    fail 'un garde détenu doit empêcher le rollback.'
  fi

  assert_status "$SOURCE_ID" "$(current_id)" 'garde détenu : current inchangé'
  wait "$guard_holder" 2>/dev/null || true
else
  skip 'flock indisponible : test du garde non exécuté.'
fi

# Écriture de métadonnées en échec : la fonction réelle doit échouer et ne
# jamais masquer l'erreur.
setup_case 'ecriture-metadonnees' staging
metadata_dir="$CASE_DIR/metadata-lock"
mkdir "$metadata_dir"
mkdir "$metadata_dir/token"
if (
  source "$ops_dir/lib/common.sh"
  c2me_lock_write_metadata "$metadata_dir" 'jeton-test' '123' 'test-host' '2026-11-14T00:00:00Z'
) 2>/dev/null; then
  fail 'l écriture de métadonnées doit échouer si le jeton est un répertoire.'
else
  pass
fi

# Garde non régulier : acquisition refusée avant toute écriture.
setup_case 'garde-non-regulier' staging
: >"$CASE_ROOT/shared/.release-operation.lock.guard"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'fichier de garde non régulier' 'garde non régulier refusé'
else
  fail 'un garde non régulier doit empêcher le rollback.'
fi

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'un verrou a été créé malgré un garde invalide.'
fi

rm -rf "$CASE_ROOT/shared/.release-operation.lock.guard"

# .guard symbolique : refus avant toute ouverture.
setup_case 'garde-symbolique' staging
ln -s "$CASE_ROOT/shared" "$CASE_ROOT/shared/.release-operation.lock.guard"
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'garde symbolique' 'garde symbolique refusé'
else
  fail 'un garde symbolique doit empêcher le rollback.'
fi

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'un verrou a été créé malgré un garde symbolique.'
fi

rm -f "$CASE_ROOT/shared/.release-operation.lock.guard"

# Identité du descripteur : valide avant remplacement, refusée après.
setup_case 'garde-identite-descripteur' staging
guard_dir="$CASE_ROOT/shared/.release-operation.lock.guard"
mkdir "$guard_dir"

if (
  source "$ops_dir/lib/common.sh"
  exec {guard_fd}<"$guard_dir"
  c2me_guard_validate_fd "$guard_dir" "$guard_fd" || exit 1
  mv "$guard_dir" "$guard_dir.old"
  mkdir "$guard_dir"
  if c2me_guard_validate_fd "$guard_dir" "$guard_fd"; then
    exit 1
  fi
  exit 0
) 2>/dev/null; then
  pass
else
  fail 'la validation du descripteur de garde doit détecter un remplacement.'
fi

rm -rf "$guard_dir" "$guard_dir.old"

# flock absent : refus en mode production, tolérance uniquement en mode de test
# explicitement autorisé.
setup_case 'flock-absent-production' staging
flock_output="$(
  (
    source "$ops_dir/lib/common.sh"
    C2ME_FLOCK_BIN="$CASE_DIR/flock-absent"
    c2me_guard_enter "$CASE_DIR/lock-production"
  ) 2>&1
)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$flock_output" 'flock est requis' 'flock absent refusé en production'
else
  fail 'flock absent doit être refusé hors mode de test.'
fi

if [[ ! -e "$CASE_DIR/lock-production.guard" ]]; then
  pass
else
  fail 'un garde a été créé malgré l absence de flock.'
fi

status=0
(
  source "$ops_dir/lib/common.sh"
  C2ME_FLOCK_BIN="$CASE_DIR/flock-absent"
  C2ME_ALLOW_MISSING_FLOCK=1
  c2me_guard_enter "$CASE_DIR/lock-test"
) >/dev/null 2>&1 || status=$?

if ((status == 0)); then
  pass
else
  fail 'le mode de test explicite doit tolérer flock absent.'
fi

# Interruption pendant l'attente du garde à l'acquisition : aucun verrou ne
# doit rester.
setup_case 'interruption-acquisition' staging
guard="$CASE_ROOT/shared/.release-operation.lock.guard"
mkdir "$guard"
flock -x "$guard" -c 'sleep 5' &
guard_holder=$!
sleep 0.3

C2ME_LOCK_GUARD_TIMEOUT=10 bash "$ops_dir/rollback.sh" --env staging --to "$TARGET_ID" \
  --reason 'interruption acquisition' --schema-attestation "$ATTESTATION" \
  --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged \
  >"$CASE_DIR/interruption-acquisition.log" 2>&1 &
acquisition_pid=$!
sleep 0.5

kill -TERM "$acquisition_pid" 2>/dev/null
wait "$acquisition_pid" 2>/dev/null
status=$?

assert_status 143 "$status" 'interruption pendant acquisition : code 143'

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'un verrou subsiste après interruption pendant l acquisition.'
fi

assert_status "$SOURCE_ID" "$(current_id)" 'interruption acquisition : current inchangé'
kill -TERM "$guard_holder" 2>/dev/null
wait "$guard_holder" 2>/dev/null || true

# Mode dry-run : sortie exacte et aucun état modifié.
setup_case 'dry-run' staging
dry_link_before="$(readlink -f "$CASE_ROOT/current")"
dry_output="$(run_rollback staging "$TARGET_ID" --dry-run)"
dry_status=$?
dry_expected="PLAN=ok
MODE=dry-run
ENVIRONMENT=staging
SOURCE=$SOURCE_ID
TARGET=$TARGET_ID
CURRENT_BEFORE=$CASE_ROOT/releases/$SOURCE_ID
VALIDATION=ok
Aucune modification effectuée (--dry-run)."

assert_status 0 "$dry_status" 'dry-run réussi'
assert_status "$dry_expected" "$dry_output" 'sortie dry-run exacte'
assert_status "$dry_link_before" "$(readlink -f "$CASE_ROOT/current")" 'dry-run : current inchangé'

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'dry-run a créé un verrou.'
fi

if [[ ! -e "$CASE_ROOT/shared/rollback.log" ]]; then
  pass
else
  fail 'dry-run a créé ou modifié le journal.'
fi

setup_case 'refus-deploiement-en-cours' staging
mkdir "$CASE_ROOT/releases/.incoming-test"
output="$(run_rollback staging "$TARGET_ID")"
status=$?
rmdir "$CASE_ROOT/releases/.incoming-test"

if ((status != 0)); then
  pass
  assert_contains "$output" 'déploiement en cours' 'déploiement concurrent refusé'
else
  fail 'un déploiement en cours doit être refusé.'
fi

setup_case 'refus-supervisor-actif' staging
printf 'RUNNING\n' >"$work_dir/supervisor-status"
cat >"$fake_bin/supervisorctl" <<FAKE
#!/usr/bin/env bash
cat "$work_dir/supervisor-status"
FAKE
chmod +x "$fake_bin/supervisorctl"
output="$(C2ME_SUPERVISOR_PROGRAM='chantier-workers' C2ME_SUPERVISORCTL_BIN="$fake_bin/supervisorctl" run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'encore actif' 'worker Supervisor actif refusé'
else
  fail 'un worker Supervisor actif doit être refusé.'
fi

# ---------------------------------------------------------------------------
# 5. Health check
# ---------------------------------------------------------------------------

setup_case 'health-echec' staging
output="$(FAKE_CURL_RESULT=fail run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'health check en échec' 'échec du health check signalé'
else
  fail 'un health check en échec doit faire échouer le rollback.'
fi

assert_status "$TARGET_ID" "$(current_id)" 'current reste sur la cible après échec du health check (aucun retour automatique)'
assert_contains "$(cat "$CASE_ROOT/shared/rollback.log")" '"result":"failed"' 'échec journalisé'
assert_contains "$output" 'Retour manuel possible' 'procédure de retour manuel indiquée'

if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
  pass
else
  fail 'le verrou subsiste après un échec de health check.'
fi

setup_case 'health-invalide' staging
output="$(FAKE_CURL_RESULT=invalid run_rollback staging "$TARGET_ID")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'incohérent' 'réponse de health check incohérente refusée'
else
  fail 'une réponse de health check incohérente doit faire échouer le rollback.'
fi

# ---------------------------------------------------------------------------
# 6. Interruption SIGTERM
# ---------------------------------------------------------------------------

setup_case 'interruption' staging
curl_pid_file="$work_dir/curl.pid"
curl_stop_file="$work_dir/curl.stop"
rm -f "$curl_pid_file" "$curl_stop_file"

FAKE_CURL_SLEEP=30 FAKE_CURL_PID="$curl_pid_file" FAKE_CURL_STOP="$curl_stop_file" \
  bash "$ops_dir/rollback.sh" --env staging --to "$TARGET_ID" \
  --reason 'test interruption' --schema-attestation "$ATTESTATION" \
  --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged \
  >"$work_dir/interruption.log" 2>&1 &
main_pid=$!

for attempt in $(seq 1 150); do
  [[ -s "$curl_pid_file" ]] && break
  sleep 0.1
done

if [[ -s "$curl_pid_file" ]]; then
  curl_pid="$(cat "$curl_pid_file")"
  kill -TERM "$main_pid" 2>/dev/null
  wait "$main_pid" 2>/dev/null
  status=$?

  assert_status 143 "$status" 'code de sortie sur SIGTERM'

  if kill -0 "$curl_pid" 2>/dev/null; then
    fail 'le processus enfant du health check est encore vivant.'
  else
    pass
  fi

  if [[ -f "$curl_stop_file" ]]; then
    pass
  else
    fail 'le processus enfant n a pas reçu le signal.'
  fi

  if [[ ! -e "$CASE_ROOT/shared/.release-operation.lock" ]]; then
    pass
  else
    fail 'le verrou subsiste après interruption.'
  fi

  assert_status "$TARGET_ID" "$(current_id)" 'current est la cible après interruption post-bascule'
  assert_contains "$(cat "$CASE_ROOT/shared/rollback.log")" '"event":"interrupted"' 'interruption journalisée'
else
  fail 'le health check simulé ne s est pas bloqué.'
  kill -KILL "$main_pid" 2>/dev/null || true
  wait "$main_pid" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 7. Intégrité du journal
# ---------------------------------------------------------------------------

setup_case 'journal' staging
output="$(run_rollback staging "$TARGET_ID")"
status=$?

if ((status == 0)); then
  pass
else
  fail 'le rollback du test de journal doit réussir.'
fi

journal="$CASE_ROOT/shared/rollback.log"
journal_ok="$(php -r '
    $lines = file($argv[1], FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    $required = ["timestamp","event","operation_id","environment","operator","host","source_release","target_release","source_commit","target_commit","reason","schema_attestation_sha256","current_before","current_after","health","workers","queues","jobs","result","error"];
    if (count($lines) < 2) { fwrite(STDERR, "journal trop court\n"); exit(1); }
    $events = [];
    foreach ($lines as $line) {
        $row = json_decode($line, true);
        if (!is_array($row)) { fwrite(STDERR, "JSON invalide\n"); exit(1); }
        foreach ($required as $key) {
            if (!array_key_exists($key, $row)) { fwrite(STDERR, "champ absent: $key\n"); exit(1); }
        }
        $events[] = $row["event"];
    }
    if ($events !== ["started", "completed"]) { fwrite(STDERR, "séquence inattendue\n"); exit(1); }
    exit(0);
' "$journal" 2>&1)"
status=$?

assert_status 0 "$status" "journal JSONL intègre ($journal_ok)"

# ---------------------------------------------------------------------------
# 8. Atomicité de current (Linux uniquement)
# ---------------------------------------------------------------------------

if [[ "$(uname -s)" == 'Linux' ]]; then
  atomic_dir="$work_dir/atomicite"
  mkdir -p "$atomic_dir/releases/a" "$atomic_dir/releases/b"
  : >"$atomic_dir/releases/a/marker"
  : >"$atomic_dir/releases/b/marker"
  ln -s "$atomic_dir/releases/a" "$atomic_dir/current"

  (
    for attempt in $(seq 1 5000); do
      if [[ ! -L "$atomic_dir/current" || ! -d "$atomic_dir/current" ]]; then
        printf 'rupture\n' >>"$atomic_dir/failures"
        break
      fi
    done
  ) &
  reader_pid=$!

  for attempt in $(seq 1 20); do
    ln -sfn "$atomic_dir/releases/b" "$atomic_dir/.tmp"
    mv -Tf "$atomic_dir/.tmp" "$atomic_dir/current"
    ln -sfn "$atomic_dir/releases/a" "$atomic_dir/.tmp"
    mv -Tf "$atomic_dir/.tmp" "$atomic_dir/current"
  done

  wait "$reader_pid" 2>/dev/null || true

  if [[ -f "$atomic_dir/failures" ]]; then
    fail 'current a été observé absent ou invalide pendant les bascules atomiques.'
  else
    pass
  fi
else
  skip 'test d atomicité réservé à Linux.'
fi

# ---------------------------------------------------------------------------
# Bilan
# ---------------------------------------------------------------------------

printf '\n%d test(s) réussi(s), %d échec(s), %d ignoré(s).\n' "$passed" "$failed" "$skipped"

if ((failed > 0)); then
  exit 1
fi

exit 0
