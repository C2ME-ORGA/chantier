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

readonly STAGING_ROOT='/www/wwwroot/chantier-staging'
readonly PRODUCTION_ROOT='/www/wwwroot/chantier'
readonly STAGING_USER='c2me-deploy-staging'
readonly PRODUCTION_USER='c2me-deploy-production'

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
entries_file=""
verbose_file=""

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

# Journalise uniquement si le chemin de journal a été jugé sûr par
# prepare_logging(). N'écrit jamais dans .env ni dans storage.
deployment_log() {
  local status="$1"

  if [[ "$log_ready" -ne 1 || -z "$shared" ]]; then
    return 0
  fi

  local log_file="$shared/deployment.log"

  (
    umask 077
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
  ) >> "$log_file"
}

prepare_logging() {
  [[ -n "$root" ]] || return 0

  if [[ ! -e "$shared" ]]; then
    return 0
  fi

  if [[ ! -d "$root" || -L "$root" ]]; then
    die "racine de déploiement invalide ou symbolique : $root"
  fi

  if [[ ! -d "$shared" || -L "$shared" ]]; then
    die "répertoire shared invalide ou symbolique : $shared"
  fi

  if [[ ! -w "$shared" ]]; then
    die "répertoire shared non accessible en écriture : journal obligatoire"
  fi

  local log_file="$shared/deployment.log"

  if [[ -e "$log_file" || -L "$log_file" ]]; then
    if [[ -L "$log_file" ]]; then
      die "journal symbolique interdit : $log_file"
    fi

    if [[ ! -f "$log_file" ]]; then
      die "journal non régulier : $log_file"
    fi

    if [[ ! -w "$log_file" ]]; then
      die "journal non accessible en écriture : $log_file"
    fi
  fi

  log_ready=1
}

# Politique de permissions de shared/.env :
# - écriture de groupe interdite ;
# - écriture, lecture ou exécution par les autres interdites ;
# - lecture de groupe autorisée (600, 640, 700, 750).
env_mode_is_secure() {
  local mode="${1:-}"

  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1

  (( (8#$mode & 8#0020) == 0 && (8#$mode & 8#0007) == 0 ))
}

# Ne supprime que les répertoires créés par l'exécution courante. Une release
# préexistante, une release active, `current` et `shared/` ne sont jamais
# supprimés.
cleanup_incomplete() {
  if [[ "$incoming_created" -eq 1 && -n "$incoming_dir" && -d "$incoming_dir" ]]; then
    case "$incoming_dir" in
      "$root/releases/.incoming-"*) rm -rf -- "$incoming_dir" ;;
    esac
  fi

  if [[ "$release_created" -eq 1 && "$activated" -eq 0 && -n "$release_dir" && -d "$release_dir" ]]; then
    local active
    active="$(readlink -f "$root/current" 2>/dev/null || true)"

    if [[ "$active" != "$(readlink -f "$release_dir" 2>/dev/null || true)" ]]; then
      case "$release_dir" in
        "$root/releases/"*) rm -rf -- "$release_dir" ;;
      esac
    fi
  fi
}

on_exit() {
  local status=$?

  cleanup_incomplete || true
  rm -f -- "${entries_file:-}" "${verbose_file:-}" 2>/dev/null || true

  if [[ "$status" -ne 0 ]]; then
    deployment_log "failure" || true
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

main() {
  set -euo pipefail

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

  env_mode="$(stat -c '%a' "$shared/.env")"

  env_mode_is_secure "$env_mode" || die "permissions du .env trop permissives (mode $env_mode) : écriture de groupe et accès des autres utilisateurs interdits"

  release_dir="$root/releases/$release_id"

  [[ ! -e "$release_dir" ]] || die "la release existe déjà : $release_id"

  # Répertoire unique créé par mktemp : une collision ne peut pas désigner un
  # répertoire préexistant ou appartenant à une autre exécution.
  mask_signals

  if ! incoming_dir="$(mktemp -d "$root/releases/.incoming-${release_id}-XXXXXX")"; then
    unmask_signals
    die "création du répertoire d'extraction impossible"
  fi

  incoming_created=1
  unmask_signals

  [[ -d "$incoming_dir" && ! -L "$incoming_dir" ]] || die "répertoire d'extraction invalide : $incoming_dir"
  [[ "$(stat -c '%u' "$incoming_dir")" == "$(id -u)" ]] || die "répertoire d'extraction non détenu par l'utilisateur courant"

  tar -xzf "$package_real" -C "$incoming_dir" --no-same-owner --no-same-permissions

  verify_extraction "$incoming_dir"

  [[ -f "$incoming_dir/artisan" ]] || die "release incomplète : artisan absent"
  [[ -f "$incoming_dir/vendor/autoload.php" ]] || die "release incomplète : vendor absent"
  [[ -f "$incoming_dir/public/index.php" ]] || die "release incomplète : public/index.php absent"

  ln -s "$shared/.env" "$incoming_dir/.env"
  ln -s "$shared/storage" "$incoming_dir/storage"
  ln -s ../storage/app/public "$incoming_dir/public/storage"

  [[ -d "$incoming_dir/storage" ]] || die "lien storage invalide"
  [[ -w "$incoming_dir/storage" ]] || die "stockage partagé non accessible en écriture"
  [[ -d "$incoming_dir/bootstrap/cache" ]] || die "répertoire bootstrap/cache absent"

  mkdir -p "$incoming_dir/bootstrap/cache"

  [[ -w "$incoming_dir/bootstrap/cache" ]] || die "bootstrap/cache non accessible en écriture"

  resolve_php_bin
  assert_php_version

  log "PHP $php_version"

  (
    cd "$incoming_dir"

    "$php_bin" artisan config:cache
    "$php_bin" artisan view:cache

    if [[ "$route_cache" == "true" ]]; then
      "$php_bin" artisan route:cache
    fi

    if [[ "$queue_restart" == "true" ]]; then
      "$php_bin" artisan queue:restart
    fi
  )

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

  chmod 0644 "$incoming_dir/release.json"

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

  deployment_log "success"
  log "release $release_id activée pour $environment"
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
