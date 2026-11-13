#!/usr/bin/env bash
#
# Construit le paquet de déploiement dans le job de build GitHub Actions.
#
# Les dépendances sont installées à partir des fichiers de verrouillage
# existants, sans les modifier. Aucune compilation n'est effectuée sur le
# serveur : le paquet livré contient `vendor/` et les assets Vite compilés.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage : build-package.sh --tag <tag> --output-dir <dossier> [--source <dossier>]

Exécute composer install --no-dev, npm ci et npm run build, puis assemble le
paquet et son empreinte SHA-256.
USAGE
}

fail() {
  printf 'ERREUR: %s\n' "$*" >&2
  exit 1
}

tag=""
output_dir=""
source_dir="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) tag="${2:-}"; shift 2 ;;
    --output-dir) output_dir="${2:-}"; shift 2 ;;
    --source) source_dir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ -z "$tag" || -z "$output_dir" ]]; then
  usage >&2
  exit 64
fi

[[ -f "$source_dir/composer.lock" ]] || fail "composer.lock absent : le build exige un fichier de verrouillage"
[[ -f "$source_dir/package-lock.json" ]] || fail "package-lock.json absent : le build exige un fichier de verrouillage"

# Empreintes des fichiers de verrouillage avant installation : elles ne doivent
# pas changer, le build ne réécrit jamais un fichier de verrouillage.
composer_lock_before="$(sha256sum "$source_dir/composer.lock" | awk '{print $1}')"
package_lock_before="$(sha256sum "$source_dir/package-lock.json" | awk '{print $1}')"

(cd "$source_dir" && composer install \
  --no-dev \
  --no-interaction \
  --prefer-dist \
  --optimize-autoloader \
  --no-progress)

(cd "$source_dir" && npm ci)

(cd "$source_dir" && npm run build)

composer_lock_after="$(sha256sum "$source_dir/composer.lock" | awk '{print $1}')"
package_lock_after="$(sha256sum "$source_dir/package-lock.json" | awk '{print $1}')"

[[ "$composer_lock_before" == "$composer_lock_after" ]] || fail "composer.lock a été modifié pendant le build"
[[ "$package_lock_before" == "$package_lock_after" ]] || fail "package-lock.json a été modifié pendant le build"

bash "$script_dir/assemble-package.sh" \
  --source "$source_dir" \
  --output-dir "$output_dir" \
  --tag "$tag"
