#!/usr/bin/env bash
#
# Valide un tag de release avant un déploiement.
#
# Contrôles :
# - format SemVer attendu pour le canal (release candidate en staging,
#   version stable en production) ;
# - tag annoté dont l'objet pointe sur un commit ;
# - commit du tag appartenant à l'historique de la branche de référence
#   (la branche peut avoir avancé depuis la création du tag) ;
# - provenance : commit et arbre Git enregistrés pour la suite du workflow.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/versions.sh
source "$script_dir/../lib/versions.sh"

usage() {
  cat <<'USAGE'
Usage : validate-tag.sh --channel <staging|production> --tag <tag> [--ref <ref>]

--channel staging     exige un tag vX.Y.Z-rc.N appartenant à origin/develop.
--channel production  exige un tag vX.Y.Z appartenant à origin/main.
--ref                 référence Git attendue (valeur par défaut selon le canal).
USAGE
}

fail() {
  printf 'ERREUR: %s\n' "$*" >&2
  exit 1
}

emit() {
  local key="$1"
  local value="$2"

  printf '%s=%s\n' "$key" "$value"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
  fi
}

channel=""
tag=""
target_ref=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel) channel="${2:-}"; shift 2 ;;
    --tag) tag="${2:-}"; shift 2 ;;
    --ref) target_ref="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

case "$channel" in
  staging)
    expected_ref="origin/develop"
    ;;
  production)
    expected_ref="origin/main"
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

target_ref="${target_ref:-$expected_ref}"

if [[ -z "$tag" ]]; then
  usage >&2
  exit 64
fi

if [[ "$channel" == "staging" ]]; then
  if version_is_stable "$tag"; then
    fail "le canal staging exige une release candidate vX.Y.Z-rc.N, reçu : $tag"
  fi

  version_is_rc "$tag" || fail "tag de release candidate invalide : $tag"
else
  if version_is_rc "$tag"; then
    fail "une prérelease ne peut pas être déployée en production : $tag"
  fi

  version_is_stable "$tag" || fail "tag de version stable invalide : $tag"
fi

if [[ "$target_ref" != "$expected_ref" ]]; then
  fail "référence interdite pour le canal $channel : $target_ref (attendu : $expected_ref)"
fi

if [[ "$(git cat-file -t "refs/tags/${tag}" 2>/dev/null || true)" != "tag" ]]; then
  fail "le tag $tag doit exister et être annoté"
fi

tag_object="$(git cat-file -p "refs/tags/${tag}")"
object_sha="$(printf '%s\n' "$tag_object" | awk '/^object /{print $2; exit}')"
object_type="$(printf '%s\n' "$tag_object" | awk '/^type /{print $2; exit}')"

if [[ "$object_type" != "commit" ]]; then
  fail "le tag $tag pointe sur un objet $object_type et non sur un commit"
fi

tag_commit="$(git rev-parse "${tag}^{commit}")"

if [[ "$tag_commit" != "$object_sha" ]]; then
  fail "provenance incohérente pour $tag : le tag annonce $object_sha mais résout $tag_commit"
fi

if ! git rev-parse -q --verify "${target_ref}^{commit}" >/dev/null; then
  fail "référence introuvable : $target_ref"
fi

target_commit="$(git rev-parse "${target_ref}^{commit}")"

if ! git merge-base --is-ancestor "$tag_commit" "$target_commit"; then
  fail "le tag $tag ($tag_commit) n'appartient pas à l'historique de $target_ref ($target_commit)"
fi

head_matches=false

if [[ "$tag_commit" == "$target_commit" ]]; then
  head_matches=true
fi

tree_sha="$(git rev-parse "${tag}^{tree}")"

if [[ -z "$tree_sha" ]]; then
  fail "arbre Git introuvable pour le tag $tag"
fi

if [[ "$channel" == "staging" ]]; then
  base_version="$(version_base "$tag")"
  rc_number="$(version_rc_number "$tag")"
else
  base_version="$tag"
  rc_number=""
fi

emit channel "$channel"
emit tag "$tag"
emit base_version "$base_version"
emit rc_number "$rc_number"
emit commit_sha "$tag_commit"
emit tree_sha "$tree_sha"
emit reference "$target_ref"
emit head_matches "$head_matches"
