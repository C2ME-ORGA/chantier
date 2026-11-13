#!/usr/bin/env bash
#
# Restauration C2ME Chantier — CHAN-98, lot 2.
#
# La restauration cible toujours une base et un répertoire neufs. Elle refuse
# toute cible applicative, toute cible préexistante et toute clé privée mal
# protégée. Elle ne touche jamais chantier_staging ni chantier_production.
#
# Voir docs/development/backup-restore.md et backup-restore-runbook.md.

set -Eeuo pipefail

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$OPS_DIR/lib/common.sh"

trap c2me_cleanup EXIT
trap 'c2me_on_signal 129' HUP
trap 'c2me_on_signal 130' INT
trap 'c2me_on_signal 143' TERM

usage() {
  cat <<'EOF'
Usage : restore.sh <commande> --env <staging|production> --set <set-id> [options]

Commandes :
  verify        Vérifie l'intégrité du jeu (délègue à backup.sh verify)
  db            Restaure la base dans une base neuve chantier_restore_<date>_<hex8>
  files         Restaure les fichiers dans un répertoire neuf
  all           Restaure la base puis les fichiers
  report        Produit et chaîne le rapport de restauration
  unlock        Libère explicitement un verrou orphelin

Options :
  --env <env>                 Environnement du jeu (obligatoire)
  --set <set-id>              Jeu à restaurer (obligatoire)
  --target-db <nom>           Base cible ; motif chantier_restore_YYYYMMDD_hex8
  --target-dir <chemin>       Répertoire cible neuf, hors racine applicative
  --owner <user:groupe>       Remappage d'appartenance (obligatoire pour files)
  --identity <fichier>        Clé privée age, 0600, hors emplacement interdit
  --notes <texte>             Notes du rapport
  --confirm-stale-lock        Confirme la libération d'un verrou orphelin
  -h, --help                  Affiche cette aide

Aucune donnée déchiffrée n'est conservée : la zone de travail est supprimée
à la fin, y compris après un échec. Aucun mode 777 n'est appliqué.
EOF
}

command="${1:-}"
[[ -n "$command" ]] || {
  usage
  exit 2
}
shift

env=""
set_id=""
target_db=""
target_dir=""
owner=""
identity=""
notes=""
confirm_stale_lock=0

while (($#)); do
  case "$1" in
    --env)
      env="${2:-}"
      shift 2
      ;;
    --set)
      set_id="${2:-}"
      shift 2
      ;;
    --target-db)
      target_db="${2:-}"
      shift 2
      ;;
    --target-dir)
      target_dir="${2:-}"
      shift 2
      ;;
    --owner)
      owner="${2:-}"
      shift 2
      ;;
    --identity)
      identity="${2:-}"
      shift 2
      ;;
    --notes)
      notes="${2:-}"
      shift 2
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
      c2me_die "option inconnue : $1"
      ;;
  esac
done

[[ -n "$env" ]] || c2me_die "l'option --env est obligatoire."
[[ -n "$set_id" ]] || c2me_die "l'option --set est obligatoire."

c2me_resolve_environment "$env"
C2ME_DB_DEFAULTS_FILE="${C2ME_DB_DEFAULTS_FILE:-}"
C2ME_RESTORE_DB_DEFAULTS_FILE="${C2ME_RESTORE_DB_DEFAULTS_FILE:-$C2ME_DB_DEFAULTS_FILE}"
C2ME_RESTORE_WORK_ROOT="${C2ME_RESTORE_WORK_ROOT:-/var/tmp/c2me-restore}"
C2ME_LEDGER_DIR="$C2ME_BACKUP_ROOT/ledger"
C2ME_REPORTS_DIR="$C2ME_LEDGER_DIR/restore-reports"
C2ME_STATE_DIR="$C2ME_LEDGER_DIR/restore-state"

# ---------------------------------------------------------------------------
# Gardes
# ---------------------------------------------------------------------------

assert_set_valid() {
  [[ "$set_id" =~ ^set-(staging|production)-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$ ]] \
    || c2me_die "identifiant de jeu invalide : $set_id"

  [[ "$set_id" == set-"$C2ME_ENV"-* ]] \
    || c2me_die "le jeu $set_id n'appartient pas à l'environnement $C2ME_ENV."

  C2ME_SET_DIR="$C2ME_BACKUP_ROOT/sets/$set_id"
  c2me_require_dir "$C2ME_SET_DIR" 'jeu de sauvegarde'
  c2me_require_file "$C2ME_SET_DIR/manifest.json" 'manifeste du jeu'

  c2me_manifest_validate "$C2ME_SET_DIR/manifest.json" \
    || c2me_die 'manifeste invalide : restauration refusée.'

  (
    cd "$C2ME_SET_DIR"
    sha256sum -c --quiet SHA256SUMS
  ) || c2me_die 'artefact altéré : restauration refusée.'

  local expected actual
  expected="$(awk '{print $1}' "$C2ME_SET_DIR/manifest.json.sha256")"
  actual="$(c2me_sha256 "$C2ME_SET_DIR/manifest.json")"
  [[ "$expected" == "$actual" ]] || c2me_die 'checksum du manifeste invalide : restauration refusée.'

  local status
  status="$(c2me_manifest_summary "$C2ME_SET_DIR/manifest.json" status)"

  if [[ "$status" != 'complete' ]]; then
    c2me_die "le jeu n'est pas complet (status=$status) : restauration refusée."
  fi
}

assert_full_set() {
  local scope restorable
  scope="$(c2me_manifest_summary "$C2ME_SET_DIR/manifest.json" scope)"
  restorable="$(c2me_manifest_summary "$C2ME_SET_DIR/manifest.json" restorable_as_complete)"

  [[ "$scope" == 'full' ]] || c2me_die "jeu $scope : une restauration complète exige un jeu full."
  [[ "$restorable" == 'true' ]] || c2me_die 'jeu non restaurable comme complet : restauration refusée.'
}

assert_identity_file() {
  [[ -n "$identity" ]] || c2me_die "l'option --identity est obligatoire (clé privée age)."
  c2me_require_file "$identity" 'clé privée age'

  local mode
  mode="$(stat -c '%a' -- "$identity" 2>/dev/null || stat -f '%Lp' -- "$identity" 2>/dev/null || true)"

  if c2me_posix_modes_enforced; then
    [[ "$mode" =~ ^[0-7]{3,4}$ ]] || c2me_die "impossible de vérifier les permissions de la clé : $identity"

    if (((8#$mode & 8#077) != 0)); then
      c2me_die "la clé privée age est accessible au groupe ou aux autres (mode $mode) : refusée."
    fi
  else
    c2me_warn 'modes POSIX non appliqués par cette plateforme : contrôle de permission de la clé ignoré (Linux uniquement).'
  fi

  c2me_assert_not_forbidden_path "$identity" 'clé privée age'
}

assert_target_database() {
  [[ -n "$target_db" ]] || c2me_die "l'option --target-db est obligatoire."

  [[ "$target_db" =~ ^chantier_restore_[0-9]{8}_[0-9a-f]{8}$ ]] \
    || c2me_die "base cible invalide : $target_db (attendu chantier_restore_YYYYMMDD_hex8)."

  [[ "$target_db" != "$C2ME_DB_NAME" ]] \
    || c2me_die 'la base cible ne doit jamais être la base applicative.'

  [[ "$target_db" != 'chantier_staging' && "$target_db" != 'chantier_production' ]] \
    || c2me_die 'la base cible ne doit jamais être une base applicative.'

  c2me_require_file "$C2ME_RESTORE_DB_DEFAULTS_FILE" 'fichier d options MySQL de restauration'
  c2me_require_command "$C2ME_MYSQL_BIN" 'client mariadb/mysql'

  local existing
  existing="$("$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_RESTORE_DB_DEFAULTS_FILE" -N -B \
    -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '$target_db'")"

  [[ -z "$existing" ]] || c2me_die "la base cible existe déjà : $target_db. Choisir un identifiant neuf."
}

assert_target_directory() {
  [[ -n "$target_dir" ]] || c2me_die "l'option --target-dir est obligatoire."

  case "$target_dir" in
    / | /etc | /usr | /bin | /sbin | /boot | /dev | /proc | /sys | /root | /home | /var | /opt | /srv | /www)
      c2me_die "répertoire cible interdit : $target_dir"
      ;;
  esac

  c2me_assert_not_forbidden_path "$target_dir" 'répertoire cible'

  [[ ! -e "$target_dir" ]] || c2me_die "le répertoire cible existe déjà : $target_dir. Choisir un chemin neuf."

  [[ -n "$owner" ]] || c2me_die "l'option --owner <utilisateur:groupe> est obligatoire."

  local user group
  user="${owner%%:*}"
  group="${owner#*:}"

  [[ "$owner" == *:* && -n "$user" && -n "$group" ]] \
    || c2me_die "format d'appartenance invalide : $owner (attendu utilisateur:groupe)."

  id -u -- "$user" >/dev/null 2>&1 || c2me_die "utilisateur inconnu : $user"

  if command -v getent >/dev/null 2>&1; then
    getent group -- "$group" >/dev/null 2>&1 || c2me_die "groupe inconnu : $group"
  fi

  C2ME_TARGET_OWNER="$owner"
  C2ME_TARGET_USER="$user"
  C2ME_TARGET_GROUP="$group"
}

prepare_work_dir() {
  c2me_assert_not_forbidden_path "$C2ME_RESTORE_WORK_ROOT" 'racine de travail'

  if [[ ! -d "$C2ME_RESTORE_WORK_ROOT" ]]; then
    c2me_mkdir_mode "$C2ME_RESTORE_WORK_ROOT" 0700
  else
    c2me_chmod 0700 -- "$C2ME_RESTORE_WORK_ROOT"
  fi

  C2ME_WORK_DIR="$C2ME_RESTORE_WORK_ROOT/$set_id-$(c2me_random_hex8)"
  [[ ! -e "$C2ME_WORK_DIR" ]] || c2me_die "zone de travail déjà existante : $C2ME_WORK_DIR"
  mkdir -- "$C2ME_WORK_DIR"
  c2me_chmod 0700 -- "$C2ME_WORK_DIR"
  c2me_register_cleanup "$C2ME_WORK_DIR"
}

prepare_state_dir() {
  c2me_mkdir_mode "$C2ME_STATE_DIR" 2750
  C2ME_STATE_FILE="$C2ME_STATE_DIR/$set_id/results.env"
  c2me_mkdir_mode "$C2ME_STATE_DIR/$set_id" 2750

  if [[ ! -f "$C2ME_STATE_FILE" ]]; then
    : >"$C2ME_STATE_FILE"
  fi

  c2me_chmod 0640 -- "$C2ME_STATE_FILE"
}

state_set() {
  local key="$1"
  local value="$2"
  printf '%s=%s\n' "$key" "$(printf '%s' "$value" | tr -d '\n\r')" >>"$C2ME_STATE_FILE"
}

assert_archive_safe() {
  local archive="$1"
  local output files dirs bytes expected_files expected_bytes

  if ! output="$("$C2ME_PHP_BIN" "$OPS_DIR/lib/tar-inspect.php" "$archive" 2>&1)"; then
    c2me_die "archive refusée : $output"
  fi

  files="$(printf '%s' "$output" | sed -n 's/.*files=\([0-9]*\).*/\1/p')"
  dirs="$(printf '%s' "$output" | sed -n 's/.*dirs=\([0-9]*\).*/\1/p')"
  bytes="$(printf '%s' "$output" | sed -n 's/.*bytes=\([0-9]*\).*/\1/p')"

  [[ "$files" =~ ^[0-9]+$ && "$dirs" =~ ^[0-9]+$ && "$bytes" =~ ^[0-9]+$ ]] \
    || c2me_die 'inspection de l archive illisible : restauration refusée.'

  expected_files="$(c2me_manifest_summary "$C2ME_SET_DIR/manifest.json" files.file_count)"
  expected_bytes="$(c2me_manifest_summary "$C2ME_SET_DIR/manifest.json" files.total_bytes)"

  [[ "$files" == "$expected_files" ]] \
    || c2me_die "incohérence archive/manifeste : $files fichiers dans l archive, $expected_files annoncés."

  [[ "$bytes" == "$expected_bytes" ]] \
    || c2me_die "incohérence archive/manifeste : $bytes octets de fichiers dans l archive, $expected_bytes annoncés."

  C2ME_ARCHIVE_FILES="$files"
  C2ME_ARCHIVE_BYTES="$bytes"
}

assert_inventory_safe() {
  local inventory="$1"

  c2me_require_file "$inventory" 'inventaire des fichiers'

  if grep -Evq '^[0-9a-f]{64}  (app/private|app/public)/' "$inventory"; then
    c2me_die 'inventaire non conforme : chemin hors périmètre ou format invalide.'
  fi
}

assert_dump_safe() {
  local dump="$1"

  if grep -Eqi '^(CREATE|DROP)[[:space:]]+DATABASE|^USE[[:space:]]' "$dump"; then
    c2me_die 'le dump contient une instruction de base de données interdite (CREATE/DROP DATABASE ou USE).'
  fi
}

artifact_name() {
  local kind="$1"

  awk -v kind="\"$kind\"" '
    /"kind":/ { current = $0 }
    /"name":/ && current ~ kind { gsub(/.*"name": "|".*/, ""); print; exit }
  ' "$C2ME_SET_DIR/manifest.json"
}

artifact_compression() {
  local name="$1"

  case "$name" in
    *.zst.age) printf 'zstd\n' ;;
    *.gz.age) printf 'gzip\n' ;;
    *) c2me_die "extension d artefact non reconnue : $name" ;;
  esac
}

# ---------------------------------------------------------------------------
# Restauration de la base
# ---------------------------------------------------------------------------

count_target_rows() {
  local tables table escaped total=0 count

  tables="$("$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_RESTORE_DB_DEFAULTS_FILE" -N -B "$target_db" \
    -e "SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE' ORDER BY table_name")"

  while IFS= read -r table; do
    [[ -n "$table" ]] || continue
    escaped="${table//\`/\`\`}"
    count="$("$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_RESTORE_DB_DEFAULTS_FILE" -N -B "$target_db" \
      -e "SELECT COUNT(*) FROM \`$escaped\`")"
    [[ "$count" =~ ^[0-9]+$ ]] || c2me_die "comptage impossible pour la table $table."
    total=$((total + count))
  done <<<"$tables"

  printf '%s\n' "$total"
}

restore_database() {
  assert_target_database
  prepare_work_dir
  prepare_state_dir

  local started=$SECONDS
  local name
  name="$(artifact_name database)"
  [[ -n "$name" ]] || c2me_die 'aucun artefact de base dans le manifeste.'
  c2me_require_file "$C2ME_SET_DIR/$name" 'artefact de base'

  c2me_info "déchiffrement de l'artefact de base."
  local plain="$C2ME_WORK_DIR/db.sql"
  c2me_register_cleanup "$plain"

  local compression
  compression="$(artifact_compression "$name")"
  c2me_age_decrypt "$C2ME_SET_DIR/$name" "$C2ME_WORK_DIR/db.payload" "$identity"
  c2me_register_cleanup "$C2ME_WORK_DIR/db.payload"

  c2me_decompress "$C2ME_WORK_DIR/db.payload" "$plain" "$compression"
  rm -f -- "$C2ME_WORK_DIR/db.payload"
  assert_dump_safe "$plain"

  c2me_info "création de la base cible $target_db."
  "$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_RESTORE_DB_DEFAULTS_FILE" \
    -e "CREATE DATABASE \`$target_db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci" \
    || c2me_die "création de la base cible impossible : $target_db"

  c2me_info "import du dump."
  c2me_run "$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_RESTORE_DB_DEFAULTS_FILE" \
    --default-character-set=utf8mb4 "$target_db" <"$plain" \
    || c2me_die 'échec de l import du dump.'

  local charset
  charset="$("$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_RESTORE_DB_DEFAULTS_FILE" -N -B "$target_db" \
    -e 'SELECT @@character_set_database')"
  [[ "$charset" == 'utf8mb4' ]] || c2me_die "charset de la base restaurée inattendu : $charset"

  local expected_tables expected_rows actual_tables actual_rows
  expected_tables="$(c2me_manifest_summary "$C2ME_SET_DIR/manifest.json" database.tables)"
  expected_rows="$(c2me_manifest_summary "$C2ME_SET_DIR/manifest.json" database.rows)"
  actual_tables="$("$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_RESTORE_DB_DEFAULTS_FILE" -N -B "$target_db" \
    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'")"
  actual_rows="$(count_target_rows)"

  [[ "$actual_tables" == "$expected_tables" ]] \
    || c2me_die "nombre de tables restauré ($actual_tables) différent du manifeste ($expected_tables)."
  [[ "$actual_rows" == "$expected_rows" ]] \
    || c2me_die "nombre de lignes restauré ($actual_rows) différent du manifeste ($expected_rows)."

  rm -f -- "$plain"

  state_set TARGET_DB "$target_db"
  state_set DATABASE_STATUS ok
  state_set DATABASE_SECONDS "$((SECONDS - started))"
  state_set DATABASE_TABLES "$actual_tables"
  state_set DATABASE_ROWS "$actual_rows"

  c2me_info "base restaurée et contrôlée : $target_db ($actual_tables tables, $actual_rows lignes)."
  printf 'TARGET_DB=%s\n' "$target_db"
  printf 'DATABASE=ok\n'
}

# ---------------------------------------------------------------------------
# Restauration des fichiers
# ---------------------------------------------------------------------------

apply_permissions() {
  local directory="$1"

  find "$directory" -type d -exec chmod 2770 {} + || c2me_die 'échec du mode des répertoires.'
  find "$directory" -type f -exec chmod 0640 {} + || c2me_die 'échec du mode des fichiers.'

  while IFS= read -r -d '' executable; do
    chmod 0750 -- "$executable" || c2me_die "échec du mode de $executable."
  done < <(find "$directory" -type f -perm -u+x -print0)

  chown -R -- "$C2ME_TARGET_OWNER" "$directory" \
    || c2me_die "remappage d'appartenance impossible vers $C2ME_TARGET_OWNER."
}

assert_final_permissions() {
  local directory="$1"
  local violations

  violations="$(find "$directory" ! -type l -perm -0002 -print)"
  [[ -z "$violations" ]] || c2me_die "permissions trop permissives : $(printf '%s' "$violations" | tr '\n' ' ')"

  violations="$(find "$directory" -type l -print)"
  [[ -z "$violations" ]] || c2me_die "lien symbolique interdit dans la restauration : $(printf '%s' "$violations" | tr '\n' ' ')"

  violations="$(find "$directory" ! -user "$C2ME_TARGET_USER" -print -quit)"
  [[ -z "$violations" ]] || c2me_die "appartenance non remappée : $violations"

  if c2me_setgid_supported; then
    violations="$(find "$directory" -type d ! -perm -2000 -print -quit)"
    [[ -z "$violations" ]] || c2me_die "répertoire sans bit setgid : $violations"
  else
    c2me_warn 'bit setgid non applicable sur cette plateforme : contrôle ignoré (production Linux uniquement).'
  fi
}

restore_files() {
  assert_full_set
  assert_target_directory
  prepare_work_dir
  prepare_state_dir

  local started=$SECONDS
  local name
  name="$(artifact_name files)"
  [[ -n "$name" ]] || c2me_die 'aucun artefact fichiers dans le manifeste.'
  c2me_require_file "$C2ME_SET_DIR/$name" 'artefact fichiers'

  c2me_info "déchiffrement de l'archive des fichiers."
  local archive="$C2ME_WORK_DIR/files.tar"
  local payload="$C2ME_WORK_DIR/files.payload"
  c2me_register_cleanup "$archive"
  c2me_register_cleanup "$payload"

  local compression
  compression="$(artifact_compression "$name")"
  c2me_age_decrypt "$C2ME_SET_DIR/$name" "$payload" "$identity"
  c2me_decompress "$payload" "$archive" "$compression"
  rm -f -- "$payload"

  c2me_require_file "$C2ME_SET_DIR/inventory.sha256" 'inventaire des fichiers'
  assert_archive_safe "$archive"
  assert_inventory_safe "$C2ME_SET_DIR/inventory.sha256"

  c2me_info "création du répertoire cible $target_dir."
  mkdir -- "$target_dir" || c2me_die "création impossible : $target_dir"
  chmod 2750 -- "$target_dir"

  c2me_info 'extraction sans conservation des UID/GID d origine.'
  c2me_run "$C2ME_TAR_BIN" --extract --file "$archive" --directory "$target_dir" \
    --no-same-owner --no-same-permissions \
    || c2me_die 'échec de l extraction de l archive.'

  c2me_info 'vérification de l inventaire (SHA-256).'
  (
    cd "$target_dir"
    sha256sum -c --quiet "$C2ME_SET_DIR/inventory.sha256"
  ) || c2me_die 'inventaire non conforme : restauration refusée.'

  c2me_info "remappage vers $C2ME_TARGET_OWNER et application des modes."
  apply_permissions "$target_dir"
  assert_final_permissions "$target_dir"

  rm -f -- "$archive"

  state_set TARGET_DIR "$target_dir"
  state_set FILES_STATUS ok
  state_set FILES_SECONDS "$((SECONDS - started))"
  state_set FILES_OWNER "$C2ME_TARGET_OWNER"

  c2me_info "fichiers restaurés et contrôlés : $target_dir."
  printf 'TARGET_DIR=%s\n' "$target_dir"
  printf 'FILES=ok\n'
}

# ---------------------------------------------------------------------------
# Rapport
# ---------------------------------------------------------------------------

write_report() {
  assert_set_valid
  mkdir -p -m 2750 -- "$C2ME_REPORTS_DIR"
  c2me_require_dir "$C2ME_REPORTS_DIR" 'répertoire des rapports de restauration'

  local state_file=""
  if [[ -n "${C2ME_STATE_DIR:-}" ]]; then
    state_file="$(find "$C2ME_STATE_DIR/$set_id" -maxdepth 1 -name 'results.env' -print 2>/dev/null | head -n 1 || true)"
  fi

  local status_db='non effectuée'
  local status_files='non effectuée'
  local db_seconds='null'
  local files_seconds='null'
  local target_database='null'
  local target_directory='null'

  if [[ -n "$state_file" && -f "$state_file" ]]; then
    status_db="$(sed -n 's/^DATABASE_STATUS=//p' "$state_file" | tail -n 1)"
    status_files="$(sed -n 's/^FILES_STATUS=//p' "$state_file" | tail -n 1)"

    local value
    value="$(sed -n 's/^DATABASE_SECONDS=//p' "$state_file" | tail -n 1)"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      db_seconds="$value"
    fi

    value="$(sed -n 's/^FILES_SECONDS=//p' "$state_file" | tail -n 1)"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      files_seconds="$value"
    fi

    value="$(sed -n 's/^TARGET_DB=//p' "$state_file" | tail -n 1)"
    if [[ -n "$value" ]]; then
      target_database="\"$value\""
    fi

    value="$(sed -n 's/^TARGET_DIR=//p' "$state_file" | tail -n 1)"
    if [[ -n "$value" ]]; then
      target_directory="\"$value\""
    fi
  fi

  [[ -n "$status_db" ]] || status_db='non effectuée'
  [[ -n "$status_files" ]] || status_files='non effectuée'

  if [[ "$status_db" != 'ok' && "$status_files" != 'ok' ]]; then
    c2me_die 'aucune restauration réussie enregistrée pour ce jeu : rapport refusé.'
  fi

  local generated_at
  generated_at="$(c2me_iso_now)"
  local report="$C2ME_REPORTS_DIR/restore-$set_id-$(date -u '+%Y%m%dT%H%M%SZ')-$(c2me_random_hex8).json"

  cat >"$report" <<JSON
{
  "schema_version": 1,
  "report_type": "restore",
  "backup_set_id": "$set_id",
  "environment": "$C2ME_ENV",
  "generated_at": "$generated_at",
  "operator": "$C2ME_OPERATOR",
  "host": "$C2ME_HOST_ID",
  "target_database": $target_database,
  "target_directory": $target_directory,
  "mechanics": {
    "manifest": "ok",
    "checksums": "ok",
    "database": "$status_db",
    "files": "$status_files",
    "permissions": "$status_files",
    "application": "non effectuée"
  },
  "durations_seconds": {
    "database": $db_seconds,
    "files": $files_seconds
  },
  "application_check": {
    "performed": false,
    "note": "Vérification applicative manuelle requise en localhost (runbook §4.4)."
  },
  "notes": "$(c2me_json_escape "$notes")",
  "integrity": {
    "algorithm": "sha256",
    "signature": "none",
    "description": "Rapport horodaté, haché et chaîné. Détecteur d'altération, non authentifiant."
  }
}
JSON

  local report_sha
  report_sha="$(c2me_sha256 "$report")"
  printf '%s  %s\n' "$report_sha" "$(basename "$report")" >"$report.sha256"

  local chain="$C2ME_LEDGER_DIR/chain.jsonl"
  local previous=""
  if [[ -f "$chain" ]]; then
    previous="$(tail -n 1 "$chain" | sed -n 's/.*"sha256": "\([0-9a-f]\{64\}\)".*/\1/p')"
  fi

  printf '{"report": "%s", "sha256": "%s", "previous_sha256": "%s", "timestamp": "%s"}\n' \
    "$(basename "$report")" "$report_sha" "$previous" "$generated_at" >>"$chain"

  chmod 0640 -- "$report" "$report.sha256" "$chain" 2>/dev/null || true

  printf 'REPORT=%s\n' "$report"
  printf 'REPORT_SHA256=%s\n' "$report_sha"
  printf 'REPORT_SIGNED=false\n'
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$command" in
  verify)
    exec "$OPS_DIR/backup.sh" verify --env "$C2ME_ENV" --set "$set_id"
    ;;
  db)
    assert_set_valid
    assert_identity_file
    c2me_acquire_lock "$C2ME_BACKUP_ROOT/.lock"
    restore_database
    ;;
  files)
    assert_set_valid
    assert_identity_file
    c2me_acquire_lock "$C2ME_BACKUP_ROOT/.lock"
    restore_files
    ;;
  all)
    assert_set_valid
    assert_full_set
    assert_identity_file
    c2me_acquire_lock "$C2ME_BACKUP_ROOT/.lock"
    restore_database
    restore_files
    ;;
  report)
    assert_set_valid
    write_report
    ;;
  unlock)
    ((confirm_stale_lock == 1)) \
      || c2me_die 'la libération d un verrou exige --confirm-stale-lock après vérification manuelle.'
    c2me_release_stale_lock "$C2ME_BACKUP_ROOT/.lock"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    c2me_die "commande inconnue : $command"
    ;;
esac
