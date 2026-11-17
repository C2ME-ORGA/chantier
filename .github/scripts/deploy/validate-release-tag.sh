#!/usr/bin/env bash
#
# Valide un tag de release avant la création de la release GitHub.
#
# Règles :
# - tag annoté vX.Y.Z ou vX.Y.Z-rc.N ;
# - version stable : commit == HEAD de origin/main ;
# - release candidate normale : commit == HEAD de origin/develop ;
# - release candidate de hotfix : commit == HEAD de origin/main, présent dans
#   l'historique de develop, non déjà pointé par un tag stable ;
# - provenance : commit et arbre Git émis pour la suite du workflow.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/versions.sh
# shellcheck disable=SC1091 # fichier source du dépôt, résolu à l'exécution
source "$script_dir/../lib/versions.sh"

usage() {
  cat <<'USAGE'
Usage : validate-release-tag.sh --tag <tag> [--develop-ref <ref>] [--main-ref <ref>]

--tag          tag de release à valider.
--develop-ref  référence de développement (défaut : origin/develop).
--main-ref     référence de production (défaut : origin/main).
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

tag=""
develop_ref="origin/develop"
main_ref="origin/main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) tag="${2:-}"; shift 2 ;;
    --develop-ref) develop_ref="${2:-}"; shift 2 ;;
    --main-ref) main_ref="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ -z "$tag" ]]; then
  usage >&2
  exit 64
fi

if version_is_stable "$tag"; then
  release_type="stable"
  target_ref="$main_ref"
  target_label="main"
elif version_is_rc "$tag"; then
  release_type="release-candidate"
  target_ref="$develop_ref"
  target_label="develop"
else
  fail "tag de release invalide : $tag"
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

if ! git rev-parse -q --verify "${main_ref}^{commit}" >/dev/null; then
  fail "référence introuvable : $main_ref"
fi

target_commit="$(git rev-parse "${target_ref}^{commit}")"
main_commit="$(git rev-parse "${main_ref}^{commit}")"

stable_tag_at_commit="$(
  git tag --points-at "$tag_commit" \
    | grep -E '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' \
    || true
)"

head_matches=false
hotfix_rc=false

if [[ "$release_type" == "stable" ]]; then
  if [[ "$tag_commit" != "$target_commit" ]]; then
    fail "le tag stable $tag pointe sur le commit $tag_commit, alors que $target_ref pointe sur le commit $target_commit. Créez le tag sur le HEAD actuel de $target_label, sans déplacer un tag déjà publié."
  fi

  if [[ -n "$stable_tag_at_commit" ]]; then
    other_stable="$(printf '%s\n' "$stable_tag_at_commit" | grep -Fxv "$tag" || true)"

    if [[ -n "$other_stable" ]]; then
      fail "un autre tag stable pointe déjà sur le commit $tag_commit : $other_stable"
    fi
  fi

  head_matches=true
else
  if [[ -n "$stable_tag_at_commit" ]]; then
    fail "le commit $tag_commit est déjà pointé par un tag stable : $stable_tag_at_commit. Une release candidate ne peut pas porter sur un commit déjà publié comme version stable."
  fi

  if [[ "$tag_commit" == "$target_commit" ]]; then
    head_matches=true
  else
    if [[ "$tag_commit" != "$main_commit" ]]; then
      fail "la release candidate de hotfix $tag pointe sur le commit $tag_commit, alors que le HEAD de $main_ref est $main_commit. Une RC de hotfix doit pointer exactement sur le HEAD de main ; si main a avancé, synchronisez-le vers develop et créez une nouvelle RC."
    fi

    if ! git merge-base --is-ancestor "$tag_commit" "$target_commit"; then
      fail "la release candidate de hotfix $tag pointe sur le commit $tag_commit, qui n'appartient pas à l'historique de $target_ref. Synchronisez main vers develop avant de créer la RC de hotfix."
    fi

    hotfix_rc=true
  fi
fi

tree_sha="$(git rev-parse "${tag}^{tree}")"

if [[ -z "$tree_sha" ]]; then
  fail "arbre Git introuvable pour le tag $tag"
fi

if [[ "$release_type" == "stable" ]]; then
  base_version="$tag"
  rc_number=""
else
  base_version="$(version_base "$tag")"
  rc_number="$(version_rc_number "$tag")"
fi

emit release_type "$release_type"
emit tag "$tag"
emit base_version "$base_version"
emit rc_number "$rc_number"
emit commit_sha "$tag_commit"
emit tree_sha "$tree_sha"
emit reference "$target_ref"
emit head_matches "$head_matches"
emit hotfix_rc "$hotfix_rc"
