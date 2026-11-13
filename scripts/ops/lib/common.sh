#!/usr/bin/env bash
#
# Fonctions communes aux scripts d'exploitation CHAN-98 (lot 2).
#
# Ce fichier est sourcé par backup.sh et restore.sh. Il ne doit contenir
# aucun secret et ne doit jamais être exécuté directement.

if [[ -n "${C2ME_OPS_COMMON_LOADED:-}" ]]; then
  return 0
fi
C2ME_OPS_COMMON_LOADED=1

set -Eeuo pipefail
umask 027

OPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS_LIB_DIR="$OPS_SCRIPT_DIR/lib"
OPS_MANIFEST_TOOL="$OPS_LIB_DIR/manifest.php"

C2ME_SUPPORTED_ENVIRONMENTS=(staging production)

# ---------------------------------------------------------------------------
# Environnements : table fixe, jamais déduite d'une variable libre.
# ---------------------------------------------------------------------------

c2me_env_root() {
  case "$1" in
    staging) printf '%s\n' '/www/wwwroot/chantier-staging.c2me.ovh' ;;
    production) printf '%s\n' '/www/wwwroot/chantier.c2me.fr' ;;
    *) return 1 ;;
  esac
}

c2me_env_database() {
  case "$1" in
    staging) printf '%s\n' 'chantier_staging' ;;
    production) printf '%s\n' 'chantier_production' ;;
    *) return 1 ;;
  esac
}

c2me_env_group() {
  case "$1" in
    staging) printf '%s\n' 'c2me-staging' ;;
    production) printf '%s\n' 'c2me-production' ;;
    *) return 1 ;;
  esac
}

c2me_env_backup_root() {
  case "$1" in
    staging | production) printf '%s\n' "/var/backups/c2me/$1" ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Journalisation
# ---------------------------------------------------------------------------

c2me_json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' \
    | tr -d '\r\n'
}

c2me_iso_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

c2me_iso_compact() {
  date -u '+%Y%m%dT%H%M%SZ'
}

c2me_random_hex8() {
  if command -v od >/dev/null 2>&1 && [[ -r /dev/urandom ]]; then
    od -An -tx1 -N4 /dev/urandom | tr -d ' \n'
  else
    printf '%08x' "${RANDOM:-0}"
  fi
}

c2me_log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(c2me_iso_now)"

  printf '[%s] %s: %s\n' "$timestamp" "$level" "$message" >&2

  if [[ -n "${C2ME_BACKUP_ROOT:-}" && -d "${C2ME_BACKUP_ROOT:-}" && -w "${C2ME_BACKUP_ROOT:-}" ]]; then
    printf '{"timestamp":"%s","level":"%s","environment":"%s","event":"%s","message":"%s","pid":%d}\n' \
      "$timestamp" \
      "$(c2me_json_escape "$level")" \
      "$(c2me_json_escape "${C2ME_ENV:-unknown}")" \
      "$(c2me_json_escape "${C2ME_EVENT:-ops}")" \
      "$(c2me_json_escape "$message")" \
      "$$" >>"$C2ME_BACKUP_ROOT/ops.log" 2>/dev/null || true
  fi
}

c2me_info() {
  c2me_log info "$@"
}

c2me_warn() {
  c2me_log warning "$@"
}

c2me_die() {
  c2me_log error "$@"
  exit 1
}

# ---------------------------------------------------------------------------
# Nettoyage et verrou
# ---------------------------------------------------------------------------

C2ME_CLEANUP_PATHS=()

c2me_register_cleanup() {
  C2ME_CLEANUP_PATHS+=("$1")
}

C2ME_CLEANUP_DONE=0

c2me_cleanup() {
  if ((C2ME_CLEANUP_DONE == 1)); then
    return 0
  fi

  C2ME_CLEANUP_DONE=1
  local path
  set +e

  for path in "${C2ME_CLEANUP_PATHS[@]:-}"; do
    if [[ -n "$path" && -e "$path" ]]; then
      rm -rf -- "$path" 2>/dev/null || true
    fi
  done

  if [[ -n "${C2ME_LOCK_DIR:-}" && -d "${C2ME_LOCK_DIR:-}" ]]; then
    rm -rf -- "$C2ME_LOCK_DIR" 2>/dev/null || true
  fi

  return 0
}

# Gestionnaire de signal : nettoie puis termine le processus avec un code
# explicite. Aucune opération ne reprend après le nettoyage.
c2me_on_signal() {
  local code="$1"

  trap - EXIT HUP INT TERM
  c2me_cleanup
  exit "$code"
}

c2me_lock_pid_alive() {
  local pid="$1"

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

c2me_acquire_lock() {
  local lock_dir="$1"

  if [[ -d "$lock_dir" ]]; then
    local pid started_at
    pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
    started_at="$(cat "$lock_dir/started_at" 2>/dev/null || true)"

    if c2me_lock_pid_alive "$pid"; then
      c2me_die "une autre opération est déjà en cours (pid $pid, depuis ${started_at:-date inconnue}, verrou : $lock_dir)."
    fi

    c2me_die "verrou orphelin détecté (pid ${pid:-inconnu}, depuis ${started_at:-date inconnue}) : suppression automatique interdite. Vérifier qu'aucun processus n'est actif, puis exécuter 'backup.sh unlock --env <env> --confirm-stale-lock'."
  fi

  if ! mkdir -- "$lock_dir" 2>/dev/null; then
    c2me_die "impossible de créer le verrou (course concurrente ?) : $lock_dir"
  fi

  C2ME_LOCK_DIR="$lock_dir"
  c2me_chmod 0700 -- "$lock_dir"
  printf '%s\n' "$$" >"$lock_dir/pid" 2>/dev/null || true
  printf '%s\n' "$(c2me_iso_now)" >"$lock_dir/started_at" 2>/dev/null || true
  printf '%s\n' "${C2ME_HOST_ID:-unknown}" >"$lock_dir/host" 2>/dev/null || true
  C2ME_CLEANUP_PATHS+=("$lock_dir")
}

# Récupération explicite d'un verrou orphelin. Refuse si le PID est vivant.
c2me_release_stale_lock() {
  local lock_dir="$1"

  if [[ ! -d "$lock_dir" ]]; then
    c2me_die "aucun verrou à libérer : $lock_dir"
  fi

  local pid started_at
  pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
  started_at="$(cat "$lock_dir/started_at" 2>/dev/null || true)"

  if c2me_lock_pid_alive "$pid"; then
    c2me_die "le verrou est actif (pid $pid depuis ${started_at:-date inconnue}) : libération refusée."
  fi

  rm -rf -- "$lock_dir"
  c2me_info "verrou orphelin libéré explicitement (pid ${pid:-inconnu}, depuis ${started_at:-date inconnue})."
}

# Applique un mode. Sur les systèmes de test non POSIX (MSYS), chmod est sans
# effet : l'échec y est toléré, jamais sur Linux.
c2me_chmod() {
  if chmod "$@" 2>/dev/null; then
    return 0
  fi

  case "$(uname -s 2>/dev/null || true)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

c2me_mkdir_mode() {
  local directory="$1"
  local mode="$2"

  mkdir -p -- "$directory" || return 1
  c2me_chmod "$mode" -- "$directory" || return 1
}

# Indique si la plateforme applique réellement les modes POSIX. Utilisé pour
# ne pas déclarer conformes des permissions qui ne peuvent pas être posées.
c2me_posix_modes_enforced() {
  local probe mode

  probe="$(mktemp 2>/dev/null)" || return 1

  if ! chmod 0600 "$probe" 2>/dev/null; then
    rm -f -- "$probe"
    return 1
  fi

  mode="$(stat -c '%a' -- "$probe" 2>/dev/null || stat -f '%Lp' -- "$probe" 2>/dev/null || printf 'unknown')"
  rm -f -- "$probe"

  [[ "$mode" == '600' ]]
}

# Indique si la plateforme applique réellement le bit setgid. Utilisé pour ne
# pas déclarer conformes des permissions qui ne peuvent pas être posées.
c2me_setgid_supported() {
  local probe
  probe="$(mktemp -d 2>/dev/null)" || return 1

  if ! chmod 2770 "$probe" 2>/dev/null; then
    rm -rf -- "$probe"
    return 1
  fi

  if [[ -n "$(find "$probe" -maxdepth 0 -perm -2000 -print 2>/dev/null)" ]]; then
    rm -rf -- "$probe"
    return 0
  fi

  rm -rf -- "$probe"
  return 1
}

# ---------------------------------------------------------------------------
# Validation des chemins
# ---------------------------------------------------------------------------

c2me_assert_absolute() {
  local path="$1"
  local label="$2"

  [[ "$path" = /* ]] || c2me_die "$label doit être un chemin absolu : $path"
  [[ "$path" != *".."* ]] || c2me_die "$label ne doit pas contenir de traversée de chemin : $path"
}

c2me_realpath() {
  local path="$1"

  if realpath -m -- "$path" >/dev/null 2>&1; then
    realpath -m -- "$path"
    return 0
  fi

  local parent base
  parent="$(dirname -- "$path")"
  base="$(basename -- "$path")"

  while [[ ! -d "$parent" && "$parent" != '/' ]]; do
    parent="$(dirname -- "$parent")"
  done

  if [[ -d "$parent" ]]; then
    (cd "$parent" && printf '%s/%s\n' "$(pwd -P)" "$base")
  else
    printf '%s\n' "$path"
  fi
}

# Refuse tout chemin situé sous une racine applicative, une release, un
# répertoire public ou la racine de sauvegarde.
c2me_assert_not_forbidden_path() {
  local candidate="$1"
  local label="$2"
  local resolved candidate_resolved resolved_root

  c2me_assert_absolute "$candidate" "$label"

  candidate_resolved="$(c2me_realpath "$candidate")"

  for resolved in \
    "${C2ME_ROOT:-}" \
    "${C2ME_ROOT:-}/releases" \
    "${C2ME_ROOT:-}/current" \
    "${C2ME_ROOT:-}/public" \
    "${C2ME_ROOT:-}/shared" \
    "${C2ME_ROOT:-}/shared/storage" \
    "${C2ME_BACKUP_ROOT:-}/sets" \
    "${C2ME_BACKUP_ROOT:-}/incoming" \
    "${C2ME_BACKUP_ROOT:-}/expired" \
    "${C2ME_BACKUP_ROOT:-}/ledger"; do
    [[ -n "$resolved" ]] || continue
    resolved_root="$(c2me_realpath "$resolved")"
    [[ -n "$resolved_root" ]] || resolved_root="$resolved"

    if [[ "$candidate_resolved" == "$resolved_root" || "$candidate_resolved" == "$resolved_root"/* ]]; then
      c2me_die "$label est interdite : $candidate (sous $resolved_root)."
    fi
  done

  case "$candidate_resolved" in
    /www/wwwroot | /www/wwwroot/*)
      c2me_die "$label est interdite : $candidate (racine web)."
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Résolution de l'environnement
# ---------------------------------------------------------------------------

c2me_resolve_environment() {
  local environment="$1"

  [[ -n "$environment" ]] || c2me_die "l'environnement est obligatoire (staging ou production)."

  case "$environment" in
    staging | production) ;;
    *) c2me_die "environnement non autorisé : $environment" ;;
  esac

  C2ME_ENV="$environment"

  local expected_root expected_db expected_group expected_backup_root
  expected_root="$(c2me_env_root "$environment")"
  expected_db="$(c2me_env_database "$environment")"
  expected_group="$(c2me_env_group "$environment")"
  expected_backup_root="$(c2me_env_backup_root "$environment")"

  C2ME_ROOT="${C2ME_ROOT:-$expected_root}"
  C2ME_DB_NAME="${C2ME_DB_NAME:-$expected_db}"
  C2ME_GROUP="${C2ME_GROUP:-$expected_group}"
  C2ME_BACKUP_ROOT="${C2ME_BACKUP_ROOT:-$expected_backup_root}"

  c2me_assert_absolute "$C2ME_ROOT" 'C2ME_ROOT'
  c2me_assert_absolute "$C2ME_BACKUP_ROOT" 'C2ME_BACKUP_ROOT'

  [[ "$(basename "$C2ME_ROOT")" == "$(basename "$expected_root")" ]] \
    || c2me_die "C2ME_ROOT ne correspond pas à l'environnement $environment (attendu : $expected_root)."

  [[ "$C2ME_DB_NAME" == "$expected_db" ]] \
    || c2me_die "C2ME_DB_NAME ne correspond pas à l'environnement $environment (attendu : $expected_db)."

  [[ "$C2ME_GROUP" == "$expected_group" ]] \
    || c2me_die "C2ME_GROUP ne correspond pas à l'environnement $environment (attendu : $expected_group)."

  if [[ "$C2ME_BACKUP_ROOT" == "$C2ME_ROOT" || "$C2ME_BACKUP_ROOT" == "$C2ME_ROOT"/* ]]; then
    c2me_die "C2ME_BACKUP_ROOT doit être hors de la racine applicative."
  fi

  if [[ "$C2ME_BACKUP_ROOT" == /www/wwwroot || "$C2ME_BACKUP_ROOT" == /www/wwwroot/* ]]; then
    c2me_die "C2ME_BACKUP_ROOT ne doit pas être une racine web."
  fi

  C2ME_STORAGE_ROOT="$C2ME_ROOT/shared/storage"
  C2ME_MAINTENANCE_MARKER="$C2ME_STORAGE_ROOT/framework/down"
  C2ME_RELEASE_FILE="$C2ME_ROOT/current/release.json"
  C2ME_OPERATOR="${C2ME_OPERATOR:-${USER:-unknown}}"
  C2ME_HOST_ID="${C2ME_HOST_ID:-$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')}"
  C2ME_OPERATOR="$(printf '%s' "$C2ME_OPERATOR" | tr -cd 'A-Za-z0-9._-')"
  C2ME_HOST_ID="$(printf '%s' "$C2ME_HOST_ID" | tr -cd 'A-Za-z0-9._-')"
  [[ -n "$C2ME_OPERATOR" ]] || C2ME_OPERATOR='unknown'
  [[ -n "$C2ME_HOST_ID" ]] || C2ME_HOST_ID='unknown'

  C2ME_PHP_BIN="${C2ME_PHP_BIN:-php}"
  C2ME_MYSQL_BIN="${C2ME_MYSQL_BIN:-$(command -v mariadb || command -v mysql || true)}"
  C2ME_DB_DUMP_BIN="${C2ME_DB_DUMP_BIN:-$(command -v mariadb-dump || command -v mysqldump || true)}"
  C2ME_AGE_BIN="${C2ME_AGE_BIN:-$(command -v age || true)}"
  C2ME_TAR_BIN="${C2ME_TAR_BIN:-$(command -v tar || true)}"
  C2ME_ZSTD_BIN="${C2ME_ZSTD_BIN:-$(command -v zstd || true)}"
  C2ME_GZIP_BIN="${C2ME_GZIP_BIN:-$(command -v gzip || true)}"
  C2ME_SUPERVISORCTL_BIN="${C2ME_SUPERVISORCTL_BIN:-$(command -v supervisorctl || true)}"

  C2ME_RETENTION_DAILY_DAYS="${C2ME_RETENTION_DAILY_DAYS:-30}"
  C2ME_RETENTION_MONTHLY_DAYS="${C2ME_RETENTION_MONTHLY_DAYS:-365}"
  C2ME_QUARANTINE_DAYS="${C2ME_QUARANTINE_DAYS:-7}"

  export C2ME_ENV C2ME_ROOT C2ME_DB_NAME C2ME_GROUP C2ME_BACKUP_ROOT C2ME_STORAGE_ROOT
}

c2me_require_file() {
  local path="$1"
  local label="$2"

  [[ -f "$path" ]] || c2me_die "$label introuvable : $path"
}

c2me_require_dir() {
  local path="$1"
  local label="$2"

  [[ -d "$path" ]] || c2me_die "$label introuvable : $path"
}

c2me_require_command() {
  local path="$1"
  local label="$2"

  [[ -n "$path" && -x "$path" ]] || c2me_die "$label absent ou non exécutable : ${path:-<vide>}"
}

c2me_sha256() {
  local path="$1"

  sha256sum -- "$path" | awk '{print $1}'
}

c2me_file_bytes() {
  local path="$1"

  wc -c <"$path" | tr -d ' '
}

c2me_available_kb() {
  local path="$1"

  df -Pk -- "$path" | awk 'NR==2 {print $4}'
}

c2me_require_free_space() {
  local path="$1"
  local required_kb="$2"
  local available_kb

  available_kb="$(c2me_available_kb "$path")"
  [[ -n "$available_kb" ]] || c2me_die "impossible de mesurer l'espace disque de $path."

  if ((available_kb < required_kb)); then
    c2me_die "espace disque insuffisant : ${available_kb} Ko disponibles, ${required_kb} Ko requis."
  fi
}

# ---------------------------------------------------------------------------
# Outils externes
# ---------------------------------------------------------------------------

c2me_select_compressor() {
  local requested="${C2ME_COMPRESSION:-auto}"

  case "$requested" in
    zstd)
      c2me_require_command "$C2ME_ZSTD_BIN" 'zstd'
      C2ME_COMPRESSION_TOOL='zstd'
      C2ME_COMPRESSION_EXT='zst'
      ;;
    gzip)
      c2me_require_command "$C2ME_GZIP_BIN" 'gzip'
      C2ME_COMPRESSION_TOOL='gzip'
      C2ME_COMPRESSION_EXT='gz'
      ;;
    auto)
      if [[ -n "$C2ME_ZSTD_BIN" && -x "$C2ME_ZSTD_BIN" ]]; then
        C2ME_COMPRESSION_TOOL='zstd'
        C2ME_COMPRESSION_EXT='zst'
      elif [[ -n "$C2ME_GZIP_BIN" && -x "$C2ME_GZIP_BIN" ]]; then
        C2ME_COMPRESSION_TOOL='gzip'
        C2ME_COMPRESSION_EXT='gz'
      else
        c2me_die 'aucun outil de compression disponible (zstd ou gzip).'
      fi
      ;;
    *)
      c2me_die "C2ME_COMPRESSION invalide : $requested"
      ;;
  esac
}

c2me_compress() {
  local source="$1"
  local destination="$2"

  if [[ "$C2ME_COMPRESSION_TOOL" == 'zstd' ]]; then
    "$C2ME_ZSTD_BIN" -q -T0 -10 -o "$destination" -- "$source"
  else
    "$C2ME_GZIP_BIN" -9 -c -- "$source" >"$destination"
  fi
}

c2me_test_compression() {
  local path="$1"

  if [[ "$C2ME_COMPRESSION_TOOL" == 'zstd' ]]; then
    "$C2ME_ZSTD_BIN" -q -t -- "$path"
  else
    "$C2ME_GZIP_BIN" -t -- "$path" 2>/dev/null
  fi
}

c2me_decompress() {
  local source="$1"
  local destination="$2"
  local tool="$3"

  case "$tool" in
    zstd)
      c2me_require_command "$C2ME_ZSTD_BIN" 'zstd'
      "$C2ME_ZSTD_BIN" -d -q -o "$destination" -- "$source"
      ;;
    gzip)
      c2me_require_command "$C2ME_GZIP_BIN" 'gzip'
      "$C2ME_GZIP_BIN" -d -c -- "$source" >"$destination"
      ;;
    *)
      c2me_die "outil de compression inconnu : $tool"
      ;;
  esac

  [[ -s "$destination" ]] || c2me_die "le fichier décompressé est vide : $destination"
}

c2me_age_encrypt() {
  local source="$1"
  local destination="$2"
  local recipient_file="$3"

  c2me_require_command "$C2ME_AGE_BIN" 'age'
  c2me_require_file "$recipient_file" 'fichier destinataire age'

  if ! "$C2ME_AGE_BIN" --encrypt --recipients-file "$recipient_file" --output "$destination" -- "$source"; then
    c2me_die "échec du chiffrement age de $source."
  fi

  [[ -s "$destination" ]] || c2me_die "l'artefact chiffré est vide : $destination"
}

c2me_age_decrypt() {
  local source="$1"
  local destination="$2"
  local identity_file="$3"

  c2me_require_command "$C2ME_AGE_BIN" 'age'
  c2me_require_file "$identity_file" 'clé privée age'

  if ! "$C2ME_AGE_BIN" --decrypt --identity "$identity_file" --output "$destination" -- "$source"; then
    c2me_die "échec du déchiffrement de $source."
  fi

  [[ -s "$destination" ]] || c2me_die "le fichier déchiffré est vide : $destination"
}

c2me_age_recipient() {
  local recipient_file="$1"

  c2me_require_file "$recipient_file" 'fichier destinataire age'
  head -n 1 "$recipient_file" | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Manifeste
# ---------------------------------------------------------------------------

c2me_manifest_validate() {
  local manifest="$1"

  "$C2ME_PHP_BIN" "$OPS_MANIFEST_TOOL" validate "$manifest"
}

c2me_manifest_summary() {
  local manifest="$1"
  local key="$2"

  "$C2ME_PHP_BIN" "$OPS_MANIFEST_TOOL" summary "$manifest" "$key"
}

c2me_release_value() {
  local key="$1"
  local fallback="$2"

  if [[ ! -f "$C2ME_RELEASE_FILE" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  local value
  value="$(sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$C2ME_RELEASE_FILE" | head -n 1)"

  if [[ -z "$value" ]]; then
    printf '%s\n' "$fallback"
  else
    printf '%s\n' "$value"
  fi
}
