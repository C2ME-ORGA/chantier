#!/usr/bin/env bash
#
# Sauvegarde C2ME Chantier — CHAN-98, lot 2.
#
# Voir docs/development/backup-restore.md (règles) et
# docs/development/backup-restore-runbook.md (procédure opérateur).
#
# Aucune sauvegarde n'est créée sans : mode maintenance actif, workers
# vérifiés arrêtés, tâches planifiées confirmées neutralisées, base InnoDB,
# clé privée age absente du serveur et espace disque suffisant.

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
Usage : backup.sh <commande> --env <staging|production> [options]

Commandes :
  preflight              Contrôles sans écrire de sauvegarde
  set                    Jeu complet (base + fichiers), méthode de référence
  db                     Dump de base seul (diagnostic, non restaurable seul ;
                         exige --trigger manual)
  verify                 Vérifie l'intégrité d'un jeu existant
  list                   Liste les jeux et leur statut
  prune                  Applique la rétention (simulation par défaut)
  unlock                 Libère explicitement un verrou orphelin

Options :
  --env <env>                        Environnement cible (obligatoire)
  --set <set-id>                     Jeu concerné (verify)
  --trigger <type>                   scheduled | pre-migration | manual (set, db)
  --confirm-workers-stopped          Déclaration : workers arrêtés et vérifiés
  --confirm-scheduler-disabled       Déclaration : cron neutralisé et vérifié
  --confirm                          Applique réellement la rétention
  --delete-expired                   Supprime les jeux en quarantaine expirés
  --confirm-stale-lock               Confirme la libération d'un verrou orphelin
  --dry-run                          Simulation (prune)
  -h, --help                         Affiche cette aide

Variables principales :
  C2ME_ROOT                  Racine applicative (doit correspondre à l'environnement)
  C2ME_BACKUP_ROOT           Racine de sauvegarde (hors racine applicative)
  C2ME_DB_DEFAULTS_FILE      Fichier d'options MySQL en 0600 (identifiants)
  C2ME_AGE_RECIPIENT_FILE    Clé publique age (défaut : <backup>/keys/recipient.pub)
  C2ME_SUPERVISOR_PROGRAM    Programme Supervisor des workers (facultatif)
  C2ME_COMPRESSION           auto | zstd | gzip
  C2ME_PHP_BIN, C2ME_MYSQL_BIN, C2ME_DB_DUMP_BIN, C2ME_AGE_BIN

Aucun secret ne doit être passé en argument. Aucune migration n'est exécutée.
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
trigger="scheduled"
confirm_workers=0
confirm_scheduler=0
confirm=0
delete_expired=0
dry_run=0
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
    --trigger)
      trigger="${2:-}"
      shift 2
      ;;
    --confirm-workers-stopped)
      confirm_workers=1
      shift
      ;;
    --confirm-scheduler-disabled)
      confirm_scheduler=1
      shift
      ;;
    --confirm)
      confirm=1
      shift
      ;;
    --delete-expired)
      delete_expired=1
      shift
      ;;
    --confirm-stale-lock)
      confirm_stale_lock=1
      shift
      ;;
    --dry-run)
      dry_run=1
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

[[ -n "$env" ]] || c2me_die "l'option --env est obligatoire (staging ou production)."

c2me_resolve_environment "$env"

C2ME_AGE_RECIPIENT_FILE="${C2ME_AGE_RECIPIENT_FILE:-$C2ME_BACKUP_ROOT/keys/recipient.pub}"
C2ME_DB_DEFAULTS_FILE="${C2ME_DB_DEFAULTS_FILE:-}"

# ---------------------------------------------------------------------------
# Contrôles
# ---------------------------------------------------------------------------

require_database_access() {
  c2me_require_file "$C2ME_DB_DEFAULTS_FILE" 'fichier d options MySQL (C2ME_DB_DEFAULTS_FILE)'
  c2me_require_command "$C2ME_MYSQL_BIN" 'client mariadb/mysql'
  c2me_require_command "$C2ME_DB_DUMP_BIN" 'mariadb-dump'
}

sql_scalar() {
  "$C2ME_MYSQL_BIN" --defaults-extra-file="$C2ME_DB_DEFAULTS_FILE" -N -B "$C2ME_DB_NAME" -e "$1"
}

assert_private_key_absent() {
  local found

  found="$(find "$C2ME_BACKUP_ROOT" "$C2ME_ROOT" \
    \( -name 'age-identity*' -o -name '*.agekey' -o -name 'keys.txt' \) \
    -not -path "$C2ME_BACKUP_ROOT/keys/recipient.pub" -print -quit 2>/dev/null || true)"

  if [[ -n "$found" ]]; then
    c2me_die "clé privée potentielle détectée sur le serveur : $found. Retrait obligatoire avant toute sauvegarde."
  fi
}

assert_workers_stopped() {
  if [[ -n "${C2ME_SUPERVISOR_PROGRAM:-}" ]]; then
    if [[ -n "$C2ME_SUPERVISORCTL_BIN" && -x "$C2ME_SUPERVISORCTL_BIN" ]]; then
      local status
      status="$("$C2ME_SUPERVISORCTL_BIN" status "$C2ME_SUPERVISOR_PROGRAM" 2>/dev/null || true)"

      if [[ "$status" == *RUNNING* || "$status" == *STARTING* ]]; then
        c2me_die "le programme Supervisor $C2ME_SUPERVISOR_PROGRAM est encore actif : $status"
      fi
    else
      c2me_die 'C2ME_SUPERVISOR_PROGRAM est défini mais supervisorctl est introuvable.'
    fi
  elif ((confirm_workers == 0)); then
    c2me_die 'aucun programme Supervisor configuré : fournir --confirm-workers-stopped après vérification.'
  fi

  if command -v pgrep >/dev/null 2>&1; then
    if pgrep -af 'queue:work|queue:listen|horizon' 2>/dev/null | grep -F -- "$C2ME_ROOT" >/dev/null 2>&1; then
      c2me_die "un worker de file d'attente semble encore actif pour $C2ME_ROOT."
    fi
  fi
}

assert_scheduler_disabled() {
  ((confirm_scheduler == 1)) \
    || c2me_die 'fournir --confirm-scheduler-disabled après neutralisation vérifiée du cron schedule:run.'

  if command -v pgrep >/dev/null 2>&1; then
    if pgrep -af 'schedule:run' 2>/dev/null | grep -F -- "$C2ME_ROOT" >/dev/null 2>&1; then
      c2me_die "une tâche schedule:run semble encore active pour $C2ME_ROOT."
    fi
  fi
}

assert_maintenance_mode() {
  [[ -f "$C2ME_MAINTENANCE_MARKER" ]] \
    || c2me_die "mode maintenance inactif : marqueur absent ($C2ME_MAINTENANCE_MARKER)."
}

assert_database_innodb() {
  local non_innodb

  non_innodb="$(sql_scalar "SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND engine <> 'InnoDB' ORDER BY table_name")"

  if [[ -n "$non_innodb" ]]; then
    c2me_die "tables non InnoDB détectées, dump à chaud non cohérent : $(printf '%s' "$non_innodb" | tr '\n' ' ')"
  fi
}

assert_database_shape() {
  local tables migrations_count

  tables="$(sql_scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'")"
  [[ "$tables" =~ ^[0-9]+$ ]] || c2me_die 'impossible de compter les tables de la base.'
  ((tables >= 1)) || c2me_die 'la base ne contient aucune table : sauvegarde refusée.'

  migrations_count="$(sql_scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'migrations'")"
  [[ "$migrations_count" == '1' ]] || c2me_die 'la table migrations est absente : sauvegarde refusée.'

  C2ME_DB_TABLES="$tables"
}

assert_no_symlinks_or_specials() {
  local violations

  if [[ ! -d "$C2ME_STORAGE_ROOT" ]]; then
    c2me_die "répertoire de stockage introuvable : $C2ME_STORAGE_ROOT"
  fi

  violations="$(find "$C2ME_STORAGE_ROOT/app/private" "$C2ME_STORAGE_ROOT/app/public" \
    \( -type l -o -type p -o -type s -o -type b -o -type c \) -print 2>/dev/null || true)"

  if [[ -n "$violations" ]]; then
    c2me_die "lien symbolique ou fichier spécial dans les données métier : $(printf '%s' "$violations" | tr '\n' ' ')"
  fi
}

assert_no_newline_filenames() {
  local violation

  violation="$(find "$C2ME_STORAGE_ROOT/app/private" "$C2ME_STORAGE_ROOT/app/public" \
    -name $'*\n*' -print -quit 2>/dev/null || true)"

  if [[ -n "$violation" ]]; then
    c2me_die 'un nom de fichier contient un saut de ligne : sauvegarde refusée.'
  fi
}

preflight_common() {
  c2me_require_dir "$C2ME_ROOT" 'racine applicative'
  c2me_require_dir "$C2ME_STORAGE_ROOT" 'stockage partagé'
  c2me_require_dir "$C2ME_BACKUP_ROOT" 'racine de sauvegarde (à préparer par l administrateur)'

  [[ -w "$C2ME_BACKUP_ROOT" ]] || c2me_die "racine de sauvegarde non inscriptible : $C2ME_BACKUP_ROOT"
  [[ -d "$C2ME_BACKUP_ROOT/incoming" ]] || c2me_die "répertoire incoming absent : $C2ME_BACKUP_ROOT/incoming"
  [[ -d "$C2ME_BACKUP_ROOT/sets" ]] || c2me_die "répertoire sets absent : $C2ME_BACKUP_ROOT/sets"

  c2me_require_command "$C2ME_PHP_BIN" 'PHP CLI'
  c2me_require_command "$C2ME_TAR_BIN" 'tar'
  c2me_require_command "$(command -v sha256sum || true)" 'sha256sum'
  c2me_require_command "$(command -v find || true)" 'find'
  c2me_require_file "$OPS_MANIFEST_TOOL" 'validateur de manifeste'
  c2me_require_file "$C2ME_AGE_RECIPIENT_FILE" 'clé publique age (C2ME_AGE_RECIPIENT_FILE)'

  assert_private_key_absent

  c2me_select_compressor

  local recipient
  recipient="$(c2me_age_recipient "$C2ME_AGE_RECIPIENT_FILE")"
  [[ "$recipient" == age1* ]] || c2me_die "le fichier destinataire ne contient pas une clé age valide : $C2ME_AGE_RECIPIENT_FILE"
  C2ME_AGE_RECIPIENT="$recipient"
}

preflight_backup() {
  preflight_common

  if [[ "$command" != 'db' ]]; then
    assert_no_symlinks_or_specials
    assert_no_newline_filenames
  fi

  require_database_access
  assert_database_shape
  assert_database_innodb

  local storage_kb db_kb required_kb
  storage_kb="$(du -sk -- "$C2ME_STORAGE_ROOT/app" 2>/dev/null | awk '{print $1}')"
  db_kb="$(sql_scalar 'SELECT COALESCE(SUM(data_length + index_length), 0) DIV 1024 FROM information_schema.tables WHERE table_schema = DATABASE()')"
  [[ "$storage_kb" =~ ^[0-9]+$ ]] || storage_kb=0
  [[ "$db_kb" =~ ^[0-9]+$ ]] || db_kb=0
  required_kb=$(((storage_kb + db_kb) * 5 / 2))
  ((required_kb > 10240)) || required_kb=10240

  c2me_require_free_space "$C2ME_BACKUP_ROOT" "$required_kb"

  if [[ -f "$C2ME_MAINTENANCE_MARKER" ]]; then
    c2me_info 'mode maintenance détecté.'
  else
    c2me_warn 'mode maintenance non actif : la sauvegarde sera refusée tant qu il ne l est pas.'
  fi
}

assert_consistency_window() {
  assert_maintenance_mode
  assert_workers_stopped
  assert_scheduler_disabled
}

# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------

dump_options() {
  C2ME_DUMP_OPTIONS=(
    --single-transaction
    --quick
    --routines
    --events
    --triggers
    --default-character-set=utf8mb4
    --hex-blob
    --skip-add-locks
  )

  if "$C2ME_DB_DUMP_BIN" --help 2>&1 | grep -q -- '--no-tablespaces'; then
    C2ME_DUMP_OPTIONS+=(--no-tablespaces)
  fi
}

dump_options_hash() {
  printf '%s\n' "${C2ME_DUMP_OPTIONS[@]}" | sha256sum | awk '{print $1}'
}

count_rows_exact() {
  local tables table escaped total=0 count

  tables="$(sql_scalar "SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE' ORDER BY table_name")"

  while IFS= read -r table; do
    [[ -n "$table" ]] || continue
    escaped="${table//\`/\`\`}"
    count="$(sql_scalar "SELECT COUNT(*) FROM \`$escaped\`")"
    [[ "$count" =~ ^[0-9]+$ ]] || c2me_die "comptage impossible pour la table $table."
    total=$((total + count))
  done <<<"$tables"

  printf '%s\n' "$total"
}

inventory_build() {
  local suffix="$1"
  local roots=()

  (
    cd "$C2ME_STORAGE_ROOT"

    if [[ -d app/private ]]; then
      roots+=(app/private)
    fi

    if [[ -d app/public ]]; then
      roots+=(app/public)
    fi

    : >"$C2ME_WORK_DIR/paths.$suffix"
    : >"$C2ME_WORK_DIR/inventory.meta.$suffix"
    : >"$C2ME_WORK_DIR/inventory.sha256.$suffix"

    if ((${#roots[@]} == 0)); then
      return 0
    fi

    find "${roots[@]}" -print 2>/dev/null | LC_ALL=C sort >"$C2ME_WORK_DIR/paths.$suffix"
    find "${roots[@]}" -type f -print 2>/dev/null | LC_ALL=C sort >"$C2ME_WORK_DIR/files.$suffix"
    find "${roots[@]}" -printf '%p\t%y\t%s\t%T@\t%m\n' 2>/dev/null \
      | LC_ALL=C sort >"$C2ME_WORK_DIR/inventory.meta.$suffix"

    tr '\n' '\0' <"$C2ME_WORK_DIR/files.$suffix" \
      | xargs -0 -r sha256sum -- 2>/dev/null \
      | sed -E 's/^([0-9a-f]{64}) [ *]/\1  /' \
      | LC_ALL=C sort -k2 >"$C2ME_WORK_DIR/inventory.sha256.$suffix"
  )
}

inventory_compare() {
  cmp -s "$C2ME_WORK_DIR/inventory.meta.A" "$C2ME_WORK_DIR/inventory.meta.B" \
    || c2me_die 'des fichiers ont changé pendant la sauvegarde (métadonnées). Jeu invalide.'
  cmp -s "$C2ME_WORK_DIR/inventory.sha256.A" "$C2ME_WORK_DIR/inventory.sha256.B" \
    || c2me_die 'des fichiers ont changé pendant la sauvegarde (contenu). Jeu invalide.'
}

tar_feature_supported() {
  "$C2ME_TAR_BIN" --help 2>/dev/null | grep -q -- "$1"
}

tar_create_files_archive() {
  local archive="$1"
  local list="$C2ME_WORK_DIR/paths.A"
  local flags=(--create --no-recursion --numeric-owner)

  if tar_feature_supported '--verbatim-files-from'; then
    flags+=(--verbatim-files-from)
  fi

  if tar_feature_supported '--one-file-system'; then
    flags+=(--one-file-system)
  fi

  if tar_feature_supported '--acls'; then
    flags+=(--acls)
  fi

  if tar_feature_supported '--xattrs'; then
    flags+=(--xattrs)
  fi

  flags+=(--file "$archive" --files-from "$list")

  (cd "$C2ME_STORAGE_ROOT" && "$C2ME_TAR_BIN" "${flags[@]}")
}

seal_artifact() {
  local plain="$1"
  local destination="$2"

  c2me_require_file "$plain" 'fichier à sceller'

  local compressed="$plain.$C2ME_COMPRESSION_EXT"
  c2me_register_cleanup "$compressed"

  c2me_compress "$plain" "$compressed" \
    || c2me_die "échec de la compression de $plain."

  c2me_test_compression "$compressed" \
    || c2me_die "archive compressée invalide : $compressed."

  c2me_age_encrypt "$compressed" "$destination" "$C2ME_AGE_RECIPIENT_FILE"

  rm -f -- "$plain" "$compressed"

  [[ -s "$destination" ]] || c2me_die "artefact chiffré vide : $destination"
}

write_manifest() {
  local manifest="$1"
  local files_block="$2"
  local create_alias="$3"

  local started finished downtime
  started="$(c2me_manifest_summary_timestamp "$C2ME_CONSISTENCY_STARTED")"
  finished="$(c2me_manifest_summary_timestamp "$C2ME_CONSISTENCY_FINISHED")"
  downtime=$((finished - started))
  ((downtime >= 0)) || downtime=0

  local delete_after
  delete_after="$(date -u -d "+${C2ME_RETENTION_DAILY_DAYS} days" '+%Y-%m-%dT%H:%M:%SZ')"

  cat >"$manifest" <<JSON
{
  "schema_version": 1,
  "backup_set_id": "$C2ME_SET_ID",
  "environment": "$C2ME_ENV",
  "scope": "$C2ME_SCOPE",
  "restorable_as_complete": $(if [[ "$C2ME_SCOPE" == 'full' ]]; then printf 'true'; else printf 'false'; fi),
  "status": "complete",
  "created_at": "$C2ME_CREATED_AT",
  "completed_at": "$(c2me_iso_now)",
  "trigger": "$trigger",
  "consistency": {
    "mode": "maintenance",
    "maintenance_marker": true,
    "workers_verified": true,
    "scheduler_verified": true,
    "file_changes_detected": false,
    "started_at": "$C2ME_CONSISTENCY_STARTED",
    "finished_at": "$C2ME_CONSISTENCY_FINISHED",
    "downtime_seconds": $downtime
  },
  "release": {
    "version": "$C2ME_RELEASE_VERSION",
    "commit_sha": "$C2ME_RELEASE_COMMIT",
    "tree_sha": $C2ME_RELEASE_TREE
  },
  "database": {
    "name": "$C2ME_DB_NAME",
    "server_version": "$C2ME_DB_SERVER_VERSION",
    "tool": "mariadb-dump",
    "tool_version": "$C2ME_DUMP_TOOL_VERSION",
    "options_sha256": "$C2ME_DUMP_OPTIONS_HASH",
    "tables": $C2ME_DB_TABLES,
    "rows": $C2ME_DB_ROWS,
    "non_innodb_tables": []
  },
$files_block
  "artifacts": [
    {
      "kind": "database",
      "name": "$C2ME_DB_ARTIFACT",
      "bytes": $C2ME_DB_BYTES,
      "sha256": "$C2ME_DB_SHA256",
      "compression": "$C2ME_COMPRESSION_TOOL",
      "encryption": {
        "tool": "age",
        "recipient": "$C2ME_AGE_RECIPIENT"
      }
    }$(if [[ "$C2ME_SCOPE" == 'full' ]]; then printf ',\n    {\n      "kind": "files",\n      "name": "%s",\n      "bytes": %s,\n      "sha256": "%s",\n      "compression": "%s",\n      "encryption": {\n        "tool": "age",\n        "recipient": "%s"\n      }\n    }' "$C2ME_FILES_ARTIFACT" "$C2ME_FILES_BYTES" "$C2ME_FILES_SHA256" "$C2ME_COMPRESSION_TOOL" "$C2ME_AGE_RECIPIENT"; fi)
  ],
  "retention": {
    "class": "$create_alias",
    "delete_after": "$delete_after"
  },
  "host": {
    "name": "$C2ME_HOST_ID",
    "operator": "$C2ME_OPERATOR"
  }
}
JSON
}

c2me_manifest_summary_timestamp() {
  date -u -d "$1" '+%s'
}

create_set() {
  local scope="$1"

  assert_consistency_window

  C2ME_SCOPE="$scope"
  C2ME_CREATED_AT="$(c2me_iso_now)"
  C2ME_SET_ID="set-$C2ME_ENV-$(c2me_iso_compact)-$(c2me_random_hex8)"
  C2ME_WORK_DIR="$C2ME_BACKUP_ROOT/incoming/$C2ME_SET_ID"

  [[ "$C2ME_SET_ID" =~ ^set-(staging|production)-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$ ]] \
    || c2me_die "identifiant de jeu invalide : $C2ME_SET_ID"

  [[ ! -e "$C2ME_WORK_DIR" ]] || c2me_die "un jeu portant cet identifiant existe déjà : $C2ME_SET_ID"
  [[ ! -e "$C2ME_BACKUP_ROOT/sets/$C2ME_SET_ID" ]] || c2me_die "jeu déjà présent dans sets/ : $C2ME_SET_ID"

  mkdir -- "$C2ME_WORK_DIR"
  c2me_chmod 0700 -- "$C2ME_WORK_DIR"
  c2me_register_cleanup "$C2ME_WORK_DIR"

  C2ME_CONSISTENCY_STARTED="$(c2me_iso_now)"

  c2me_info "jeu $C2ME_SET_ID : collecte des métadonnées."

  C2ME_RELEASE_VERSION="$(c2me_release_value version unknown)"
  [[ "$C2ME_RELEASE_VERSION" =~ ^(v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?|unknown)$ ]] || C2ME_RELEASE_VERSION='unknown'

  local commit
  commit="$(c2me_release_value commit_sha unknown)"
  if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    commit='unknown'
  fi
  C2ME_RELEASE_COMMIT="$commit"

  if [[ "$commit" == 'unknown' ]]; then
    C2ME_RELEASE_TREE='null'
    C2ME_COMMIT_SHORT='unknown'
  else
    C2ME_COMMIT_SHORT="${commit:0:7}"
    local tree
    tree="$(c2me_release_value tree_sha '')"
    if [[ "$tree" =~ ^[0-9a-f]{40}$ ]]; then
      C2ME_RELEASE_TREE="\"$tree\""
    else
      C2ME_RELEASE_TREE='null'
    fi
  fi

  C2ME_DB_SERVER_VERSION="$(sql_scalar 'SELECT VERSION()')"
  C2ME_DUMP_TOOL_VERSION="$("$C2ME_DB_DUMP_BIN" --version 2>/dev/null | head -n 1 | tr -cd 'A-Za-z0-9._+-')"
  [[ -n "$C2ME_DUMP_TOOL_VERSION" ]] || C2ME_DUMP_TOOL_VERSION='unknown'

  dump_options
  C2ME_DUMP_OPTIONS_HASH="$(dump_options_hash)"
  C2ME_DB_ROWS="$(count_rows_exact)"

  local timestamp
  timestamp="$(printf '%s' "$C2ME_SET_ID" | sed -E 's/^set-(staging|production)-([0-9]{8}T[0-9]{6}Z)-[0-9a-f]{8}$/\2/')"

  C2ME_DB_ARTIFACT="db-$C2ME_ENV-$timestamp-$C2ME_RELEASE_VERSION-$C2ME_COMMIT_SHORT-$trigger.sql.$C2ME_COMPRESSION_EXT.age"
  C2ME_FILES_ARTIFACT="files-$C2ME_ENV-$timestamp-$C2ME_RELEASE_VERSION-$C2ME_COMMIT_SHORT-$trigger.tar.$C2ME_COMPRESSION_EXT.age"

  c2me_info "dump de la base $C2ME_DB_NAME."
  local dump_plain="$C2ME_WORK_DIR/db.sql"
  c2me_register_cleanup "$dump_plain"

  if ! "$C2ME_DB_DUMP_BIN" --defaults-extra-file="$C2ME_DB_DEFAULTS_FILE" \
    "${C2ME_DUMP_OPTIONS[@]}" "$C2ME_DB_NAME" >"$dump_plain"; then
    c2me_die 'échec du dump de la base.'
  fi

  [[ -s "$dump_plain" ]] || c2me_die 'dump de base vide : sauvegarde refusée.'

  seal_artifact "$dump_plain" "$C2ME_WORK_DIR/$C2ME_DB_ARTIFACT"
  C2ME_DB_SHA256="$(c2me_sha256 "$C2ME_WORK_DIR/$C2ME_DB_ARTIFACT")"
  C2ME_DB_BYTES="$(c2me_file_bytes "$C2ME_WORK_DIR/$C2ME_DB_ARTIFACT")"

  local files_block='  "files": null,'

  if [[ "$scope" == 'full' ]]; then
    c2me_info 'inventaire des fichiers (état A).'
    inventory_build A

    local file_count
    file_count="$(grep -c . "$C2ME_WORK_DIR/inventory.meta.A" || true)"
    [[ "$file_count" =~ ^[0-9]+$ ]] || file_count=0

    c2me_info "archivage de $file_count entrées."
    local files_plain="$C2ME_WORK_DIR/files.tar"
    c2me_register_cleanup "$files_plain"

    tar_create_files_archive "$files_plain" || c2me_die 'échec de création de l archive des fichiers.'

    local archived_count
    archived_count="$("$C2ME_TAR_BIN" -tf "$files_plain" | grep -c . || true)"
    [[ "$archived_count" == "$file_count" ]] \
      || c2me_die "incohérence archive/inventaire : $archived_count entrées archivées, $file_count inventoriées."

    c2me_info 'inventaire des fichiers (état B).'
    inventory_build B
    inventory_compare

    local total_bytes
    total_bytes="$(awk -F'\t' '$2 == "f" {sum += $3} END {print sum + 0}' "$C2ME_WORK_DIR/inventory.meta.A")"
    [[ "$total_bytes" =~ ^[0-9]+$ ]] || total_bytes=0

    cp -- "$C2ME_WORK_DIR/inventory.sha256.A" "$C2ME_WORK_DIR/inventory.sha256"
    cp -- "$C2ME_WORK_DIR/inventory.meta.A" "$C2ME_WORK_DIR/inventory.meta"

    seal_artifact "$files_plain" "$C2ME_WORK_DIR/$C2ME_FILES_ARTIFACT"
    C2ME_FILES_SHA256="$(c2me_sha256 "$C2ME_WORK_DIR/$C2ME_FILES_ARTIFACT")"
    C2ME_FILES_BYTES="$(c2me_file_bytes "$C2ME_WORK_DIR/$C2ME_FILES_ARTIFACT")"

    C2ME_INVENTORY_SHA256="$(c2me_sha256 "$C2ME_WORK_DIR/inventory.sha256")"
    local file_count_value
    file_count_value="$(awk -F'\t' '$2 == "f" {count++} END {print count + 0}' "$C2ME_WORK_DIR/inventory.meta")"
    [[ "$file_count_value" =~ ^[0-9]+$ ]] || file_count_value=0

    files_block=$(cat <<JSON
  "files": {
    "included_roots": ["app/private", "app/public"],
    "exclusions": ["framework/", "logs/", "*.part", "*.partial"],
    "file_count": $file_count_value,
    "total_bytes": $total_bytes,
    "inventory_sha256": "$C2ME_INVENTORY_SHA256"
  },
JSON
    )
  fi

  C2ME_CONSISTENCY_FINISHED="$(c2me_iso_now)"

  local retention_class='daily'
  case "$trigger" in
    pre-migration) retention_class='pre-migration' ;;
    manual) retention_class='manual' ;;
    pre-restore) retention_class='manual' ;;
  esac

  local manifest="$C2ME_WORK_DIR/manifest.json"
  write_manifest "$manifest" "$files_block" "$retention_class"

  c2me_info 'validation du manifeste.'
  c2me_manifest_validate "$manifest" || c2me_die 'manifeste invalide : jeu non promu.'

  c2me_sha256 "$manifest" >"$manifest.sha256"

  (
    cd "$C2ME_WORK_DIR"
    sha256sum -- "$C2ME_DB_ARTIFACT" >SHA256SUMS
    if [[ "$scope" == 'full' ]]; then
      sha256sum -- "$C2ME_FILES_ARTIFACT" >>SHA256SUMS
      sha256sum -- inventory.sha256 inventory.meta >>SHA256SUMS
    fi
    sha256sum -- manifest.json >>SHA256SUMS
  )

  chmod 0640 -- "$C2ME_WORK_DIR"/* 2>/dev/null || true
  chmod 2750 -- "$C2ME_WORK_DIR"

  if [[ ! -e "$C2ME_BACKUP_ROOT/sets/$C2ME_SET_ID" ]]; then
    mv -- "$C2ME_WORK_DIR" "$C2ME_BACKUP_ROOT/sets/$C2ME_SET_ID"
  else
    c2me_die "jeu déjà présent : $C2ME_SET_ID"
  fi

  c2me_info "jeu complet créé : $C2ME_BACKUP_ROOT/sets/$C2ME_SET_ID"
  printf 'SET_ID=%s\n' "$C2ME_SET_ID"
  printf 'MANIFEST=%s\n' "$C2ME_BACKUP_ROOT/sets/$C2ME_SET_ID/manifest.json"
  printf 'SCOPE=%s\n' "$scope"
}

# ---------------------------------------------------------------------------
# Vérification, liste, rétention
# ---------------------------------------------------------------------------

resolve_set_dir() {
  [[ -n "$set_id" ]] || c2me_die 'l option --set est obligatoire.'
  [[ "$set_id" =~ ^set-(staging|production)-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$ ]] \
    || c2me_die "identifiant de jeu invalide : $set_id"

  C2ME_SET_DIR="$C2ME_BACKUP_ROOT/sets/$set_id"
  c2me_require_dir "$C2ME_SET_DIR" 'jeu de sauvegarde'

  [[ "$C2ME_SET_DIR" != *".."* ]] || c2me_die 'chemin de jeu invalide.'
}

verify_set() {
  resolve_set_dir

  local manifest="$C2ME_SET_DIR/manifest.json"
  c2me_require_file "$manifest" 'manifeste'

  c2me_manifest_validate "$manifest" || c2me_die 'manifeste invalide.'

  local expected actual
  expected="$(cat "$manifest.sha256" 2>/dev/null | awk '{print $1}')"
  actual="$(c2me_sha256 "$manifest")"
  [[ "$expected" == "$actual" ]] || c2me_die 'le checksum du manifeste ne concorde pas : jeu altéré.'

  (
    cd "$C2ME_SET_DIR"
    sha256sum -c --quiet SHA256SUMS
  ) || c2me_die 'un artefact ne correspond pas à SHA256SUMS : jeu altéré.'

  local env_of_set
  env_of_set="$(c2me_manifest_summary "$manifest" environment)"
  [[ "$env_of_set" == "$C2ME_ENV" ]] || c2me_die "le jeu appartient à l environnement $env_of_set, pas à $C2ME_ENV."

  local status
  status="$(c2me_manifest_summary "$manifest" status)"
  [[ "$status" == 'complete' ]] || c2me_die "le jeu n'est pas complet (status=$status)."

  local name
  for name in $(sed -n 's/.*"name": "\(\(db\|files\)-[^"]*\)".*/\1/p' "$manifest"); do
    [[ -f "$C2ME_SET_DIR/$name" ]] || c2me_die "artefact absent du jeu : $name"
  done

  printf 'SET_ID=%s\n' "$set_id"
  printf 'VERIFY=ok\n'
}

list_sets() {
  local dir count=0
  local sets_dir="$C2ME_BACKUP_ROOT/sets"

  c2me_require_dir "$sets_dir" 'répertoire sets'

  for dir in "$sets_dir"/set-*; do
    [[ -d "$dir" ]] || continue
    count=$((count + 1))

    local created scope status
    created="$(c2me_manifest_summary "$dir/manifest.json" created_at 2>/dev/null || printf 'inconnu')"
    scope="$(c2me_manifest_summary "$dir/manifest.json" scope 2>/dev/null || printf 'inconnu')"
    status="$(c2me_manifest_summary "$dir/manifest.json" status 2>/dev/null || printf 'inconnu')"

    printf '%s\t%s\t%s\t%s\n' "$(basename "$dir")" "$created" "$scope" "$status"
  done

  printf 'TOTAL=%s\n' "$count"
}

prune_sets() {
  local sets_dir="$C2ME_BACKUP_ROOT/sets"
  local expired_dir="$C2ME_BACKUP_ROOT/expired"
  local newest="" dir

  c2me_require_dir "$sets_dir" 'répertoire sets'
  c2me_require_dir "$expired_dir" 'répertoire expired'

  for dir in "$sets_dir"/set-*; do
    if [[ -d "$dir" ]]; then
      newest="$dir"
    fi
  done

  for dir in "$sets_dir"/set-*; do
    [[ -d "$dir" ]] || continue

    if [[ "$dir" == "$newest" ]]; then
      c2me_info "conservé (jeu le plus récent) : $(basename "$dir")"
      continue
    fi

    local manifest="$dir/manifest.json"
    local created trigger created_ts age_days day
    created="$(c2me_manifest_summary "$manifest" created_at 2>/dev/null || true)"
    trigger="$(c2me_manifest_summary "$manifest" trigger 2>/dev/null || true)"

    if [[ -z "$created" ]]; then
      c2me_warn "jeu sans manifeste lisible, conservé : $(basename "$dir")"
      continue
    fi

    if ! created_ts="$(date -u -d "$created" '+%s' 2>/dev/null)"; then
      c2me_warn "date de création illisible, jeu conservé : $(basename "$dir")"
      continue
    fi

    age_days=$((( $(date -u '+%s') - created_ts ) / 86400))
    day="$(date -u -d "$created" '+%d' 2>/dev/null || printf '01')"

    if [[ "$trigger" == 'pre-migration' ]]; then
      c2me_info "conservé (jeu pre-migration, clôture manuelle) : $(basename "$dir")"
      continue
    fi

    if [[ "$day" == '01' ]] && ((age_days <= C2ME_RETENTION_MONTHLY_DAYS)); then
      c2me_info "conservé (rétention mensuelle) : $(basename "$dir")"
      continue
    fi

    if ((age_days <= C2ME_RETENTION_DAILY_DAYS)); then
      c2me_info "conservé (rétention quotidienne) : $(basename "$dir")"
      continue
    fi

    if grep -rqs -- "$(basename "$dir")" "$C2ME_BACKUP_ROOT/ledger/restore-reports" 2>/dev/null; then
      c2me_info "conservé (preuve de restauration) : $(basename "$dir")"
      continue
    fi

    if ((dry_run == 1)) || ((confirm == 0)); then
      printf 'EXPIRER(SansConfirmation)=%s\n' "$(basename "$dir")"
      continue
    fi

    [[ ! -e "$expired_dir/$(basename "$dir")" ]] || c2me_die "conflit en quarantaine : $(basename "$dir")"
    mv -- "$dir" "$expired_dir/$(basename "$dir")"
    c2me_info "déplacé en quarantaine : $(basename "$dir")"
  done

  if ((delete_expired == 1)); then
    if ((confirm == 0 || dry_run == 1)); then
      printf 'SUPPRESSION(Sans confirmation)=différée\n'
      return 0
    fi

    for dir in "$expired_dir"/set-*; do
      [[ -d "$dir" ]] || continue

      if grep -rqs -- "$(basename "$dir")" "$C2ME_BACKUP_ROOT/ledger/restore-reports" 2>/dev/null; then
        c2me_info "conservé (preuve de restauration) : $(basename "$dir")"
        continue
      fi

      if [[ -n "$(find "$dir" -maxdepth 0 -mtime +"$C2ME_QUARANTINE_DAYS" -print 2>/dev/null)" ]]; then
        rm -rf -- "$dir"
        c2me_info "supprimé après quarantaine : $(basename "$dir")"
      fi
    done
  fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$command" in
  preflight)
    preflight_backup
    printf 'PREFLIGHT=ok\n'
    ;;
  set)
    [[ "$trigger" =~ ^(scheduled|pre-migration|manual|pre-restore)$ ]] \
      || c2me_die "déclencheur invalide : $trigger"
    preflight_backup
    c2me_acquire_lock "$C2ME_BACKUP_ROOT/.lock"
    create_set full
    ;;
  db)
    [[ "$trigger" == 'manual' ]] \
      || c2me_die 'le dump de base seul exige --trigger manual : il n est jamais une sauvegarde complète.'
    preflight_backup
    c2me_acquire_lock "$C2ME_BACKUP_ROOT/.lock"
    create_set database-only
    ;;
  verify)
    c2me_acquire_lock "$C2ME_BACKUP_ROOT/.lock"
    verify_set
    ;;
  list)
    list_sets
    ;;
  prune)
    c2me_acquire_lock "$C2ME_BACKUP_ROOT/.lock"
    prune_sets
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
