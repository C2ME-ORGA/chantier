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

  cat >"$file" <<JSON
{
  "schema_version": 1,
  "environment": "$environment",
  "source_release": "$source",
  "target_release": "$target",
  "database": "$database",
  "checked_at": "$checked_at",
  "checked_by": "test-operator",
  "migrate_status_sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "migrations": $migrations
}
JSON
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
mkdir "$CASE_ROOT/shared/.rollback.lock"
printf '%s\n' "$$" >"$CASE_ROOT/shared/.rollback.lock/pid"
printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$CASE_ROOT/shared/.rollback.lock/started_at"
printf 'test-host\n' >"$CASE_ROOT/shared/.rollback.lock/host"
output="$(run_rollback staging "$TARGET_ID")"
status=$?
rm -rf "$CASE_ROOT/shared/.rollback.lock"

if ((status != 0)); then
  pass
  assert_contains "$output" 'déjà en cours' 'opération concurrente refusée'
else
  fail 'une opération concurrente doit être refusée.'
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

  if [[ ! -e "$CASE_ROOT/shared/.rollback.lock" ]]; then
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
