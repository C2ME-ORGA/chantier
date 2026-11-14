#!/usr/bin/env bash
#
# Déploiement d'une release sur le serveur, exécuté via SSH sans élévation de
# privilèges.
#
# Ce script est autonome : il est transmis par `ssh` et n'importe aucun fichier
# local. Il refuse tout environnement, utilisateur, chemin ou paquet qui ne
# correspond pas exactement à la configuration autorisée.
#
# Il ne modifie jamais `shared/.env`, ne déplace jamais `shared/storage`,
# n'exécute aucune migration et n'active pas le mode maintenance.

readonly STAGING_ROOT='/www/wwwroot/chantier-staging.c2me.ovh'
readonly PRODUCTION_ROOT='/www/wwwroot/chantier.c2me.fr'
readonly STAGING_USER='c2me-deploy-staging'
readonly PRODUCTION_USER='c2me-deploy-production'

# Anciens chemins documentés avant l'adaptation à aaPanel. Ils ne doivent plus
# jamais être acceptés : un site aaPanel utilise le nom de domaine comme
# répertoire racine.
readonly LEGACY_STAGING_ROOT='/www/wwwroot/chantier-staging'
readonly LEGACY_PRODUCTION_ROOT='/www/wwwroot/chantier'

# Modèle de permissions décrit dans docs/development/environments.md :
# - release : 2750 (lecture et traversée du groupe, aucune écriture) ;
# - bootstrap/cache : 2770 (PHP-FPM écrit ses caches) ;
# - fichiers extraits : umask 027 (lecture du groupe seulement).
readonly RELEASE_MODE='2750'
readonly BOOTSTRAP_CACHE_MODE='2770'

# Marqueur de propriété écrit dans tout répertoire créé par l'exécution
# courante. Le nettoyage ne supprime un répertoire que si ce marqueur contient
# le jeton unique de l'exécution : un nom de chemin prévisible ne suffit jamais.
readonly OWNER_MARKER='.c2me-deploy-owner'

# Verrou partagé avec le rollback applicatif (scripts/ops/rollback.sh). Il
# protège la publication des releases et l'activation de `current` contre une
# opération concurrente. Il est créé atomiquement par mkdir et n'est jamais
# supprimé s'il appartient à une autre exécution.
readonly OPERATION_LOCK_NAME='.release-operation.lock'

environment=""
release_id=""
version=""
commit_sha=""
tree_sha=""
artifact_id=""
expected_sha=""
package=""
expected_path=""
route_cache="true"
queue_restart="false"
dry_run=0
preflight=0

root=""
shared=""
php_bin=""
php_version=""
release_dir=""
incoming_dir=""
incoming_created=0
release_created=0
activated=0
log_ready=0
deployment_failure_status="failure"
entries_file=""
verbose_file=""
run_token=""
current_host=""
operation_lock_dir=""
operation_lock_token=""
operation_lock_owned=0

usage() {
  cat <<'USAGE'
Usage : remote-deploy.sh --environment <staging|production> --release-id <id> \
          --version <tag> --commit <sha> --tree <sha> --artifact-id <id> \
          --sha256 <empreinte> --package <fichier> --expected-path <chemin> \
          [--route-cache <true|false>] [--queue-restart <true|false>] [--dry-run]

Mode diagnostic :
  remote-deploy.sh --environment <staging|production> --expected-path <chemin> \
          --preflight

Le mode --preflight vérifie uniquement le binaire PHP 8.4 configuré et
n'effectue aucune écriture.
USAGE
}

die() {
  printf 'ERREUR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

# Ligne JSON du journal. Ne reçoit et n'écrit que des valeurs déjà validées par
# le script ; aucun contenu de fichier n'y est injecté.
deployment_log_line() {
  local status="$1"

  printf '{"timestamp":"%s","environment":"%s","release":"%s","version":"%s","commit":"%s","artifact_id":"%s","sha256":"%s","status":"%s","user":"%s"}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    "$environment" \
    "$release_id" \
    "$version" \
    "$commit_sha" \
    "$artifact_id" \
    "$expected_sha" \
    "$status" \
    "$(id -un)"
}

# Journalise uniquement si le chemin de journal a été jugé sûr par
# prepare_logging(). N'écrit jamais dans .env ni dans storage et ne suit jamais
# un lien symbolique.
deployment_log() {
  local status="$1"

  if [[ "$log_ready" -ne 1 || -z "$shared" ]]; then
    return 0
  fi

  local log_file="$shared/deployment.log"

  if [[ -L "$log_file" ]]; then
    printf 'ERREUR: journal symbolique détecté, écriture refusée : %s\n' "$log_file" >&2
    return 1
  fi

  if [[ -e "$log_file" && ! -f "$log_file" ]]; then
    printf 'ERREUR: journal non régulier, écriture refusée : %s\n' "$log_file" >&2
    return 1
  fi

  (
    umask 077

    if [[ -e "$log_file" ]]; then
      deployment_log_line "$status" >> "$log_file"
    else
      # noclobber empêche de créer le journal à travers un lien apparu entre
      # le contrôle de prepare_logging() et cette écriture.
      set -C
      deployment_log_line "$status" > "$log_file"
    fi
  )
}

prepare_logging() {
  [[ -n "$root" ]] || return 0

  # Pré-déploiement : `shared` n'a pas encore été provisionné, le déploiement
  # échouera plus loin faute de stockage partagé. Aucun journal n'est exigé.
  if [[ ! -e "$shared" && ! -L "$shared" ]]; then
    return 0
  fi

  if [[ ! -d "$root" || -L "$root" ]]; then
    die "racine de déploiement invalide ou symbolique : $root"
  fi

  # `shared` existe (y compris sous forme de lien cassé) : il doit s'agir d'un
  # répertoire réel. La journalisation devient obligatoire.
  if [[ -L "$shared" ]]; then
    die "répertoire shared symbolique interdit : journalisation impossible"
  fi

  if [[ ! -d "$shared" ]]; then
    die "répertoire shared invalide : journalisation impossible"
  fi

  if [[ ! -w "$shared" ]]; then
    die "répertoire shared non accessible en écriture : journal obligatoire"
  fi

  local log_file="$shared/deployment.log"

  if [[ -L "$log_file" ]]; then
    die "journal symbolique interdit : $log_file"
  fi

  if [[ -e "$log_file" ]]; then
    if [[ ! -f "$log_file" ]]; then
      die "journal non régulier : $log_file"
    fi

    if [[ ! -w "$log_file" ]]; then
      die "journal non accessible en écriture : $log_file"
    fi
  fi

  log_ready=1

  # Une écriture réelle prouve que le journal est utilisable (permissions,
  # espace disque, système de fichiers non figé) avant toute action métier.
  if ! deployment_log "start"; then
    log_ready=0
    die "journal de déploiement inutilisable : $log_file"
  fi
}

# Politique de permissions de shared/.env :
# - écriture de groupe interdite ;
# - écriture, lecture ou exécution par les autres utilisateurs interdites ;
# - lecture de groupe tolérée mais inutile (600 recommandé, 640 accepté).
#
# Le déploiement exécute `config:cache` avec le compte technique : la
# configuration compilée (bootstrap/cache/config.php) contient les valeurs
# nécessaires. Laravel ne charge pas `.env` lorsque la configuration est en
# cache, donc PHP-FPM n'a pas besoin de lire ce fichier à l'exécution.
env_mode_is_secure() {
  local mode="${1:-}"

  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1

  (( (8#$mode & 8#0020) == 0 && (8#$mode & 8#0007) == 0 ))
}

# Aucun droit pour les autres utilisateurs : un mode 777 ou 775 est refusé.
mode_denies_access_to_others() {
  local mode="${1:-}"

  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1

  (( (8#$mode & 8#0007) == 0 ))
}

# Le groupe de l'environnement doit pouvoir lire et traverser le répertoire :
# c'est le groupe du processus PHP-FPM (www).
mode_grants_group_access() {
  local mode="${1:-}"

  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1

  (( (8#$mode & 8#0050) == 8#0050 ))
}

# Écriture de groupe nécessaire pour PHP-FPM (storage, bootstrap/cache).
mode_is_group_writable() {
  local mode="${1:-}"

  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1

  (( (8#$mode & 8#0020) == 8#0020 ))
}

# Un ancien chemin ne doit jamais être accepté, même s'il ne correspond pas au
# chemin de l'environnement courant : le message d'erreur reste explicite.
path_is_legacy() {
  local candidate="${1:-}"

  [[ "$candidate" == "$LEGACY_STAGING_ROOT" || "$candidate" == "$LEGACY_PRODUCTION_ROOT" ]]
}

# Contrôle les permissions des répertoires créés manuellement lors de la
# préparation du serveur. Aucun changement de groupe n'est effectué ici : le
# déploiement ne dispose d'aucun privilège d'élévation.
verify_shared_layout_permissions() {
  local mode

  mode="$(stat -c '%a' "$root")"
  mode_denies_access_to_others "$mode" \
    || die "racine accessible aux autres utilisateurs (mode $mode) : 2770 attendu pour $root"
  mode_grants_group_access "$mode" \
    || die "racine non accessible au groupe PHP-FPM (mode $mode) : 2770 attendu pour $root"

  mode="$(stat -c '%a' "$root/releases")"
  mode_denies_access_to_others "$mode" \
    || die "releases accessible aux autres utilisateurs (mode $mode) : 2770 attendu pour $root/releases"

  mode="$(stat -c '%a' "$shared")"
  mode_denies_access_to_others "$mode" \
    || die "shared accessible aux autres utilisateurs (mode $mode) : 2770 attendu pour $shared"
  mode_grants_group_access "$mode" \
    || die "shared non accessible au groupe PHP-FPM (mode $mode) : lecture et traversée attendues"

  mode="$(stat -c '%a' "$shared/storage")"
  mode_denies_access_to_others "$mode" \
    || die "stockage partagé accessible aux autres utilisateurs (mode $mode) : 2770 attendu pour $shared/storage"
  mode_grants_group_access "$mode" \
    || die "stockage partagé non accessible au groupe PHP-FPM (mode $mode)"
  mode_is_group_writable "$mode" \
    || die "stockage partagé non inscriptible par le groupe PHP-FPM (mode $mode) : 2770 attendu"

  [[ ! -L "$shared/.env" ]] || die "fichier .env partagé symbolique interdit : $shared/.env"

  mode="$(stat -c '%a' "$shared/.env")"

  env_mode_is_secure "$mode" \
    || die "permissions du .env trop permissives (mode $mode) : écriture de groupe et accès des autres utilisateurs interdits (600 recommandé, 640 accepté)"
}

# Modèle de permissions d'une release : le groupe de l'environnement lit le code
# et traverse le répertoire, mais ne peut pas modifier les fichiers déployés.
# Seul bootstrap/cache est inscriptible par le groupe, pour PHP-FPM.
apply_release_permissions() {
  local directory="$1"

  mkdir -p "$directory/bootstrap/cache" || die "création de bootstrap/cache impossible : $directory"

  chmod "$BOOTSTRAP_CACHE_MODE" "$directory/bootstrap/cache" \
    || die "permissions de bootstrap/cache impossibles : $directory/bootstrap/cache"

  chmod "$RELEASE_MODE" "$directory" \
    || die "permissions du répertoire de release impossibles : $directory"
}

verify_release_permissions() {
  local directory="$1"
  local mode
  local entry

  [[ -d "$directory" && ! -L "$directory" ]] || die "répertoire de release invalide : $directory"

  mode="$(stat -c '%a' "$directory")"
  mode_denies_access_to_others "$mode" \
    || die "release accessible aux autres utilisateurs (mode $mode) : $RELEASE_MODE attendu"
  mode_grants_group_access "$mode" \
    || die "release non lisible par le groupe PHP-FPM (mode $mode) : $RELEASE_MODE attendu"

  mode="$(stat -c '%a' "$directory/bootstrap/cache")"
  mode_denies_access_to_others "$mode" \
    || die "bootstrap/cache accessible aux autres utilisateurs (mode $mode) : $BOOTSTRAP_CACHE_MODE attendu"
  mode_is_group_writable "$mode" \
    || die "bootstrap/cache non inscriptible par le groupe PHP-FPM (mode $mode) : $BOOTSTRAP_CACHE_MODE attendu"

  # Contrôle ciblé de deux points d'entrée lus à chaque requête HTTP : un
  # fichier non lisible par le groupe rendrait le site indisponible.
  for entry in artisan public/index.php; do
    mode="$(stat -c '%a' "$directory/$entry")"
    (( (8#$mode & 8#0040) == 8#0040 )) \
      || die "$entry non lisible par le groupe PHP-FPM (mode $mode)"
  done
}

# Jeton unique de l'exécution. Il est écrit dans chaque répertoire créé pour
# prouver la propriété de création sans se fier au nom du chemin.
# ---------------------------------------------------------------------------
# Verrou partagé déploiement / rollback
# ---------------------------------------------------------------------------

resolve_host_identity() {
  local host

  host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
  host="$(printf '%s' "$host" | tr -cd 'A-Za-z0-9._-')"

  case "${host,,}" in
    '' | 'unknown' | 'localhost' | 'localhost.localdomain')
      host=""
      ;;
  esac

  [[ -n "$host" ]] \
    || die "identité d'hôte non déterminable : définir un hostname stable, unique et non réservé."

  current_host="$host"
}

# Acquiert le verrou partagé avant toute création ou activation de release.
# Un verrou existant n'est jamais supprimé automatiquement : une interruption
# brutale nécessite une intervention explicite (rollback.sh unlock).
acquire_operation_lock() {
  local lock_dir="$shared/$OPERATION_LOCK_NAME"

  if [[ -e "$lock_dir" || -L "$lock_dir" ]]; then
    if [[ -L "$lock_dir" || ! -d "$lock_dir" ]]; then
      die "verrou d'opération invalide (non répertoire ou symbolique) : $lock_dir"
    fi

    local lock_host lock_pid lock_operation lock_started
    lock_host="$(cat "$lock_dir/host" 2>/dev/null || true)"
    lock_pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
    lock_operation="$(cat "$lock_dir/operation" 2>/dev/null || true)"
    lock_started="$(cat "$lock_dir/started_at" 2>/dev/null || true)"

    if [[ -z "$lock_host" || "${lock_host,,}" == 'unknown' || "${lock_host,,}" == 'localhost' || "${lock_host,,}" == 'localhost.localdomain' ]]; then
      die "verrou sans hôte fiable (absent ou réservé) : opération refusée. Intervention manuelle requise."
    fi

    if [[ "$lock_host" != "$current_host" ]]; then
      die "verrou détenu par l'hôte $lock_host, pas par $current_host : opération refusée."
    fi

    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; then
      die "opération concurrente en cours (${lock_operation:-inconnue}, pid $lock_pid, depuis ${lock_started:-date inconnue}) : déploiement refusé."
    fi

    die "verrou orphelin détecté (${lock_operation:-inconnue}, pid ${lock_pid:-inconnu}) : suppression automatique interdite. Vérifier l'absence de processus, puis exécuter 'scripts/ops/rollback.sh unlock --env ${environment:-<env>} --confirm-stale-lock' sur cet hôte."
  fi

  if ! mkdir -- "$lock_dir" 2>/dev/null; then
    die "verrou d'opération déjà détenu (course concurrente) : déploiement refusé."
  fi

  operation_lock_dir="$lock_dir"
  operation_lock_owned=1

  local random=""
  random="$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || true)"
  [[ -n "$random" ]] || random="$$-${RANDOM}-${RANDOM}-$(date -u '+%s')"
  operation_lock_token="deploy-$$-${random}"

  chmod 0700 "$lock_dir" 2>/dev/null || true
  printf '%s\n' "$$" >"$lock_dir/pid" 2>/dev/null || true
  printf '%s\n' "$current_host" >"$lock_dir/host" 2>/dev/null || true
  printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"$lock_dir/started_at" 2>/dev/null || true
  printf '%s\n' 'deploy' >"$lock_dir/operation" 2>/dev/null || true
  printf '%s\n' "$operation_lock_token" >"$lock_dir/token" 2>/dev/null || true
  chmod 0600 "$lock_dir/pid" "$lock_dir/host" "$lock_dir/started_at" "$lock_dir/operation" "$lock_dir/token" 2>/dev/null || true
}

# Ne libère que le verrou créé par cette exécution : un jeton différent prouve
# qu'il appartient à un autre processus et interdit toute suppression.
release_operation_lock() {
  [[ "$operation_lock_owned" -eq 1 && -n "$operation_lock_dir" ]] || return 0

  local recorded=""
  recorded="$(cat "$operation_lock_dir/token" 2>/dev/null || true)"

  if [[ -n "$recorded" && "$recorded" == "$operation_lock_token" ]]; then
    rm -rf -- "$operation_lock_dir" 2>/dev/null || true
  else
    printf 'AVERTISSEMENT: verrou non supprimé (jeton différent) : %s\n' "$operation_lock_dir" >&2
  fi

  operation_lock_owned=0
  operation_lock_dir=""
}

init_run_token() {
  [[ -n "$run_token" ]] && return 0

  local random=""

  random="$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || true)"

  [[ -n "$random" ]] || random="$$-${RANDOM}-${RANDOM}-$(date -u '+%s')"

  run_token="c2me-${release_id:-unknown}-$$-${random}"
}

# Écrit le marqueur de propriété dans un répertoire fraîchement créé. Le
# marqueur est créé sans écrasement (noclobber) et n'est jamais un lien.
claim_created_directory() {
  local directory="$1"
  local marker="$directory/$OWNER_MARKER"

  [[ -n "$run_token" ]] || return 1
  [[ -d "$directory" && ! -L "$directory" ]] || return 1

  if ! ( set -C; printf '%s\n' "$run_token" > "$marker" ) 2>/dev/null; then
    return 1
  fi

  chmod 0600 "$marker" 2>/dev/null || true
}

# Vérifie que le répertoire a bien été créé par cette exécution : marqueur
# régulier, non symbolique, dont le contenu correspond au jeton courant.
directory_owned_by_run() {
  local directory="$1"
  local marker="$directory/$OWNER_MARKER"
  local recorded=""

  [[ -n "$run_token" ]] || return 1
  [[ -d "$directory" && ! -L "$directory" ]] || return 1
  [[ -f "$marker" && ! -L "$marker" ]] || return 1

  recorded="$(cat -- "$marker" 2>/dev/null || true)"

  [[ "$recorded" == "$run_token" ]]
}

# Conserve un résidu plutôt que de risquer une suppression destructive.
retain_residue() {
  local directory="$1"

  printf 'AVERTISSEMENT: résidu conservé, suppression non sûre : %s\n' "$directory" >&2
  deployment_log "incomplete-retained" || true
}

# Ne supprime que les répertoires dont cette exécution prouve la propriété.
# Une release préexistante, une release active, `current` et `shared/` ne sont
# jamais supprimés. Une interruption entre la création et le positionnement de
# l'indicateur en mémoire reste couverte : la décision repose sur le marqueur
# de propriété, pas sur l'indicateur seul.
cleanup_incomplete() {
  local active=""

  if [[ -n "$incoming_dir" && -d "$incoming_dir" && ! -L "$incoming_dir" ]]; then
    case "$incoming_dir" in
      "$root/releases/.incoming-"*)
        if directory_owned_by_run "$incoming_dir"; then
          rm -rf -- "$incoming_dir" || retain_residue "$incoming_dir"
        elif [[ "$incoming_created" -eq 1 ]]; then
          retain_residue "$incoming_dir"
        fi
        ;;
      *)
        if [[ "$incoming_created" -eq 1 ]]; then
          retain_residue "$incoming_dir"
        fi
        ;;
    esac
  fi

  if [[ "$activated" -eq 0 && -n "$release_dir" && -d "$release_dir" && ! -L "$release_dir" ]]; then
    case "$release_dir" in
      "$root/releases/"*)
        if directory_owned_by_run "$release_dir"; then
          active="$(readlink -f "$root/current" 2>/dev/null || true)"

          if [[ "$active" != "$(readlink -f "$release_dir" 2>/dev/null || true)" ]]; then
            rm -rf -- "$release_dir" || retain_residue "$release_dir"
          fi
        elif [[ "$release_created" -eq 1 ]]; then
          retain_residue "$release_dir"
        fi
        ;;
      *)
        if [[ "$release_created" -eq 1 ]]; then
          retain_residue "$release_dir"
        fi
        ;;
    esac
  fi

  return 0
}

on_exit() {
  local status=$?

  cleanup_incomplete || true
  release_operation_lock || true
  rm -f -- "${entries_file:-}" "${verbose_file:-}" 2>/dev/null || true

  if [[ "$status" -ne 0 ]]; then
    deployment_log "${deployment_failure_status:-failure}" || true
  fi

  exit "$status"
}

on_signal() {
  exit "$1"
}

# Ignore temporairement les signaux pendant une section critique de création
# ou d'activation, afin qu'un signal ne puisse pas laisser un indicateur
# incohérent avec l'état du système de fichiers.
mask_signals() {
  trap '' HUP INT TERM
}

unmask_signals() {
  trap 'on_signal 129' HUP
  trap 'on_signal 130' INT
  trap 'on_signal 143' TERM
}

install_traps() {
  trap on_exit EXIT
  unmask_signals
}

resolve_php_bin() {
  php_bin="${DEPLOY_PHP_BIN:-}"

  if [[ -z "$php_bin" ]]; then
    php_bin="$(command -v php8.4 || true)"
  fi

  [[ -n "$php_bin" && -x "$php_bin" ]] || die "binaire PHP 8.4 introuvable : définir DEPLOY_PHP_BIN après vérification sur le serveur"
}

assert_php_version() {
  local reported

  reported="$("$php_bin" -r 'echo PHP_VERSION;' 2>/dev/null || true)"

  if [[ ! "$reported" =~ ^8\.4\.[0-9]+$ ]]; then
    die "PHP 8.4 requis pour le déploiement, version détectée : ${reported:-inconnue}"
  fi

  php_version="$reported"
}

# Envoie le signal de redémarrage aux workers uniquement après l'activation.
# La fonction vérifie elle-même que `current` pointe vers la nouvelle release :
# une erreur de séquencement ne peut donc pas redémarrer les workers sur
# l'ancien code. Un échec de la commande est journalisé avec un statut distinct
# et la release déjà activée est conservée.
restart_workers_after_activation() {
  [[ "$queue_restart" == "true" ]] || return 0

  if [[ "$activated" -ne 1 ]]; then
    die "queue:restart refusé : la release n'est pas encore activée"
  fi

  local active_release
  local target_release

  active_release="$(readlink -f "$root/current" 2>/dev/null || true)"
  target_release="$(readlink -f "$release_dir" 2>/dev/null || true)"

  if [[ -z "$active_release" || "$active_release" != "$target_release" ]]; then
    die "queue:restart refusé : current ne pointe pas vers la release $release_id"
  fi

  if ! (
    cd "$release_dir" || exit 1
    "$php_bin" artisan queue:restart
  ); then
    deployment_failure_status="activated-queue-restart-failed"
    die "redémarrage des workers impossible après activation de $release_id"
  fi
}

# Contrôle les types d'entrées avant toute extraction : les liens symboliques,
# liens physiques et fichiers spéciaux sont refusés.
inspect_archive() {
  local listing="$1"
  local verbose="$2"

  if grep -Eq '^[lhbcp]' "$verbose"; then
    die "type d'entrée interdit dans le paquet (lien symbolique, lien physique ou fichier spécial)"
  fi

  if grep -Eq '(^/)|(^|/)\.\.(/|$)' "$listing"; then
    die "chemin absolu ou traversée de répertoire détecté dans le paquet"
  fi

  grep -Fqx -- './artisan' "$listing" || die "paquet incomplet : artisan absent"
  grep -Fqx -- './vendor/autoload.php' "$listing" || die "paquet incomplet : vendor absent"
  grep -Fqx -- './public/index.php' "$listing" || die "paquet incomplet : public/index.php absent"

  if grep -Eq '(^|/)\.env($|\.)' "$listing"; then
    die "le paquet ne doit pas contenir de fichier .env"
  fi

  if grep -Eq '(^|/)storage/' "$listing"; then
    die "le paquet ne doit pas contenir le dossier storage"
  fi
}

# Vérifie après extraction qu'aucune entrée ne sort du répertoire cible.
verify_extraction() {
  local directory="$1"
  local directory_real
  local resolved
  local path

  directory_real="$(realpath -m -- "$directory")"

  if [[ -n "$(find "$directory" -type l -print -quit)" ]]; then
    die "lien symbolique extrait interdit"
  fi

  if [[ -n "$(find "$directory" -type f -links +1 -print -quit)" ]]; then
    die "lien physique extrait interdit"
  fi

  if [[ -n "$(find "$directory" \( -type b -o -type c -o -type p -o -type s \) -print -quit)" ]]; then
    die "entrée spéciale extraite interdite"
  fi

  while IFS= read -r -d '' path; do
    resolved="$(realpath -m -- "$path")"

    case "$resolved" in
      "$directory_real"/*) ;;
      *) die "extraction hors du répertoire de release : $path" ;;
    esac
  done < <(find "$directory" -mindepth 1 -print0)
}

# Prépare les caches de la nouvelle release, la publie, bascule `current`,
# puis envoie le signal de redémarrage des workers. Appelée par main() après
# l'extraction et la préparation du répertoire incoming.
prepare_and_activate_release() {
  local tmp_link
  local mode

  log "PHP $php_version"

  (
    set -e
    cd "$incoming_dir"

    "$php_bin" artisan config:cache
    "$php_bin" artisan view:cache

    if [[ "$route_cache" == "true" ]]; then
      "$php_bin" artisan route:cache
    fi
  ) || die "préparation des caches de la release impossible : $release_id"

  # La politique .env 600 suppose une configuration compilée : sans elle,
  # Laravel tenterait de charger `.env` à l'exécution sous PHP-FPM, qui n'a pas
  # le droit de le lire. Le fichier doit aussi rester lisible par le groupe.
  [[ -f "$incoming_dir/bootstrap/cache/config.php" ]] \
    || die "configuration compilée absente après config:cache"

  mode="$(stat -c '%a' "$incoming_dir/bootstrap/cache/config.php")"

  mode_denies_access_to_others "$mode" \
    || die "configuration compilée accessible aux autres utilisateurs (mode $mode)"
  (( (8#$mode & 8#0020) == 0 )) \
    || die "configuration compilée modifiable par le groupe (mode $mode)"
  (( (8#$mode & 8#0040) == 8#0040 )) \
    || die "configuration compilée non lisible par le groupe PHP-FPM (mode $mode)"

  cat > "$incoming_dir/release.json" <<JSON
{
    "environment": "$environment",
    "release": "$release_id",
    "version": "$version",
    "commit_sha": "$commit_sha",
    "tree_sha": "$tree_sha",
    "artifact_id": "$artifact_id",
    "sha256": "$expected_sha",
    "deployed_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
JSON

  chmod 0640 "$incoming_dir/release.json"

  # Publication atomique du répertoire de release, puis activation du lien.
  mask_signals

  if ! mv -T -- "$incoming_dir" "$release_dir"; then
    unmask_signals
    die "publication de la release impossible : $release_id"
  fi

  release_created=1
  incoming_created=0
  incoming_dir=""

  tmp_link="$root/.current.$$"

  if ! ln -sfn "$release_dir" "$tmp_link"; then
    unmask_signals
    die "création du lien temporaire current impossible"
  fi

  if ! mv -Tf "$tmp_link" "$root/current"; then
    rm -f -- "$tmp_link"
    unmask_signals
    die "activation de la release impossible : $release_id"
  fi

  activated=1
  unmask_signals

  # Le marqueur de propriété ne fait pas partie du contenu applicatif de la
  # release activée. Son retrait n'est pas critique : en cas d'échec, un
  # fichier caché inoffensif reste présent et la release active est conservée.
  rm -f -- "$release_dir/$OWNER_MARKER" \
    || log "avertissement: marqueur de propriété non supprimé : $release_dir/$OWNER_MARKER"

  # Le redémarrage des workers intervient après l'activation : `current` pointe
  # déjà vers la nouvelle release, et un échec conserve cette release active.
  restart_workers_after_activation

  deployment_log "success"
  log "release $release_id activée pour $environment"
}

main() {
  set -euo pipefail

  # Les fichiers extraits restent lisibles par le groupe de l'environnement
  # (PHP-FPM) sans être accessibles aux autres utilisateurs. Le journal utilise
  # un umask plus restrictif dans son propre sous-shell.
  umask 027

  install_traps

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --environment) environment="${2:-}"; shift 2 ;;
      --release-id) release_id="${2:-}"; shift 2 ;;
      --version) version="${2:-}"; shift 2 ;;
      --commit) commit_sha="${2:-}"; shift 2 ;;
      --tree) tree_sha="${2:-}"; shift 2 ;;
      --artifact-id) artifact_id="${2:-}"; shift 2 ;;
      --sha256) expected_sha="${2:-}"; shift 2 ;;
      --package) package="${2:-}"; shift 2 ;;
      --expected-path) expected_path="${2:-}"; shift 2 ;;
      --route-cache) route_cache="${2:-}"; shift 2 ;;
      --queue-restart) queue_restart="${2:-}"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      --preflight) preflight=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; exit 64 ;;
    esac
  done

  case "$environment" in
    staging)
      root="$STAGING_ROOT"
      expected_user="$STAGING_USER"
      ;;
    production)
      root="$PRODUCTION_ROOT"
      expected_user="$PRODUCTION_USER"
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac

  shared="$root/shared"

  if path_is_legacy "$expected_path"; then
    die "chemin obsolète refusé pour $environment : $expected_path (chemin aaPanel attendu : $root)"
  fi

  [[ "$expected_path" == "$root" ]] || die "chemin cible refusé pour $environment : chemin attendu $root"

  if [[ "$preflight" -eq 1 ]]; then
    resolve_php_bin
    assert_php_version
    printf 'php-version=%s\n' "$php_version"
    log "preflight OK pour $environment : PHP $php_version"

    exit 0
  fi

  prepare_logging

  if [[ "$dry_run" -ne 1 ]]; then
    actual_user="$(id -un)"

    [[ "$actual_user" == "$expected_user" ]] || die "utilisateur refusé pour $environment : $actual_user"
  fi

  [[ "$release_id" =~ ^[a-z0-9][a-z0-9._-]{2,80}$ ]] || die "identifiant de release invalide : $release_id"
  [[ "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.[1-9][0-9]*)?$ ]] || die "version invalide : $version"
  [[ "$commit_sha" =~ ^[0-9a-f]{40}$ ]] || die "commit invalide : $commit_sha"
  [[ "$tree_sha" =~ ^[0-9a-f]{40}$ ]] || die "arbre Git invalide : $tree_sha"
  [[ "$artifact_id" =~ ^[0-9]+$ ]] || die "identifiant d'artefact invalide : $artifact_id"
  [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || die "empreinte SHA-256 invalide"

  case "$route_cache" in true|false) ;; *) die "valeur route-cache invalide : $route_cache" ;; esac
  case "$queue_restart" in true|false) ;; *) die "valeur queue-restart invalide : $queue_restart" ;; esac

  [[ -n "$package" && -f "$package" && -r "$package" ]] || die "paquet introuvable ou illisible"

  package_real="$(realpath -m -- "$package")"
  tmp_root="$(realpath -m -- "${TMPDIR:-/tmp}")"

  case "$package_real" in
    "$tmp_root"/*) ;;
    *) die "le paquet doit être transféré dans $tmp_root" ;;
  esac

  actual_sha="$(sha256sum "$package_real" | awk '{print $1}')"

  [[ "$actual_sha" == "$expected_sha" ]] || die "empreinte SHA-256 du paquet incorrecte"

  entries_file="$(mktemp "${TMPDIR:-/tmp}/chantier-entries.XXXXXX")"
  verbose_file="$(mktemp "${TMPDIR:-/tmp}/chantier-verbose.XXXXXX")"

  tar -tzf "$package_real" > "$entries_file" || die "paquet illisible"
  tar -tvzf "$package_real" > "$verbose_file" || die "paquet illisible"

  inspect_archive "$entries_file" "$verbose_file"

  if [[ "$dry_run" -eq 1 ]]; then
    log "dry-run OK pour $environment : release $release_id, paquet vérifié"
    exit 0
  fi

  [[ -d "$root" ]] || die "répertoire d'installation introuvable : $root"
  [[ -d "$root/releases" ]] || die "répertoire releases introuvable : $root/releases"
  [[ -d "$shared/storage" ]] || die "stockage partagé introuvable : $shared/storage"
  [[ -f "$shared/.env" ]] || die "fichier .env partagé introuvable : $shared/.env"

  app_env="$(grep -E '^APP_ENV=' "$shared/.env" | head -n 1 | cut -d= -f2- | tr -d '"' || true)"

  [[ "$app_env" == "$environment" ]] || die "APP_ENV du .env ne correspond pas à l'environnement attendu"

  verify_shared_layout_permissions

  resolve_host_identity
  acquire_operation_lock

  release_dir="$root/releases/$release_id"

  [[ ! -e "$release_dir" ]] || die "la release existe déjà : $release_id"

  # Répertoire unique créé par mktemp : une collision ne peut pas désigner un
  # répertoire préexistant ou appartenant à une autre exécution. Les signaux
  # sont ignorés pendant la création et le marquage de propriété.
  init_run_token
  mask_signals

  if ! incoming_dir="$(mktemp -d "$root/releases/.incoming-${release_id}-XXXXXX")"; then
    unmask_signals
    die "création du répertoire d'extraction impossible"
  fi

  incoming_created=1

  if ! claim_created_directory "$incoming_dir"; then
    unmask_signals
    die "marquage de propriété du répertoire d'extraction impossible"
  fi

  unmask_signals

  [[ -d "$incoming_dir" && ! -L "$incoming_dir" ]] || die "répertoire d'extraction invalide : $incoming_dir"
  [[ "$(stat -c '%u' "$incoming_dir")" == "$(id -u)" ]] || die "répertoire d'extraction non détenu par l'utilisateur courant"

  tar -xzf "$package_real" -C "$incoming_dir" --no-same-owner --no-same-permissions

  verify_extraction "$incoming_dir"

  # Le paquet ne doit pas avoir remplacé le marqueur de propriété créé par
  # cette exécution. Un marqueur altéré interdit la publication.
  directory_owned_by_run "$incoming_dir" \
    || die "marqueur de propriété du répertoire d'extraction invalide"

  [[ -f "$incoming_dir/artisan" ]] || die "release incomplète : artisan absent"
  [[ -f "$incoming_dir/vendor/autoload.php" ]] || die "release incomplète : vendor absent"
  [[ -f "$incoming_dir/public/index.php" ]] || die "release incomplète : public/index.php absent"

  ln -s "$shared/.env" "$incoming_dir/.env"
  ln -s "$shared/storage" "$incoming_dir/storage"
  ln -s ../storage/app/public "$incoming_dir/public/storage"

  [[ -d "$incoming_dir/storage" ]] || die "lien storage invalide"
  [[ -w "$incoming_dir/storage" ]] || die "stockage partagé non accessible en écriture"

  # Le groupe de l'environnement doit pouvoir lire la release et écrire dans
  # bootstrap/cache : sans cela, PHP-FPM ne peut pas servir le site.
  apply_release_permissions "$incoming_dir"
  verify_release_permissions "$incoming_dir"

  resolve_php_bin
  assert_php_version

  prepare_and_activate_release
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
