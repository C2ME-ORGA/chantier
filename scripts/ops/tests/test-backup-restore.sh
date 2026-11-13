#!/usr/bin/env bash
#
# Tests locaux des scripts d'exploitation CHAN-98 (lot 2).
#
# Aucune connexion MariaDB, aucun chiffrement réel, aucune écriture hors du
# bac à sable créé par ce script. Les outils mariadb-dump, mariadb et age sont
# remplacés par des doubles de test.
#
# Exécution : bash scripts/ops/tests/test-backup-restore.sh

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ops_dir="$project_root/scripts/ops"
work_dir="$(mktemp -d)"
sandbox="$work_dir/sandbox"
root_name="chantier-staging.c2me.ovh"
root="$sandbox/$root_name"
backup_root="$sandbox/backups"
fake_bin="$work_dir/bin"

passed=0
failed=0

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
  printf 'SKIP: %s\n' "$*" >&2
}

assert_ok() {
  local label="$1"
  shift

  if "$@"; then
    pass
  else
    fail "$label"
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

assert_file_exists() {
  local path="$1"
  local label="$2"

  if [[ -f "$path" ]]; then
    pass
  else
    fail "$label : fichier absent $path."
  fi
}

assert_dir_absent() {
  local path="$1"
  local label="$2"

  if [[ ! -e "$path" ]]; then
    pass
  else
    fail "$label : chemin encore présent $path."
  fi
}

# ---------------------------------------------------------------------------
# Bac à sable
# ---------------------------------------------------------------------------

mkdir -p "$root/shared/storage/app/private/sub" \
  "$root/shared/storage/app/public" \
  "$root/shared/storage/framework/cache" \
  "$root/shared/storage/logs" \
  "$root/current" \
  "$backup_root/incoming" \
  "$backup_root/sets" \
  "$backup_root/expired" \
  "$backup_root/ledger/restore-reports" \
  "$backup_root/ledger/restore-state" \
  "$backup_root/keys" \
  "$fake_bin"

printf 'documents privés\n' >"$root/shared/storage/app/private/contrat.txt"
printf 'piece jointe\n' >"$root/shared/storage/app/private/sub/plan.pdf"
printf 'image publique\n' >"$root/shared/storage/app/public/photo.txt"
printf 'journal exclu\n' >"$root/shared/storage/logs/laravel.log"
printf 'cache exclu\n' >"$root/shared/storage/framework/cache/data.txt"
: >"$root/shared/storage/framework/down"

cat >"$root/current/release.json" <<'JSON'
{
    "environment": "staging",
    "version": "v0.1.0",
    "commit_sha": "8742e19ba18a48e3297792a7ee4058e0ad71497a",
    "tree_sha": "1111111111111111111111111111111111111111"
}
JSON

printf 'age1%s\n' "$(head -c 58 /dev/zero | tr '\0' 'q')" >"$backup_root/keys/recipient.pub"
printf '[client]\nuser=fake\npassword=fake\n' >"$work_dir/my.cnf"
chmod 0600 "$work_dir/my.cnf"
printf 'AGE-SECRET-KEY-FAKE\n' >"$work_dir/id.age"
chmod 0600 "$work_dir/id.age"

# Doubles de test -----------------------------------------------------------

cat >"$fake_bin/mariadb-dump" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "mariadb-dump  Ver 10.11.14-MariaDB"
  exit 0
fi
if [[ "${1:-}" == "--help" ]]; then
  printf '%s\n' '  --single-transaction' '  --quick' '  --routines' '  --events' '  --triggers' '  --no-tablespaces'
  exit 0
fi
if [[ -n "${FAKE_DUMP_SLEEP:-}" ]]; then
  sleep "$FAKE_DUMP_SLEEP"
fi
if [[ -n "${FAKE_DUMP_BLOCK:-}" ]]; then
  printf '%s\n' "$$" >"${FAKE_DUMP_BLOCK_PID:-/dev/null}"
  trap 'printf stopped >"${FAKE_DUMP_BLOCK_STOP:-/dev/null}"; exit 143' TERM
  while :; do
    sleep 1
  done
fi
echo "-- dump factice"
echo "CREATE TABLE users (id int);"
echo "INSERT INTO users VALUES (1);"
FAKE

cat >"$fake_bin/mariadb" <<'FAKE'
#!/usr/bin/env bash
query=""
has_query=0
args=("$@")

for ((i = 0; i < ${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "-e" ]]; then
    query="${args[$((i + 1))]:-}"
    has_query=1
  fi
done

if ((has_query == 0)); then
  if [[ -n "${FAKE_IMPORT_LOG:-}" ]]; then
    cat >"$FAKE_IMPORT_LOG"
  else
    cat >/dev/null
  fi
  exit 0
fi

case "$query" in
  *CREATE\ DATABASE*)
    exit 0
    ;;
  *VERSION\(\)*)
    echo "10.11.14-MariaDB"
    ;;
  *engine\ \<\>\ *|*engine*InnoDB*)
    : # aucune table non InnoDB
    ;;
  *table_name\ =\ \'migrations\'*)
    echo "1"
    ;;
  *information_schema.tables*COUNT*\ BASE\ TABLE*)
    echo "5"
    ;;
  *table_name*BASE\ TABLE*)
    printf 'cache\nfailed_jobs\njobs\nmigrations\nusers\n'
    ;;
  *COUNT\(\)\ FROM*)
    echo "2"
    ;;
  *data_length*)
    echo "128"
    ;;
  *SCHEMATA*)
    if [[ -n "${FAKE_EXISTING_DB:-}" && "$query" == *"$FAKE_EXISTING_DB"* ]]; then
      echo "$FAKE_EXISTING_DB"
    fi
    ;;
  *@@character_set_database*)
    echo "utf8mb4"
    ;;
  *information_schema.tables*)
    echo "5"
    ;;
  *)
    echo "1"
    ;;
esac
FAKE

cat >"$fake_bin/age" <<'FAKE'
#!/usr/bin/env bash
output=""
input=""
mode=""

while (($#)); do
  case "$1" in
    --encrypt | --encrypt-to) mode="encrypt"; shift ;;
    --decrypt) mode="decrypt"; shift ;;
    --output) output="$2"; shift 2 ;;
    --recipients-file | --recipient | --identity) shift 2 ;;
    --) shift ;;
    *) input="$1"; shift ;;
  esac
done

[[ -n "$output" ]] || { echo 'age factice : --output manquant' >&2; exit 1; }
[[ -n "$mode" ]] || { echo 'age factice : mode manquant' >&2; exit 1; }
if [[ -n "${FAKE_AGE_SLEEP:-}" ]]; then
  sleep "$FAKE_AGE_SLEEP"
fi
if [[ -n "${FAKE_AGE_BLOCK:-}" ]]; then
  printf '%s\n' "$$" >"${FAKE_AGE_BLOCK_PID:-/dev/null}"
  trap 'printf stopped >"${FAKE_AGE_BLOCK_STOP:-/dev/null}"; exit 143' TERM
  while :; do
    sleep 1
  done
fi
cp -- "$input" "$output"
FAKE

cat >"$fake_bin/supervisorctl" <<'FAKE'
#!/usr/bin/env bash
echo "${FAKE_SUPERVISOR_STATUS:-STOPPED}"
FAKE

real_tar="$(command -v tar)"
real_gzip="$(command -v gzip)"

cat >"$fake_bin/tar" <<FAKE
#!/usr/bin/env bash
if [[ -n "\${FAKE_TAR_BLOCK:-}" && " \$* " == *" --extract "* ]]; then
  printf '%s\n' "\$\$" >"\${FAKE_TAR_BLOCK_PID:-/dev/null}"
  trap 'printf stopped >"\${FAKE_TAR_BLOCK_STOP:-/dev/null}"; exit 143' TERM
  while :; do
    sleep 1
  done
fi
exec "$real_tar" "\$@"
FAKE

cat >"$fake_bin/gzip" <<FAKE
#!/usr/bin/env bash
if [[ -n "\${FAKE_GZIP_BLOCK:-}" ]]; then
  printf '%s\n' "\$\$" >"\${FAKE_GZIP_BLOCK_PID:-/dev/null}"
  trap 'printf stopped >"\${FAKE_GZIP_BLOCK_STOP:-/dev/null}"; exit 143' TERM
  while :; do
    sleep 1
  done
fi
exec "$real_gzip" "\$@"
FAKE

chmod +x "$fake_bin"/*

export PATH="$fake_bin:$PATH"
export C2ME_ROOT="$root"
export C2ME_BACKUP_ROOT="$backup_root"
export C2ME_DB_DEFAULTS_FILE="$work_dir/my.cnf"
export C2ME_RESTORE_DB_DEFAULTS_FILE="$work_dir/my.cnf"
export C2ME_AGE_RECIPIENT_FILE="$backup_root/keys/recipient.pub"
export C2ME_RESTORE_WORK_ROOT="$work_dir/work"
export C2ME_COMPRESSION="gzip"
export C2ME_PHP_BIN="$(command -v php)"
export C2ME_MYSQL_BIN="$fake_bin/mariadb"
export C2ME_DB_DUMP_BIN="$fake_bin/mariadb-dump"
export C2ME_AGE_BIN="$fake_bin/age"
export C2ME_TAR_BIN="$fake_bin/tar"
export C2ME_GZIP_BIN="$fake_bin/gzip"
export C2ME_OPERATOR="test-operator"
export C2ME_HOST_ID="test-host"
export FAKE_IMPORT_LOG="$work_dir/import.sql"

run_backup() {
  local output
  output="$(bash "$ops_dir/backup.sh" "$@" 2>&1)"
  local status=$?
  printf '%s\n' "$output"
  return $status
}

run_restore() {
  local output
  output="$(bash "$ops_dir/restore.sh" "$@" 2>&1)"
  local status=$?
  printf '%s\n' "$output"
  return $status
}

extract() {
  local key="$1"
  local output="$2"
  printf '%s\n' "$output" | sed -n "s/^${key}=//p" | tail -n 1
}

# ---------------------------------------------------------------------------
# 1. Sauvegarde complète
# ---------------------------------------------------------------------------

output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?

if ((status == 0)); then
  pass
else
  fail "la sauvegarde complète doit réussir (code $status). Sortie : $output"
fi

set_id="$(extract SET_ID "$output")"
manifest="$backup_root/sets/$set_id/manifest.json"

assert_file_exists "$manifest" 'manifeste créé'
assert_ok 'manifeste valide' bash -c "php '$ops_dir/lib/manifest.php' validate '$manifest' >/dev/null 2>&1"
assert_ok 'vérification du jeu' bash -c "bash '$ops_dir/backup.sh' verify --env staging --set '$set_id' >/dev/null 2>&1"

if grep -Fq 'contrat.txt' "$backup_root/sets/$set_id/inventory.sha256"; then
  pass
else
  fail 'l inventaire doit contenir les fichiers privés.'
fi

if grep -Fq 'laravel.log' "$backup_root/sets/$set_id/inventory.sha256"; then
  fail 'les journaux ne doivent pas être sauvegardés.'
else
  pass
fi

if grep -Fq 'data.txt' "$backup_root/sets/$set_id/inventory.sha256"; then
  fail 'le cache framework ne doit pas être sauvegardé.'
else
  pass
fi

expected_bytes=$(( $(wc -c <"$root/shared/storage/app/private/contrat.txt") \
  + $(wc -c <"$root/shared/storage/app/private/sub/plan.pdf") \
  + $(wc -c <"$root/shared/storage/app/public/photo.txt") ))
manifest_bytes="$(php "$ops_dir/lib/manifest.php" summary "$manifest" files.total_bytes)"

if [[ "$manifest_bytes" == "$expected_bytes" ]]; then
  pass
else
  fail "files.total_bytes doit sommer uniquement les fichiers réguliers ($manifest_bytes != $expected_bytes)."
fi

assert_ok 'scope full dans le manifeste' bash -c "[[ \"\$(php '$ops_dir/lib/manifest.php' summary '$manifest' scope)\" == 'full' ]]"

# ---------------------------------------------------------------------------
# 2. Refus sans mode maintenance
# ---------------------------------------------------------------------------

mv "$root/shared/storage/framework/down" "$work_dir/down.bak"
output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'mode maintenance inactif' 'refus sans maintenance'
else
  fail 'la sauvegarde doit être refusée sans mode maintenance.'
fi
mv "$work_dir/down.bak" "$root/shared/storage/framework/down"

# ---------------------------------------------------------------------------
# 3. Refus sans confirmations workers / cron
# ---------------------------------------------------------------------------

output="$(run_backup set --env staging --trigger manual)"
status=$?

if ((status != 0)); then
  pass
else
  fail 'la sauvegarde doit exiger la confirmation des workers.'
fi

output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped)"
status=$?

if ((status != 0)); then
  pass
else
  fail 'la sauvegarde doit exiger la confirmation du cron.'
fi

# ---------------------------------------------------------------------------
# 4. Refus d'un lien symbolique
# ---------------------------------------------------------------------------

ln -s /etc/hostname "$root/shared/storage/app/private/lien.txt" 2>/dev/null
symlink_status=$?

if ((symlink_status == 0)); then
  output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
  status=$?

  if ((status != 0)); then
    pass
    assert_contains "$output" 'lien symbolique' 'refus d un lien symbolique'
  else
    fail 'la sauvegarde doit refuser un lien symbolique.'
  fi

  rm -f "$root/shared/storage/app/private/lien.txt"
else
  skip 'création de lien symbolique impossible sur ce système : test non exécuté.'
fi

# ---------------------------------------------------------------------------
# 5. Refus si un fichier change pendant l'opération
# ---------------------------------------------------------------------------

real_tar="$(command -v tar)"
cat >"$fake_bin/tar-touch" <<FAKE
#!/usr/bin/env bash
"$real_tar" "\$@"
status=\$?
if [[ -n "\${FAKE_TAR_TOUCH:-}" && " \$* " == *" --create "* ]]; then
  printf 'modification\n' >>"\${FAKE_TAR_TOUCH}"
fi
exit \$status
FAKE
chmod +x "$fake_bin/tar-touch"

output="$(FAKE_TAR_TOUCH="$root/shared/storage/app/private/contrat.txt" C2ME_TAR_BIN="$fake_bin/tar-touch" run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?
rm -f "$fake_bin/tar-touch"

if ((status != 0)); then
  pass
  assert_contains "$output" 'changé pendant la sauvegarde' 'refus de modification pendant l opération'
else
  fail 'la sauvegarde doit refuser un fichier modifié pendant l opération.'
fi

if [[ -z "$(ls -A "$backup_root/incoming" 2>/dev/null)" ]]; then
  pass
else
  fail 'un échec de sauvegarde ne doit laisser aucun répertoire de travail.'
fi

# ---------------------------------------------------------------------------
# 6. Refus si age est absent
# ---------------------------------------------------------------------------

output="$(C2ME_AGE_BIN="$work_dir/age-absent" run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?

if ((status != 0)); then
  pass
else
  fail 'la sauvegarde doit être refusée si age est absent.'
fi

# ---------------------------------------------------------------------------
# 7. Détection d'altération
# ---------------------------------------------------------------------------

set_id="$(run_backup list --env staging | sed -n 's/^\(set-[^[:space:]]*\).*/\1/p' | tail -n 1)"
artifact="$(sed -n 's/.*"name": "\(db-[^"]*\)".*/\1/p' "$backup_root/sets/$set_id/manifest.json" | head -n 1)"
printf 'alteration' >>"$backup_root/sets/$set_id/$artifact"

output="$(bash "$ops_dir/backup.sh" verify --env staging --set "$set_id" 2>&1)"
status=$?

if ((status != 0)); then
  pass
else
  fail 'la vérification doit détecter un artefact altéré.'
fi

# Nouveau jeu sain pour les restaurations.
output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
set_id="$(extract SET_ID "$output")"
manifest="$backup_root/sets/$set_id/manifest.json"

if [[ -n "$set_id" ]]; then
  pass
else
  fail 'un jeu sain est nécessaire pour les tests de restauration.'
fi

# ---------------------------------------------------------------------------
# 8. Restauration de la base
# ---------------------------------------------------------------------------

target_db="chantier_restore_20261113_abc12345"
output="$(run_restore db --env staging --set "$set_id" --target-db "$target_db" --identity "$work_dir/id.age")"
status=$?

if ((status == 0)); then
  pass
else
  fail "la restauration de base doit réussir (code $status). Sortie : $output"
fi

assert_contains "$output" 'DATABASE=ok' 'restauration de base contrôlée'
assert_contains "$(cat "$work_dir/import.sql" 2>/dev/null)" 'CREATE TABLE users' 'dump décompressé puis importé'

output="$(FAKE_EXISTING_DB="$target_db" run_restore db --env staging --set "$set_id" --target-db "$target_db" --identity "$work_dir/id.age")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'existe déjà' 'refus d une base préexistante'
else
  fail 'la restauration doit refuser une base cible préexistante.'
fi

output="$(run_restore db --env staging --set "$set_id" --target-db "chantier_staging" --identity "$work_dir/id.age")"
status=$?

if ((status != 0)); then
  pass
else
  fail 'la restauration doit refuser une base applicative.'
fi

output="$(run_restore db --env staging --set "$set_id" --target-db "restore_20261113_abc12345" --identity "$work_dir/id.age")"
status=$?

if ((status != 0)); then
  pass
else
  fail 'la restauration doit refuser un nom de base non conforme.'
fi

# ---------------------------------------------------------------------------
# 9. Restauration des fichiers et remappage
# ---------------------------------------------------------------------------

owner="$(id -u):$(id -g)"
target_dir="$work_dir/restauration/fichiers"
mkdir -p "$work_dir/restauration"

output="$(run_restore files --env staging --set "$set_id" --target-dir "$target_dir" --owner "$owner" --identity "$work_dir/id.age")"
status=$?

if ((status == 0)); then
  pass
else
  fail "la restauration de fichiers doit réussir (code $status). Sortie : $output"
fi

assert_file_exists "$target_dir/app/private/contrat.txt" 'fichier privé restauré'
assert_file_exists "$target_dir/app/public/photo.txt" 'fichier public restauré'

if [[ -f "$target_dir/app/private/contrat.txt" ]]; then
  content="$(cat "$target_dir/app/private/contrat.txt")"
  assert_contains "$content" 'documents privés' 'contenu du fichier restauré'
fi

can_setgid() {
  local probe
  probe="$(mktemp -d 2>/dev/null)" || return 1
  chmod 2770 "$probe" 2>/dev/null || {
    rm -rf "$probe"
    return 1
  }
  if [[ -n "$(find "$probe" -maxdepth 0 -perm -2000 -print 2>/dev/null)" ]]; then
    rm -rf "$probe"
    return 0
  fi
  rm -rf "$probe"
  return 1
}

if can_setgid; then
  if [[ -n "$(find "$target_dir" -type d ! -perm -2000 -print -quit 2>/dev/null)" ]]; then
    fail 'les répertoires restaurés doivent porter le bit setgid.'
  else
    pass
  fi
else
  skip 'bit setgid non applicable sur cette plateforme : contrôle ignoré.'
fi

if [[ -n "$(find "$target_dir" ! -type l -perm -0002 -print -quit 2>/dev/null)" ]]; then
  fail 'aucun élément restauré ne doit être accessible en écriture aux autres.'
else
  pass
fi

output="$(run_restore files --env staging --set "$set_id" --target-dir "$target_dir" --owner "$owner" --identity "$work_dir/id.age")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'existe déjà' 'refus d un répertoire préexistant'
else
  fail 'la restauration doit refuser un répertoire cible préexistant.'
fi

output="$(run_restore files --env staging --set "$set_id" --target-dir "$root/shared/storage/restauration" --owner "$owner" --identity "$work_dir/id.age")"
status=$?

if ((status != 0)); then
  pass
else
  fail 'la restauration doit refuser une cible sous la racine applicative.'
fi

false_bin="$(command -v false)"
output="$(C2ME_TAR_BIN="$false_bin" run_restore files --env staging --set "$set_id" --target-dir "$work_dir/restauration/echec" --owner "$owner" --identity "$work_dir/id.age")"
status=$?

if ((status != 0)); then
  pass
else
  fail 'une extraction en échec doit être signalée.'
fi

if [[ -z "$(ls -A "$work_dir/work" 2>/dev/null)" ]]; then
  pass
else
  fail 'une restauration en échec ne doit laisser aucune donnée déchiffrée.'
fi

# ---------------------------------------------------------------------------
# 10. Gardes sur la clé privée
# ---------------------------------------------------------------------------

cp "$work_dir/id.age" "$root/shared/age-identity.key"
chmod 0600 "$root/shared/age-identity.key"
output="$(run_restore db --env staging --set "$set_id" --target-db "chantier_restore_20261113_deadbeef" --identity "$root/shared/age-identity.key")"
status=$?
rm -f "$root/shared/age-identity.key"

if ((status != 0)); then
  pass
else
  fail 'une clé privée sous la racine applicative doit être refusée.'
fi

cp "$work_dir/id.age" "$work_dir/id-loose.age"
chmod 0644 "$work_dir/id-loose.age"

modes_enforced=0
probe_file="$(mktemp)"
chmod 0600 "$probe_file" 2>/dev/null
if [[ "$(stat -c '%a' "$probe_file" 2>/dev/null || stat -f '%Lp' "$probe_file" 2>/dev/null || echo unknown)" == '600' ]]; then
  modes_enforced=1
fi
rm -f "$probe_file"

if ((modes_enforced == 1)); then
  output="$(run_restore db --env staging --set "$set_id" --target-db "chantier_restore_20261113_cafebabe" --identity "$work_dir/id-loose.age")"
  status=$?

  if ((status != 0)); then
    pass
    assert_contains "$output" 'groupe ou aux autres' 'refus d une clé trop permissive'
  else
    fail 'une clé privée lisible par le groupe doit être refusée.'
  fi
else
  skip 'modes POSIX non appliqués : contrôle de permission de clé non exécuté.'
fi

rm -f "$work_dir/id-loose.age"

# ---------------------------------------------------------------------------
# 11. Rapport de restauration
# ---------------------------------------------------------------------------

output="$(run_restore report --env staging --set "$set_id" --notes 'test local sans base réelle')"
status=$?

report_path="$(extract REPORT "$output")"

if ((status == 0)) && [[ -f "$report_path" ]]; then
  pass
else
  fail "le rapport de restauration doit être produit (code $status). Sortie : $output"
fi

if [[ -f "$report_path" ]]; then
  assert_ok 'rapport JSON valide' bash -c "php -r 'exit(is_array(json_decode(file_get_contents(\$argv[1]), true)) ? 0 : 1);' \"$report_path\""

  if grep -Fq '"signature": "none"' "$report_path"; then
    pass
  else
    fail 'le rapport ne doit jamais être présenté comme signé.'
  fi

  if grep -Fq '"performed": false' "$report_path"; then
    pass
  else
    fail 'le rapport doit indiquer que la vérification applicative reste manuelle.'
  fi

  expected_sha="$(sha256sum "$report_path" | awk '{print $1}')"
  recorded_sha="$(awk '{print $1}' "$report_path.sha256")"

  if [[ "$expected_sha" == "$recorded_sha" ]]; then
    pass
  else
    fail 'le checksum du rapport ne concorde pas.'
  fi
fi

if [[ -f "$backup_root/ledger/chain.jsonl" ]]; then
  pass
else
  fail 'la chaîne d intégrité des rapports doit exister.'
fi

# ---------------------------------------------------------------------------
# 12. Rétention
# ---------------------------------------------------------------------------

make_old_set() {
  local id="$1"
  local created="$2"
  mkdir -p "$backup_root/sets/$id"

  cat >"$backup_root/sets/$id/manifest.json" <<JSON
{
  "created_at": "$created",
  "trigger": "scheduled",
  "status": "complete"
}
JSON
}

make_old_set 'set-staging-20200102T000000Z-aaaaaaaa' '2020-01-02T00:00:00Z'
make_old_set 'set-staging-20200103T000000Z-bbbbbbbb' '2020-01-03T00:00:00Z'

output="$(run_backup prune --env staging --dry-run)"
status=$?

if ((status == 0)) && [[ -d "$backup_root/sets/set-staging-20200102T000000Z-aaaaaaaa" ]]; then
  pass
else
  fail 'la simulation de rétention ne doit rien déplacer.'
fi

output="$(run_backup prune --env staging)"
status=$?

if ((status == 0)) && [[ -d "$backup_root/sets/set-staging-20200102T000000Z-aaaaaaaa" ]]; then
  pass
else
  fail 'la rétention sans --confirm ne doit rien déplacer.'
fi

output="$(run_backup prune --env staging --confirm)"
status=$?

if ((status == 0)) \
  && [[ -d "$backup_root/expired/set-staging-20200102T000000Z-aaaaaaaa" ]] \
  && [[ ! -e "$backup_root/sets/set-staging-20200102T000000Z-aaaaaaaa" ]]; then
  pass
else
  fail "la rétention confirmée doit déplacer les jeux expirés en quarantaine. Sortie : $output"
fi

if [[ -d "$backup_root/sets/$set_id" ]]; then
  pass
else
  fail 'le jeu le plus récent ne doit jamais être supprimé par la rétention.'
fi

# ---------------------------------------------------------------------------
# 13. Inspection des archives TAR
# ---------------------------------------------------------------------------

fixtures_dir="$work_dir/fixtures"
mkdir -p "$fixtures_dir"

inspector="$ops_dir/lib/tar-inspect.php"

php "$project_root/scripts/ops/tests/make-tar-fixture.php" "$fixtures_dir/valid.tar" valid >/dev/null
valid_output="$(php "$inspector" "$fixtures_dir/valid.tar" 2>&1)"
assert_contains "$valid_output" 'files=1' 'archive valide acceptée'

php "$project_root/scripts/ops/tests/make-tar-fixture.php" "$fixtures_dir/valid-multi.tar" valid-multi >/dev/null
valid_multi_output="$(php "$inspector" "$fixtures_dir/valid-multi.tar" 2>&1)"
assert_contains "$valid_multi_output" 'files=2 dirs=2' 'archive valide multi-entrées acceptée'

php "$project_root/scripts/ops/tests/make-tar-fixture.php" "$fixtures_dir/pax-valid.tar" pax-valid >/dev/null
pax_valid_output="$(php "$inspector" "$fixtures_dir/pax-valid.tar" 2>&1)"
assert_contains "$pax_valid_output" 'files=1' 'PAX path autorisé accepté'

php "$project_root/scripts/ops/tests/make-tar-fixture.php" "$fixtures_dir/gnu-longname-valid.tar" gnu-longname-valid >/dev/null
gnu_valid_output="$(php "$inspector" "$fixtures_dir/gnu-longname-valid.tar" 2>&1)"
assert_contains "$gnu_valid_output" 'files=1' 'nom long GNU valide accepté'

for fixture_type in symlink hardlink fifo chardev blockdev traversal absolute outside dotdot corrupt-checksum truncated special-type \
  pax-global pax-size pax-sparse pax-xattr pax-malformed pax-empty pax-contradictory gnu-longname-malformed gnu-longlink-malformed; do
  php "$project_root/scripts/ops/tests/make-tar-fixture.php" "$fixtures_dir/$fixture_type.tar" "$fixture_type" >/dev/null

  if php "$inspector" "$fixtures_dir/$fixture_type.tar" >/dev/null 2>&1; then
    fail "l archive malveillante '$fixture_type' doit être refusée."
  else
    pass
  fi
done

# Intégration : une archive interdite ne doit jamais être extraite.
malicious_id="set-staging-20261113T235958Z-deadbeef"
cp -R "$backup_root/sets/$set_id" "$backup_root/sets/$malicious_id"
malicious_dir="$backup_root/sets/$malicious_id"
files_artifact="$(ls -1 "$malicious_dir" | grep '^files-' | head -n 1)"

php "$project_root/scripts/ops/tests/make-tar-fixture.php" "$fixtures_dir/symlink.tar" symlink >/dev/null
gzip -c "$fixtures_dir/symlink.tar" >"$malicious_dir/$files_artifact"

php -r '
    $manifestPath = $argv[1];
    $artifactPath = $argv[2];
    $manifest = json_decode(file_get_contents($manifestPath), true);
    foreach ($manifest["artifacts"] as &$artifact) {
        if ($artifact["kind"] === "files") {
            $artifact["sha256"] = hash_file("sha256", $artifactPath);
            $artifact["bytes"] = filesize($artifactPath);
        }
    }
    unset($artifact);
    file_put_contents($manifestPath, json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
' "$malicious_dir/manifest.json" "$malicious_dir/$files_artifact"

(
  cd "$malicious_dir"
  sha256sum db-* "$files_artifact" inventory.sha256 inventory.meta manifest.json >SHA256SUMS
  sha256sum manifest.json >manifest.json.sha256
)

refused_target="$work_dir/restauration/refus-archive"
output="$(run_restore files --env staging --set "$malicious_id" --target-dir "$refused_target" --owner "$owner" --identity "$work_dir/id.age")"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'archive refusée' 'refus d une archive contenant un lien symbolique'
else
  fail 'une archive contenant un lien symbolique doit être refusée.'
fi

assert_dir_absent "$refused_target" 'aucune extraction vers la cible'

# ---------------------------------------------------------------------------
# 14. Signaux et nettoyage
# ---------------------------------------------------------------------------

signals_supported=0
bash -c 'trap "exit 143" TERM; sleep 3' &
probe_pid=$!
sleep 0.5

if kill -TERM "$probe_pid" 2>/dev/null; then
  wait "$probe_pid" 2>/dev/null
  if [[ "$?" == '143' ]]; then
    signals_supported=1
  fi
else
  wait "$probe_pid" 2>/dev/null || true
fi

wait_for_nonempty() {
  local directory="$1"
  local attempt

  for attempt in $(seq 1 100); do
    if [[ -n "$(ls -A "$directory" 2>/dev/null)" ]]; then
      return 0
    fi
    sleep 0.1
  done

  return 1
}

run_with_signal() {
  local signal="$1"
  local expected_code="$2"
  local label="$3"
  local log="$work_dir/signal-${label}.log"
  local sets_before sets_after pid status

  sets_before="$(ls -1 "$backup_root/sets" | wc -l | tr -d ' ')"

  FAKE_DUMP_SLEEP=10 bash "$ops_dir/backup.sh" set --env staging --trigger manual \
    --confirm-workers-stopped --confirm-scheduler-disabled >"$log" 2>&1 &
  pid=$!

  if wait_for_nonempty "$backup_root/incoming"; then
    kill "-$signal" "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    status=$?

    if [[ "$status" == "$expected_code" ]]; then
      pass
    else
      fail "signal $signal : code retour $status au lieu de $expected_code."
    fi

    sets_after="$(ls -1 "$backup_root/sets" | wc -l | tr -d ' ')"

    if [[ "$sets_before" == "$sets_after" ]]; then
      pass
    else
      fail "signal $signal : un jeu incomplet a été promu."
    fi

    if [[ -z "$(ls -A "$backup_root/incoming" 2>/dev/null)" ]]; then
      pass
    else
      fail "signal $signal : la zone de travail n'a pas été nettoyée."
    fi

    if [[ ! -e "$backup_root/.lock" ]]; then
      pass
    else
      fail "signal $signal : le verrou n'a pas été nettoyé."
    fi
  else
    fail "signal $signal : la sauvegarde n'a pas démarré."
    kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$backup_root/.lock"
  fi
}

if ((signals_supported == 1)); then
  set -m
  run_with_signal TERM 143 'term'
  run_with_signal INT 130 'int'
  set +m
else
  skip 'les signaux ne peuvent pas être délivrés sur cette plateforme : tests TERM/INT non exécutés.'
fi

if ((signals_supported == 1)); then
  restore_target="$work_dir/restauration/signal"
  FAKE_AGE_SLEEP=10 bash "$ops_dir/restore.sh" files --env staging --set "$set_id" \
    --target-dir "$restore_target" --owner "$owner" --identity "$work_dir/id.age" \
    >"$work_dir/signal-restore.log" 2>&1 &
  restore_pid=$!

  if wait_for_nonempty "$work_dir/work"; then
    kill -TERM "$restore_pid" 2>/dev/null
    wait "$restore_pid" 2>/dev/null
    restore_status=$?

    if [[ "$restore_status" == '143' ]]; then
      pass
    else
      fail "restauration interrompue : code $restore_status au lieu de 143."
    fi

    if [[ -z "$(ls -A "$work_dir/work" 2>/dev/null)" ]]; then
      pass
    else
      fail 'une interruption de restauration doit supprimer la zone de travail déchiffrée.'
    fi

    if [[ ! -e "$backup_root/.lock" ]]; then
      pass
    else
      fail 'une interruption de restauration doit libérer le verrou.'
    fi

    assert_dir_absent "$restore_target" 'aucune cible créée par une restauration interrompue'
  else
    fail 'la restauration n a pas démarré pour le test de signal.'
    kill -KILL "$restore_pid" 2>/dev/null || true
    wait "$restore_pid" 2>/dev/null || true
    rm -rf "$backup_root/.lock"
  fi
fi

# ---------------------------------------------------------------------------
# 14 bis. Interruption des processus enfants critiques
# ---------------------------------------------------------------------------

wait_for_file() {
  local path="$1"
  local attempt

  for attempt in $(seq 1 150); do
    if [[ -s "$path" ]]; then
      return 0
    fi
    sleep 0.1
  done

  return 1
}

assert_child_interrupted() {
  local label="$1"
  local status="$2"
  local expected_code="$3"
  local pid_file="$4"
  local stop_file="$5"

  if [[ "$status" == "$expected_code" ]]; then
    pass
  else
    fail "$label : code $status au lieu de $expected_code."
  fi

  if [[ -s "$pid_file" ]]; then
    local child_pid
    child_pid="$(cat "$pid_file")"

    if kill -0 "$child_pid" 2>/dev/null; then
      fail "$label : le processus enfant $child_pid est encore vivant."
    else
      pass
    fi
  else
    fail "$label : PID enfant non enregistré."
  fi

  if [[ -f "$stop_file" ]]; then
    pass
  else
    fail "$label : l enfant n a pas reçu le signal de terminaison."
  fi

  if [[ ! -e "$backup_root/.lock" ]]; then
    pass
  else
    fail "$label : le verrou subsiste après l interruption."
  fi
}

sets_before_children="$(ls -1 "$backup_root/sets" | wc -l | tr -d ' ')"

# mariadb-dump bloqué
dump_pid_file="$work_dir/child-dump.pid"
dump_stop_file="$work_dir/child-dump.stop"
rm -f "$dump_pid_file" "$dump_stop_file"

FAKE_DUMP_BLOCK=1 FAKE_DUMP_BLOCK_PID="$dump_pid_file" FAKE_DUMP_BLOCK_STOP="$dump_stop_file" \
  bash "$ops_dir/backup.sh" set --env staging --trigger manual \
  --confirm-workers-stopped --confirm-scheduler-disabled >"$work_dir/child-dump.log" 2>&1 &
child_main_pid=$!

if wait_for_file "$dump_pid_file"; then
  kill -TERM "$child_main_pid" 2>/dev/null
  wait "$child_main_pid" 2>/dev/null
  child_status=$?

  assert_child_interrupted 'mariadb-dump interrompu' "$child_status" '143' "$dump_pid_file" "$dump_stop_file"

  if [[ -z "$(ls -A "$backup_root/incoming" 2>/dev/null)" ]]; then
    pass
  else
    fail 'mariadb-dump interrompu : zone de travail non nettoyée.'
  fi
else
  fail 'le double de mariadb-dump ne s est pas bloqué.'
  kill -KILL "$child_main_pid" 2>/dev/null || true
  wait "$child_main_pid" 2>/dev/null || true
  rm -rf "$backup_root/.lock"
fi

# gzip bloqué pendant la compression
gzip_pid_file="$work_dir/child-gzip.pid"
gzip_stop_file="$work_dir/child-gzip.stop"
rm -f "$gzip_pid_file" "$gzip_stop_file"

FAKE_GZIP_BLOCK=1 FAKE_GZIP_BLOCK_PID="$gzip_pid_file" FAKE_GZIP_BLOCK_STOP="$gzip_stop_file" \
  bash "$ops_dir/backup.sh" set --env staging --trigger manual \
  --confirm-workers-stopped --confirm-scheduler-disabled >"$work_dir/child-gzip.log" 2>&1 &
child_main_pid=$!

if wait_for_file "$gzip_pid_file"; then
  kill -TERM "$child_main_pid" 2>/dev/null
  wait "$child_main_pid" 2>/dev/null
  child_status=$?

  assert_child_interrupted 'gzip interrompu' "$child_status" '143' "$gzip_pid_file" "$gzip_stop_file"
else
  fail 'le double de gzip ne s est pas bloqué.'
  kill -KILL "$child_main_pid" 2>/dev/null || true
  wait "$child_main_pid" 2>/dev/null || true
  rm -rf "$backup_root/.lock"
fi

# age bloqué pendant la restauration
age_pid_file="$work_dir/child-age.pid"
age_stop_file="$work_dir/child-age.stop"
rm -f "$age_pid_file" "$age_stop_file"

FAKE_AGE_BLOCK=1 FAKE_AGE_BLOCK_PID="$age_pid_file" FAKE_AGE_BLOCK_STOP="$age_stop_file" \
  bash "$ops_dir/restore.sh" files --env staging --set "$set_id" \
  --target-dir "$work_dir/restauration/child-age" --owner "$owner" --identity "$work_dir/id.age" \
  >"$work_dir/child-age.log" 2>&1 &
child_main_pid=$!

if wait_for_file "$age_pid_file"; then
  kill -TERM "$child_main_pid" 2>/dev/null
  wait "$child_main_pid" 2>/dev/null
  child_status=$?

  assert_child_interrupted 'age interrompu' "$child_status" '143' "$age_pid_file" "$age_stop_file"
else
  fail 'le double de age ne s est pas bloqué.'
  kill -KILL "$child_main_pid" 2>/dev/null || true
  wait "$child_main_pid" 2>/dev/null || true
  rm -rf "$backup_root/.lock"
fi

if [[ -z "$(ls -A "$work_dir/work" 2>/dev/null)" ]]; then
  pass
else
  fail 'age interrompu : zone de travail déchiffrée non nettoyée.'
fi

assert_dir_absent "$work_dir/restauration/child-age" 'aucune cible créée après interruption de age'

# tar bloqué pendant l'extraction
tar_pid_file="$work_dir/child-tar.pid"
tar_stop_file="$work_dir/child-tar.stop"
rm -f "$tar_pid_file" "$tar_stop_file"

FAKE_TAR_BLOCK=1 FAKE_TAR_BLOCK_PID="$tar_pid_file" FAKE_TAR_BLOCK_STOP="$tar_stop_file" \
  bash "$ops_dir/restore.sh" files --env staging --set "$set_id" \
  --target-dir "$work_dir/restauration/child-tar" --owner "$owner" --identity "$work_dir/id.age" \
  >"$work_dir/child-tar.log" 2>&1 &
child_main_pid=$!

if wait_for_file "$tar_pid_file"; then
  kill -TERM "$child_main_pid" 2>/dev/null
  wait "$child_main_pid" 2>/dev/null
  child_status=$?

  assert_child_interrupted 'tar interrompu' "$child_status" '143' "$tar_pid_file" "$tar_stop_file"
else
  fail 'le double de tar ne s est pas bloqué.'
  kill -KILL "$child_main_pid" 2>/dev/null || true
  wait "$child_main_pid" 2>/dev/null || true
  rm -rf "$backup_root/.lock"
fi

if [[ -z "$(ls -A "$work_dir/work" 2>/dev/null)" ]]; then
  pass
else
  fail 'tar interrompu : zone de travail non nettoyée.'
fi

sets_after_children="$(ls -1 "$backup_root/sets" | wc -l | tr -d ' ')"

if [[ "$sets_before_children" == "$sets_after_children" ]]; then
  pass
else
  fail 'une interruption enfant a promu un jeu incomplet.'
fi

# ---------------------------------------------------------------------------
# 15. Verrou orphelin
# ---------------------------------------------------------------------------

sleep 0.1 &
dead_pid=$!
wait "$dead_pid" 2>/dev/null || true

mkdir "$backup_root/.lock"
printf '%s\n' "$dead_pid" >"$backup_root/.lock/pid"
printf '2026-11-13T00:00:00Z\n' >"$backup_root/.lock/started_at"
printf 'test-host\n' >"$backup_root/.lock/host"

output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'orphelin' 'verrou orphelin refusé sans libération'
else
  fail 'un verrou orphelin doit être refusé.'
fi

output="$(run_backup unlock --env staging)"
status=$?

if ((status != 0)); then
  pass
else
  fail 'unlock sans --confirm-stale-lock doit être refusé.'
fi

output="$(run_backup unlock --env staging --confirm-stale-lock)"
status=$?

if [[ "$status" == '0' && ! -e "$backup_root/.lock" ]]; then
  pass
else
  fail "unlock --confirm-stale-lock doit libérer le verrou orphelin. Sortie : $output"
fi

mkdir "$backup_root/.lock"
printf '%s\n' "$$" >"$backup_root/.lock/pid"
printf '2026-11-13T00:00:00Z\n' >"$backup_root/.lock/started_at"
printf 'test-host\n' >"$backup_root/.lock/host"

output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'déjà en cours' 'verrou actif refusé'
else
  fail 'un verrou actif doit être refusé.'
fi

output="$(run_backup unlock --env staging --confirm-stale-lock)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'actif' 'libération d un verrou actif refusée'
else
  fail 'la libération d un verrou actif doit être refusée.'
fi

rm -rf "$backup_root/.lock"

# Verrou d'un autre hôte : ni l'opération ni la libération ne doivent l'accepter.
mkdir "$backup_root/.lock"
printf '%s\n' "$dead_pid" >"$backup_root/.lock/pid"
printf '2026-11-13T00:00:00Z\n' >"$backup_root/.lock/started_at"
printf 'autre-hote\n' >"$backup_root/.lock/host"

output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'autre hôte' 'verrou d un autre hôte refusé'
else
  fail 'un verrou d un autre hôte doit être refusé.'
fi

output="$(run_backup unlock --env staging --confirm-stale-lock)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" "appartient à l'hôte" 'libération d un verrou distant refusée'
else
  fail 'la libération d un verrou distant doit être refusée.'
fi

rm -rf "$backup_root/.lock"

# Verrou sans hôte : ambigu, libération refusée.
mkdir "$backup_root/.lock"
printf '%s\n' "$dead_pid" >"$backup_root/.lock/pid"
printf '2026-11-13T00:00:00Z\n' >"$backup_root/.lock/started_at"

output="$(run_backup set --env staging --trigger manual --confirm-workers-stopped --confirm-scheduler-disabled)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'sans hôte identifiable' 'verrou sans hôte refusé'
else
  fail 'un verrou sans hôte doit être refusé.'
fi

output="$(run_backup unlock --env staging --confirm-stale-lock)"
status=$?

if ((status != 0)); then
  pass
  assert_contains "$output" 'sans hôte identifiable' 'libération d un verrou sans hôte refusée'
else
  fail 'la libération d un verrou sans hôte doit être refusée.'
fi

rm -rf "$backup_root/.lock"

# ---------------------------------------------------------------------------
# Bilan
# ---------------------------------------------------------------------------

printf '\n%d test(s) réussi(s), %d échec(s).\n' "$passed" "$failed"

if ((failed > 0)); then
  exit 1
fi

exit 0
