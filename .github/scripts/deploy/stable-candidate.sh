#!/usr/bin/env bash
#
# Ajoute aux notes d'une version stable la référence explicite à la release
# candidate staging correspondante.
#
# Une candidate n'est retenue que si :
# - elle porte le même numéro de version de base ;
# - c'est un tag annoté ancêtre du tag stable ;
# - son arbre Git est identique à celui du tag stable.
#
# Sans candidate vérifiable, aucune ligne `Staging-Candidate:` n'est ajoutée :
# le déploiement en production sera refusé.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/versions.sh
source "$script_dir/../lib/versions.sh"

usage() {
  cat <<'USAGE'
Usage : stable-candidate.sh --tag vX.Y.Z --notes <fichier>

Ajoute la section de déploiement aux notes de version d'un tag stable.
Pour une release candidate, le script ne modifie rien.
USAGE
}

fail() {
  printf 'ERREUR: %s\n' "$*" >&2
  exit 1
}

tag=""
notes_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) tag="${2:-}"; shift 2 ;;
    --notes) notes_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ -z "$tag" || -z "$notes_file" ]]; then
  usage >&2
  exit 64
fi

if version_is_rc "$tag"; then
  exit 0
fi

version_is_stable "$tag" || fail "tag stable invalide : $tag"

[[ -f "$notes_file" ]] || fail "fichier de notes introuvable : $notes_file"

stable_tree="$(git rev-parse "${tag}^{tree}")"

selected=""

while IFS= read -r candidate; do
  [[ -z "$candidate" ]] && continue
  version_is_rc "$candidate" || continue
  [[ "$(version_base "$candidate")" == "$tag" ]] || continue

  if [[ "$(git cat-file -t "refs/tags/${candidate}" 2>/dev/null || true)" != "tag" ]]; then
    continue
  fi

  if ! git merge-base --is-ancestor "refs/tags/${candidate}^{commit}" "refs/tags/${tag}^{commit}"; then
    continue
  fi

  if [[ "$(git rev-parse "${candidate}^{tree}")" == "$stable_tree" ]]; then
    selected="$candidate"
    break
  fi
done < <(
  git for-each-ref \
    --merged="${tag}^{commit}" \
    --format='%(refname:short)' \
    'refs/tags/v*' | sort -Vr
)

{
  printf '\n## Déploiement\n\n'

  if [[ -n "$selected" ]]; then
    printf 'Staging-Candidate: %s\n\n' "$selected"
    printf 'Le package déployé en production est celui publié par cette candidate staging.\n'
  else
    printf "Aucune release candidate staging vérifiable n'a été trouvée pour cette version : le déploiement en production sera refusé.\n"
  fi
} >> "$notes_file"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'staging_candidate=%s\n' "$selected" >> "$GITHUB_OUTPUT"
fi
