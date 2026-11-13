#!/usr/bin/env bash
#
# Génère les notes de version d'un tag à partir des Conventional Commits.
# Les notes sont écrites dans un fichier Markdown destiné à `gh release create`
# ou `gh release edit`.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage : generate-release-notes.sh <tag> <fichier-de-sortie> [tag-précédent]

Génère les notes de version du tag <tag> dans <fichier-de-sortie>.
Si le tag précédent est omis, il est déterminé automatiquement :
- pour un tag stable, dernier tag stable publié ;
- pour une release candidate, dernière RC de la même version, sinon dernier tag stable.

Variables d'environnement optionnelles :
- GITHUB_REPOSITORY : dépôt au format propriétaire/nom.
- GITHUB_SERVER_URL : URL du serveur GitHub.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 64
fi

tag="$1"
output_file="$2"
previous_tag="${3:-}"

tag_pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.[1-9][0-9]*)?$'
if [[ ! "$tag" =~ $tag_pattern ]]; then
  printf 'Tag invalide : %s\n' "$tag" >&2
  exit 1
fi

if ! git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  printf 'Tag introuvable : %s\n' "$tag" >&2
  exit 1
fi

if [[ "$(git cat-file -t "refs/tags/${tag}")" != "tag" ]]; then
  printf 'Le tag %s doit être un tag annoté.\n' "$tag" >&2
  exit 1
fi

release_tag_pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.[1-9][0-9]*)?$'
stable_tag_pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

ancestor_release_tags() {
  git for-each-ref \
    --merged="${tag}^{commit}" \
    --sort=-version:refname \
    --format='%(objecttype) %(refname:short)' \
    'refs/tags/v*' |
    awk '$1 == "tag" { print $2 }'
}

if [[ -z "$previous_tag" ]]; then
  ancestor_tags="$(ancestor_release_tags | grep -E "$release_tag_pattern" | grep -v -F -x "$tag" || true)"

  if [[ "$tag" == *-rc.* ]]; then
    base_version="${tag%-rc.*}"
    previous_tag="$(printf '%s\n' "$ancestor_tags" | grep -F -- "${base_version}-rc." | head -n 1 || true)"
  fi

  if [[ -z "$previous_tag" ]]; then
    previous_tag="$(printf '%s\n' "$ancestor_tags" | grep -E "$stable_tag_pattern" | head -n 1 || true)"
  fi
fi

if [[ -n "$previous_tag" ]]; then
  if ! git rev-parse -q --verify "refs/tags/${previous_tag}" >/dev/null; then
    printf 'Tag précédent introuvable : %s\n' "$previous_tag" >&2
    exit 1
  fi

  if [[ "$(git cat-file -t "refs/tags/${previous_tag}")" != "tag" ]]; then
    printf 'Le tag précédent %s doit être un tag annoté.\n' "$previous_tag" >&2
    exit 1
  fi

  if ! git merge-base --is-ancestor "refs/tags/${previous_tag}^{commit}" "refs/tags/${tag}^{commit}"; then
    printf 'Le tag précédent %s n'"'"'est pas un ancêtre du tag %s.\n' "$previous_tag" "$tag" >&2
    exit 1
  fi
fi

range="$tag"
if [[ -n "$previous_tag" ]]; then
  range="${previous_tag}..${tag}"
fi

server_url="${GITHUB_SERVER_URL:-https://github.com}"
repository="${GITHUB_REPOSITORY:-C2ME-ORGA/chantier}"
repo_url="${server_url}/${repository}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

breaking_file="$tmp_dir/breaking"
features_file="$tmp_dir/features"
fixes_file="$tmp_dir/fixes"
other_file="$tmp_dir/other"

: > "$breaking_file"
: > "$features_file"
: > "$fixes_file"
: > "$other_file"

while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue

  subject="$(git show -s --format=%s "$sha")"
  body="$(git show -s --format=%b "$sha")"

  type=""
  scope=""
  description="$subject"
  breaking=0
  conventional_pattern='^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$'

  if [[ "$subject" =~ $conventional_pattern ]]; then
    type="${BASH_REMATCH[1]}"
    scope="${BASH_REMATCH[3]:-}"
    description="${BASH_REMATCH[5]}"

    if [[ -n "${BASH_REMATCH[4]:-}" ]]; then
      breaking=1
    fi
  fi

  if grep -qE '^BREAKING[ -]CHANGE:' <<< "$body"; then
    breaking=1
  fi

  short_sha="$(git rev-parse --short=7 "$sha")"
  if [[ -n "$repository" ]]; then
    reference="[\`${short_sha}\`](${repo_url}/commit/${sha})"
  else
    reference="\`${short_sha}\`"
  fi

  if [[ -n "$scope" ]]; then
    line="- **${scope}** : ${description} (${reference})"
  else
    line="- ${description} (${reference})"
  fi

  if [[ "$breaking" -eq 1 ]]; then
    printf '%s\n' "$line" >> "$breaking_file"
  elif [[ "$type" == "feat" ]]; then
    printf '%s\n' "$line" >> "$features_file"
  elif [[ "$type" == "fix" ]]; then
    printf '%s\n' "$line" >> "$fixes_file"
  else
    printf '%s\n' "$line" >> "$other_file"
  fi
done < <(git log --no-merges --reverse --format='%H' "$range")

{
  if [[ "$tag" == *-rc.* ]]; then
    printf '# Release candidate %s\n\n' "$tag"
  else
    printf '# Release %s\n\n' "$tag"
  fi

  if [[ -n "$previous_tag" ]]; then
    printf 'Changements depuis `%s`.\n\n' "$previous_tag"
  else
    printf 'Première version publiée.\n\n'
  fi
} > "$output_file"

append_section() {
  local title="$1"
  local file="$2"

  if [[ -s "$file" ]]; then
    printf '## %s\n\n' "$title" >> "$output_file"
    cat "$file" >> "$output_file"
    printf '\n' >> "$output_file"
  fi
}

append_section 'Changements incompatibles' "$breaking_file"
append_section 'Fonctionnalités' "$features_file"
append_section 'Corrections' "$fixes_file"
append_section 'Autres changements' "$other_file"

if [[ ! -s "$breaking_file" && ! -s "$features_file" && ! -s "$fixes_file" && ! -s "$other_file" ]]; then
  printf 'Aucun changement notable.\n\n' >> "$output_file"
fi

if [[ -n "$previous_tag" && -n "$repository" ]]; then
  printf -- '---\n\n[Comparer `%s`...`%s`](%s/compare/%s...%s)\n\n' \
    "$previous_tag" "$tag" "$repo_url" "$previous_tag" "$tag" >> "$output_file"
fi

printf '> Notes générées automatiquement à partir des Conventional Commits.\n' >> "$output_file"
