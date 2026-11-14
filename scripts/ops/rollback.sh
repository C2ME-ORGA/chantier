#!/usr/bin/env bash
#
# Rollback applicatif C2ME Chantier — CHAN-98, lot 3.
#
# Réactive manuellement une release antérieure présente dans releases/ en
# basculant atomiquement le lien current. Le script ne touche jamais à la base
# de données, à shared/.env, à shared/storage, aux jobs, aux caches, au cron,
# à Supervisor ni à PHP-FPM.
#
# Aucun rollback n'est déclenché automatiquement par un déploiement ou par un
# échec de health check. L'opération est explicite, tracée et fail-closed.
#
# Voir docs/development/application-rollback.md et
# docs/development/application-rollback-runbook.md.

set -Eeuo pipefail

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$OPS_DIR/lib/common.sh"

ATTESTATION_TOOL="$OPS_DIR/lib/rollback-attestation.php"
ROLLBACK_LOCK_NAME='.release-operation.lock'
C2ME_REQUIRE_FLOCK=1
C2ME_CURL_BIN="${C2ME_CURL_BIN:-$(command -v curl || true)}"

environment=""
command="apply"
target_release=""
from_release=""
reason=""
attestation_file=""
max_attestation_age="${C2ME_ATTESTATION_MAX_AGE_SECONDS:-86400}"
confirm_workers=0
confirm_queues=0
confirm_jobs=0
confirm_stale_lock=0
dry_run=0

root=""
shared=""
releases_dir=""
releases_real=""
current_link=""
storage_framework=""
log_file=""
log_ready=0
operation_id=""
source_release=""
source_dir=""
target_dir=""
source_version=""
source_commit=""
target_version=""
target_commit=""
target_sha256=""
current_before=""
current_after=""
schema_attestation_sha256=""
health_status="not-run"
maintenance_state="inconnu"
switched=0
failure_status="refused"

usage() {
  cat <<'EOF'
Usage : rollback.sh --env <staging|production> --to <release-id> --reason <texte> \
          --schema-attestation <fichier> \
          --confirm-workers-stopped --confirm-queues-paused --confirm-jobs-triaged \
          [--from <release-id>] [--max-attestation-age <secondes>] [--dry-run]

       rollback.sh unlock --env <staging|production> --confirm-stale-lock

Réactive manuellement une release antérieure en basculant atomiquement
`current`. Aucune migration, aucune restauration de base, aucune modification
de `.env`, `shared/storage`, des jobs, du cron ou des services.

Options :
  --env                     Environnement cible (obligatoire)
  --to                      Release cible présente dans releases/ (obligatoire)
  --from                    Release source attendue ; refus si current diffère
  --reason                  Raison du rollback, 5 à 500 caractères (obligatoire)
  --schema-attestation      Attestation de compatibilité N/N-1 (obligatoire)
  --max-attestation-age     Validité de l attestation en secondes (défaut 86400)
  --confirm-workers-stopped Workers vérifiés arrêtés
  --confirm-queues-paused   Files vérifiées en pause
  --confirm-jobs-triaged    Jobs en attente traités ou conservés selon la procédure
  --dry-run                 Contrôles uniquement, aucune bascule
  --confirm-stale-lock      Libère explicitement un verrou orphelin (commande unlock)
  -h, --help                Affiche cette aide

Le script refuse toute cible hors de releases/, toute release incomplète,
tout schéma non attesté compatible, tout état de workers/files non confirmé,
toute opération concurrente et tout changement de `current` pendant les
contrôles. Aucun argument --force n'est accepté.
EOF
}

# ---------------------------------------------------------------------------
# Journal
# ---------------------------------------------------------------------------

rollback_log_event() {
  local event="$1"
  local result="$2"
  local error="${3:-}"

  if [[ "$log_ready" -ne 1 || -z "$log_file" ]]; then
    return 0
  fi

  if [[ -L "$log_file" ]]; then
    printf 'ERREUR: journal de rollback symbolique, écriture refusée : %s\n' "$log_file" >&2
    return 1
  fi

  (
    umask 027
    printf '{"timestamp":"%s","event":"%s","operation_id":"%s","environment":"%s","operator":"%s","host":"%s","source_release":"%s","target_release":"%s","source_version":"%s","target_version":"%s","source_commit":"%s","target_commit":"%s","target_sha256":"%s","reason":"%s","schema_attestation_sha256":"%s","current_before":"%s","current_after":"%s","health":"%s","workers":"%s","queues":"%s","jobs":"%s","maintenance":"%s","result":"%s","error":"%s","dry_run":%s}\n' \
      "$(c2me_iso_now)" \
      "$(c2me_json_escape "$event")" \
      "$(c2me_json_escape "$operation_id")" \
      "$(c2me_json_escape "$environment")" \
      "$(c2me_json_escape "${C2ME_OPERATOR:-inconnu}")" \
      "$(c2me_json_escape "${C2ME_HOST_ID:-inconnu}")" \
      "$(c2me_json_escape "$source_release")" \
      "$(c2me_json_escape "$target_release")" \
      "$(c2me_json_escape "$source_version")" \
      "$(c2me_json_escape "$target_version")" \
      "$(c2me_json_escape "$source_commit")" \
      "$(c2me_json_escape "$target_commit")" \
      "$(c2me_json_escape "$target_sha256")" \
      "$(c2me_json_escape "$reason")" \
      "$(c2me_json_escape "$schema_attestation_sha256")" \
      "$(c2me_json_escape "$current_before")" \
      "$(c2me_json_escape "$current_after")" \
      "$(c2me_json_escape "$health_status")" \
      "$( [[ "$confirm_workers" -eq 1 ]] && printf 'stopped-declared' || printf 'non-verifie' )" \
      "$( [[ "$confirm_queues" -eq 1 ]] && printf 'paused-declared' || printf 'non-verifie' )" \
      "$( [[ "$confirm_jobs" -eq 1 ]] && printf 'triaged-declared' || printf 'non-verifie' )" \
      "$(c2me_json_escape "$maintenance_state")" \
      "$(c2me_json_escape "$result")" \
      "$(c2me_json_escape "$error")" \
      "$(if [[ "$dry_run" -eq 1 ]]; then printf 'true'; else printf 'false'; fi)" \
      >>"$log_file"
  )
}

prepare_logging() {
  [[ -n "$shared" ]] || return 1
  [[ -d "$shared" && ! -L "$shared" ]] || c2me_die "répertoire shared invalide : $shared"
  [[ -w "$shared" ]] || c2me_die "répertoire shared non inscriptible : $shared"

  log_file="$shared/rollback.log"

  if [[ -L "$log_file" ]]; then
    c2me_die "journal de rollback symbolique interdit : $log_file"
  fi

  if [[ -e "$log_file" && ! -f "$log_file" ]]; then
    c2me_die "journal de rollback non régulier : $log_file"
  fi

  if [[ ! -e "$log_file" ]]; then
    (umask 027 && set -C && : >"$log_file") \
      || c2me_die "création du journal de rollback impossible : $log_file"
  fi

  [[ -w "$log_file" ]] || c2me_die "journal de rollback non inscriptible : $log_file"
  log_ready=1
}

# Toute erreur survenant après l'initialisation du journal produit une entrée
# « refused ». Une erreur avant l'initialisation ne peut pas être journalisée.
c2me_die() {
  local message="$*"

  if [[ "${log_ready:-0}" -eq 1 ]]; then
    rollback_log_event 'refused' "${failure_status:-refused}" "$message" || true
  fi

  c2me_log error "$message"
  exit 1
}

refuse() {
  local message="$1"

  failure_status='refused'
  rollback_log_event 'refused' 'refused' "$message" || true
  c2me_log error "$message"
  exit 1
}

fail_after_change() {
  local message="$1"

  failure_status='failed'
  rollback_log_event 'failed' 'failed' "$message" || true
  c2me_log error "$message"
  exit 1
}

# ---------------------------------------------------------------------------
# Signaux
# ---------------------------------------------------------------------------

rollback_on_signal() {
  local code="$1"
  local signal="$2"

  trap - EXIT HUP INT TERM
  health_status="${health_status:-interrompu}"
  rollback_log_event 'interrupted' 'interrupted' "signal $signal reçu" || true
  c2me_terminate_children
  exec </dev/null >/dev/null 2>&1
  c2me_cleanup
  exit "$code"
}

install_traps() {
  trap c2me_cleanup EXIT
  trap 'rollback_on_signal 129 HUP' HUP
  trap 'rollback_on_signal 130 INT' INT
  trap 'rollback_on_signal 143 TERM' TERM
}

mask_signals() {
  trap '' HUP INT TERM
}

unmask_signals() {
  trap 'rollback_on_signal 129 HUP' HUP
  trap 'rollback_on_signal 130 INT' INT
  trap 'rollback_on_signal 143 TERM' TERM
}

# ---------------------------------------------------------------------------
# Contrôles de racine, de release et de concurrence
# ---------------------------------------------------------------------------

assert_root_layout() {
  c2me_require_dir "$root" 'racine applicative'
  [[ ! -L "$root" ]] || c2me_die "racine applicative symbolique interdite : $root"

  c2me_require_dir "$C2ME_ROOT/shared" 'répertoire shared'
  c2me_require_dir "$C2ME_ROOT/releases" 'répertoire releases'

  shared="$C2ME_ROOT/shared"
  releases_dir="$C2ME_ROOT/releases"
  current_link="$C2ME_ROOT/current"
  storage_framework="$C2ME_STORAGE_ROOT/framework"

  [[ ! -L "$shared" ]] || c2me_die "répertoire shared symbolique interdit : $shared"
  [[ ! -L "$releases_dir" ]] || c2me_die "répertoire releases symbolique interdit : $releases_dir"
  [[ -d "$storage_framework" && ! -L "$storage_framework" ]] \
    || c2me_die "répertoire storage/framework introuvable ou invalide : $storage_framework"

  local owner current_user
  owner="$(stat -c '%U' "$root" 2>/dev/null || true)"
  current_user="$(id -un)"

  [[ "$owner" == "$current_user" ]] \
    || c2me_die "la racine $root appartient à $owner et non au compte technique $current_user."

  releases_real="$(c2me_realpath "$releases_dir")"
  [[ -n "$releases_real" ]] || c2me_die "résolution du répertoire releases impossible."
}

assert_no_incoming_release() {
  local incoming
  incoming="$(find "$releases_dir" -mindepth 1 -maxdepth 1 -type d -name '.incoming-*' -print -quit 2>/dev/null || true)"

  [[ -z "$incoming" ]] \
    || c2me_die "déploiement en cours détecté ($incoming) : rollback refusé."
}

assert_reason() {
  [[ ${#reason} -ge 5 && ${#reason} -le 500 ]] \
    || c2me_die 'la raison du rollback doit contenir entre 5 et 500 caractères.'
  [[ "$reason" != *$'\n'* && "$reason" != *$'\r'* ]] \
    || c2me_die 'la raison du rollback ne doit pas contenir de saut de ligne.'
}

assert_release_id() {
  local id="$1"
  [[ "$id" =~ ^[a-z0-9][a-z0-9._-]{2,80}$ ]] \
    || c2me_die "identifiant de release invalide : $id"
}

current_release_id() {
  [[ -L "$current_link" ]] || c2me_die "le lien current est absent ou n'est pas un lien symbolique : $current_link"

  local resolved
  resolved="$(c2me_realpath "$current_link")"
  [[ -n "$resolved" && -d "$resolved" ]] || c2me_die "le lien current ne résout pas vers un répertoire."

  case "$resolved" in
    "$releases_real"/*) ;;
    *) c2me_die "le lien current pointe hors de releases/ : $resolved" ;;
  esac

  local id="${resolved#"$releases_real"/}"

  [[ "$id" != */* ]] || c2me_die "le lien current pointe vers un sous-répertoire inattendu : $resolved"
  assert_release_id "$id"
  printf '%s\n' "$id"
}

release_json_value() {
  local file="$1"
  local key="$2"

  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -n 1
}

assert_release_complete() {
  local id="$1"
  local role="$2"
  local dir="$releases_dir/$id"
  local resolved expected

  assert_release_id "$id"

  [[ -d "$dir" && ! -L "$dir" ]] || c2me_die "release $role introuvable ou symbolique : $id"

  resolved="$(c2me_realpath "$dir")"
  expected="$releases_real/$id"

  [[ "$resolved" == "$expected" ]] \
    || c2me_die "résolution de la release $role hors de releases/ : $dir"

  local required
  for required in artisan public/index.php bootstrap/cache/config.php release.json; do
    [[ -f "$dir/$required" && -r "$dir/$required" ]] \
      || c2me_die "release $role incomplète ($required absent ou illisible) : $id"
  done

  [[ -r "$dir/bootstrap/cache/config.php" ]] \
    || c2me_die "configuration compilée illisible dans la release $role : $id"

  local env_link storage_link public_link
  env_link="$(c2me_realpath "$dir/.env" 2>/dev/null || true)"
  storage_link="$(c2me_realpath "$dir/storage" 2>/dev/null || true)"
  public_link="$(c2me_realpath "$dir/public/storage" 2>/dev/null || true)"

  [[ "$env_link" == "$(c2me_realpath "$shared/.env" 2>/dev/null || true)" ]] \
    || c2me_die "lien .env invalide dans la release $role : $id"
  [[ "$storage_link" == "$(c2me_realpath "$C2ME_STORAGE_ROOT" 2>/dev/null || true)" ]] \
    || c2me_die "lien storage invalide dans la release $role : $id"
  [[ "$public_link" == "$(c2me_realpath "$C2ME_STORAGE_ROOT/app/public" 2>/dev/null || true)" ]] \
    || c2me_die "lien public/storage invalide dans la release $role : $id"

  local marker="$dir/release.json"
  local marker_env marker_release marker_version marker_commit marker_sha

  marker_env="$(release_json_value "$marker" environment)"
  marker_release="$(release_json_value "$marker" release)"
  marker_version="$(release_json_value "$marker" version)"
  marker_commit="$(release_json_value "$marker" commit_sha)"
  marker_sha="$(release_json_value "$marker" sha256)"

  [[ "$marker_env" == "$environment" ]] \
    || c2me_die "release.json incohérent (environment) pour $id."
  [[ "$marker_release" == "$id" ]] \
    || c2me_die "release.json incohérent (release) pour $id."
  [[ "$marker_version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.[1-9][0-9]*)?$ ]] \
    || c2me_die "release.json incohérent (version) pour $id."
  [[ "$marker_commit" =~ ^[0-9a-f]{40}$ ]] \
    || c2me_die "release.json incohérent (commit_sha) pour $id."
  [[ "$marker_sha" =~ ^[0-9a-f]{64}$ ]] \
    || c2me_die "release.json incohérent (sha256) pour $id."

  if c2me_posix_modes_enforced; then
    local mode
    mode="$(stat -c '%a' "$dir/bootstrap/cache/config.php")"

    (( (8#$mode & 8#0007) == 0 )) \
      || c2me_die "configuration compilée accessible aux autres utilisateurs (mode $mode) : $id"
    (( (8#$mode & 8#0020) == 0 )) \
      || c2me_die "configuration compilée modifiable par le groupe (mode $mode) : $id"
    (( (8#$mode & 8#0040) == 8#0040 )) \
      || c2me_die "configuration compilée non lisible par le groupe (mode $mode) : $id"
  fi

  if [[ "$role" == 'cible' ]]; then
    target_dir="$dir"
    target_version="$marker_version"
    target_commit="$marker_commit"
    target_sha256="$marker_sha"
  else
    source_dir="$dir"
    source_version="$marker_version"
    source_commit="$marker_commit"
  fi
}

assert_schema_attestation() {
  c2me_require_file "$attestation_file" 'attestation de compatibilité'
  [[ ! -L "$attestation_file" ]] || c2me_die "attestation symbolique interdite : $attestation_file"
  c2me_require_command "$C2ME_PHP_BIN" 'PHP CLI'

  [[ "$max_attestation_age" =~ ^[0-9]+$ ]] && ((max_attestation_age >= 1)) \
    || c2me_die "durée de validité d attestation invalide : $max_attestation_age"

  local output
  if ! output="$("$C2ME_PHP_BIN" "$ATTESTATION_TOOL" validate "$attestation_file" \
    --environment "$environment" \
    --source "$source_release" \
    --target "$target_release" \
    --database "$C2ME_DB_NAME" \
    --max-age "$max_attestation_age" 2>&1)"; then
    c2me_die "attestation de compatibilité refusée : $output"
  fi

  schema_attestation_sha256="$(c2me_sha256 "$attestation_file")"
}

assert_workers_stopped() {
  ((confirm_workers == 1)) \
    || c2me_die 'workers non confirmés arrêtés : fournir --confirm-workers-stopped après vérification.'

  if [[ -n "${C2ME_SUPERVISOR_PROGRAM:-}" ]]; then
    [[ -n "$C2ME_SUPERVISORCTL_BIN" && -x "$C2ME_SUPERVISORCTL_BIN" ]] \
      || c2me_die 'C2ME_SUPERVISOR_PROGRAM est défini mais supervisorctl est introuvable.'

    local status
    status="$("$C2ME_SUPERVISORCTL_BIN" status "$C2ME_SUPERVISOR_PROGRAM" 2>/dev/null || true)"

    [[ "$status" != *RUNNING* && "$status" != *STARTING* ]] \
      || c2me_die "le programme Supervisor est encore actif : $status"
  fi

  if command -v pgrep >/dev/null 2>&1; then
    if pgrep -af 'queue:work|queue:listen|horizon' 2>/dev/null | grep -F -- "$C2ME_ROOT" >/dev/null 2>&1; then
      c2me_die "un worker de file d'attente semble encore actif pour $C2ME_ROOT."
    fi
  fi
}

assert_queues_paused() {
  ((confirm_queues == 1)) \
    || c2me_die 'files non confirmées en pause : fournir --confirm-queues-paused après vérification.'
}

assert_jobs_triaged() {
  ((confirm_jobs == 1)) \
    || c2me_die 'jobs non confirmés traités : fournir --confirm-jobs-triaged après vérification.'
}

assert_maintenance_readable() {
  [[ -d "$storage_framework" ]] || c2me_die "état de maintenance non vérifiable : $storage_framework absent."

  if [[ -f "$C2ME_MAINTENANCE_MARKER" ]]; then
    maintenance_state='actif'
  else
    maintenance_state='inactif'
  fi

  [[ -e "$shared/.env" ]] || c2me_die "shared/.env absent : état de configuration non vérifiable."
  [[ ! -L "$shared/.env" ]] || c2me_die "shared/.env symbolique interdit."
}

assert_current_unchanged() {
  local current
  current="$(current_release_id)"

  [[ "$current" == "$source_release" ]] \
    || c2me_die "le lien current a changé pendant l'opération ($current au lieu de $source_release)."
}

# ---------------------------------------------------------------------------
# Bascule et health check
# ---------------------------------------------------------------------------

activate_release() {
  local tmp_link="$C2ME_ROOT/.current.rollback.$$"

  mask_signals

  if ! ln -sfn "$target_dir" "$tmp_link"; then
    unmask_signals
    fail_after_change 'création du lien current temporaire impossible.'
  fi

  if ! mv -Tf "$tmp_link" "$current_link"; then
    rm -f -- "$tmp_link" 2>/dev/null || true
    unmask_signals
    fail_after_change 'activation atomique de current impossible.'
  fi

  switched=1
  current_after="$(c2me_realpath "$current_link")"

  unmask_signals

  if [[ "$current_after" != "$(c2me_realpath "$target_dir")" ]]; then
    fail_after_change 'current ne pointe pas vers la release cible après activation.'
  fi
}

health_check() {
  local curl_bin="$C2ME_CURL_BIN"
  local url body body_file instruction

  c2me_require_command "$curl_bin" 'curl (health check obligatoire)'
  url="$(c2me_env_url "$environment")"
  instruction="Retour manuel possible vers $source_release via rollback.sh --env $environment --to $source_release --reason <motif> --schema-attestation <fichier> après une nouvelle attestation."

  body_file="$(mktemp "$shared/.rollback-health.XXXXXX")" \
    || fail_after_change 'fichier temporaire de health check impossible.'
  c2me_register_cleanup "$body_file"

  if ! c2me_run "$curl_bin" --fail --silent --show-error --max-time 15 \
    --header 'Accept: application/json' "$url/up" >"$body_file" 2>&1; then
    health_status='failed'
    fail_after_change "health check en échec après activation : $url/up. $instruction"
  fi

  body="$(cat "$body_file")"
  rm -f -- "$body_file"

  if [[ "$body" != *'"status":"up"'* ]]; then
    health_status='failed'
    fail_after_change "health check incohérent après activation : réponse inattendue de $url/up. $instruction"
  fi

  health_status='ok'
}

# ---------------------------------------------------------------------------
# Exécution
# ---------------------------------------------------------------------------

main() {
  if [[ "${1:-}" == 'unlock' ]]; then
    command='unlock'
    shift
  fi

  while (($#)); do
    case "$1" in
      --env | --environment)
        environment="${2:-}"
        shift 2
        ;;
      --to)
        target_release="${2:-}"
        shift 2
        ;;
      --from)
        from_release="${2:-}"
        shift 2
        ;;
      --reason)
        reason="${2:-}"
        shift 2
        ;;
      --schema-attestation)
        attestation_file="${2:-}"
        shift 2
        ;;
      --max-attestation-age)
        max_attestation_age="${2:-}"
        shift 2
        ;;
      --confirm-workers-stopped)
        confirm_workers=1
        shift
        ;;
      --confirm-queues-paused)
        confirm_queues=1
        shift
        ;;
      --confirm-jobs-triaged)
        confirm_jobs=1
        shift
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --confirm-stale-lock)
        confirm_stale_lock=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        c2me_die "option inconnue : $1"
        ;;
    esac
  done

  [[ -n "$environment" ]] || c2me_die 'l option --env est obligatoire.'

  if [[ "$command" == 'unlock' ]]; then
    ((confirm_stale_lock == 1)) \
      || c2me_die 'la libération d un verrou orphelin exige --confirm-stale-lock après vérification manuelle.'

    c2me_resolve_environment "$environment"
    root="$C2ME_ROOT"

    c2me_release_stale_lock "$C2ME_ROOT/shared/$ROLLBACK_LOCK_NAME"
    printf 'UNLOCK=ok\n'

    return 0
  fi

  [[ -n "$target_release" ]] || c2me_die 'l option --to est obligatoire.'
  [[ -n "$attestation_file" ]] || c2me_die "l option --schema-attestation est obligatoire."
  [[ -n "$reason" ]] || c2me_die "l option --reason est obligatoire."

  c2me_resolve_environment "$environment"
  root="$C2ME_ROOT"
  C2ME_UNLOCK_HINT="scripts/ops/rollback.sh unlock --env $environment --confirm-stale-lock"
  operation_id="rollback-$environment-$(c2me_iso_compact)-$(c2me_random_hex8)"

  if [[ -n "$from_release" ]]; then
    assert_release_id "$from_release"
  fi

  assert_reason
  assert_root_layout

  if ((dry_run == 0)); then
    prepare_logging
  fi

  assert_no_incoming_release

  c2me_require_command "$C2ME_CURL_BIN" 'curl (health check obligatoire)'

  source_release="$(current_release_id)"
  current_before="$(c2me_realpath "$current_link")"

  if [[ -n "$from_release" && "$source_release" != "$from_release" ]]; then
    c2me_die "la release active ($source_release) ne correspond pas à --from ($from_release)."
  fi

  if [[ "$target_release" == "$source_release" ]]; then
    c2me_die "la release cible est déjà active : $target_release"
  fi

  assert_release_complete "$source_release" 'source'
  assert_release_complete "$target_release" 'cible'
  assert_maintenance_readable
  assert_schema_attestation
  assert_workers_stopped
  assert_queues_paused
  assert_jobs_triaged

  if ((dry_run == 1)); then
    printf 'PLAN=ok\n'
    printf 'MODE=dry-run\n'
    printf 'ENVIRONMENT=%s\n' "$environment"
    printf 'SOURCE=%s\n' "$source_release"
    printf 'TARGET=%s\n' "$target_release"
    printf 'CURRENT_BEFORE=%s\n' "$current_before"
    printf 'VALIDATION=ok\n'
    printf 'Aucune modification effectuée (--dry-run).\n'
    return 0
  fi

  c2me_acquire_lock "$shared/$ROLLBACK_LOCK_NAME"
  printf 'rollback\n' >"$C2ME_LOCK_DIR/operation" 2>/dev/null || true

  assert_no_incoming_release
  assert_current_unchanged

  rollback_log_event 'started' 'in_progress' ''

  activate_release
  health_check

  rollback_log_event 'completed' 'success' ''

  printf 'ROLLBACK=ok\nOPERATION_ID=%s\nSOURCE=%s\nTARGET=%s\nCURRENT_AFTER=%s\nHEALTH=%s\n' \
    "$operation_id" "$source_release" "$target_release" "$current_after" "$health_status"
  printf 'Workers et files non modifiés par le script : reprendre manuellement selon le runbook.\n'
}

install_traps
main "$@"
