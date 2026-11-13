#!/usr/bin/env bash
#
# Contrôle post-déploiement exécuté via SSH, sans élévation de privilèges.
#
# Vérifie la release active, les liens symboliques, les permissions et le
# marqueur de release. Aucune donnée sensible n'est affichée.

readonly STAGING_ROOT='/www/wwwroot/chantier-staging'
readonly PRODUCTION_ROOT='/www/wwwroot/chantier'
readonly STAGING_USER='c2me-deploy-staging'
readonly PRODUCTION_USER='c2me-deploy-production'

environment=""
release_id=""
version=""
commit_sha=""
expected_sha=""
expected_path=""
dry_run=0

usage() {
  cat <<'USAGE'
Usage : remote-check.sh --environment <staging|production> --release-id <id> \
          --version <tag> --commit <sha> --sha256 <empreinte> \
          --expected-path <chemin> [--dry-run]
USAGE
}

die() {
  printf 'ERREUR: %s\n' "$*" >&2
  exit 1
}

# Même politique que remote-deploy.sh : écriture de groupe et accès des autres
# utilisateurs interdits.
env_mode_is_secure() {
  local mode="${1:-}"

  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1

  (( (8#$mode & 8#0020) == 0 && (8#$mode & 8#0007) == 0 ))
}

main() {
  set -euo pipefail

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --environment) environment="${2:-}"; shift 2 ;;
      --release-id) release_id="${2:-}"; shift 2 ;;
      --version) version="${2:-}"; shift 2 ;;
      --commit) commit_sha="${2:-}"; shift 2 ;;
      --sha256) expected_sha="${2:-}"; shift 2 ;;
      --expected-path) expected_path="${2:-}"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
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

  [[ "$expected_path" == "$root" ]] || die "chemin cible refusé pour $environment : chemin attendu $root"

  if [[ "$dry_run" -ne 1 ]]; then
    actual_user="$(id -un)"

    [[ "$actual_user" == "$expected_user" ]] || die "utilisateur refusé pour $environment : $actual_user"
  fi

  [[ "$release_id" =~ ^[a-z0-9][a-z0-9._-]{2,80}$ ]] || die "identifiant de release invalide : $release_id"
  [[ "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.[1-9][0-9]*)?$ ]] || die "version invalide : $version"
  [[ "$commit_sha" =~ ^[0-9a-f]{40}$ ]] || die "commit invalide : $commit_sha"
  [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || die "empreinte SHA-256 invalide"

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'dry-run OK pour %s : contrôles de configuration validés\n' "$environment"
    exit 0
  fi

  release_dir="$root/releases/$release_id"
  shared="$root/shared"

  [[ -d "$root" ]] || die "répertoire d'installation introuvable : $root"
  [[ -d "$release_dir" ]] || die "release introuvable : $release_id"

  active="$(readlink -f "$root/current" || true)"

  [[ "$active" == "$(readlink -f "$release_dir")" ]] || die "la release active ne correspond pas à $release_id"

  [[ -f "$release_dir/artisan" ]] || die "release incomplète : artisan absent"

  [[ "$(readlink -f "$release_dir/.env")" == "$(readlink -f "$shared/.env")" ]] || die "lien .env invalide"
  [[ "$(readlink -f "$release_dir/storage")" == "$(readlink -f "$shared/storage")" ]] || die "lien storage invalide"
  [[ "$(readlink -f "$release_dir/public/storage")" == "$(readlink -f "$shared/storage/app/public")" ]] || die "lien public/storage invalide"
  [[ -w "$release_dir/storage" ]] || die "stockage non accessible en écriture"
  [[ -w "$release_dir/bootstrap/cache" ]] || die "bootstrap/cache non accessible en écriture"

  env_mode="$(stat -c '%a' "$shared/.env")"

  env_mode_is_secure "$env_mode" || die "permissions du .env trop permissives (mode $env_mode) : écriture de groupe et accès des autres utilisateurs interdits"

  marker="$release_dir/release.json"
  [[ -f "$marker" ]] || die "marqueur de release absent"

  grep -Fq -- "\"environment\": \"$environment\"" "$marker" || die "environnement incohérent dans le marqueur"
  grep -Fq -- "\"release\": \"$release_id\"" "$marker" || die "release incohérente dans le marqueur"
  grep -Fq -- "\"version\": \"$version\"" "$marker" || die "version incohérente dans le marqueur"
  grep -Fq -- "\"commit_sha\": \"$commit_sha\"" "$marker" || die "commit incohérent dans le marqueur"
  grep -Fq -- "\"sha256\": \"$expected_sha\"" "$marker" || die "empreinte incohérente dans le marqueur"

  printf 'deployment-check ok environment=%s release=%s commit=%s\n' "$environment" "$release_id" "$commit_sha"
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
