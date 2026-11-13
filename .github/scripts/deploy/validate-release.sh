#!/usr/bin/env bash
#
# Valide l'événement `release.published` avant un déploiement en production.
#
# Contrôles :
# - release publiée, ni brouillon ni prérelease ;
# - tag stable conforme à SemVer ;
# - présence d'une référence explicite à la candidate staging validée :
#   `Staging-Candidate: vX.Y.Z-rc.N` ;
# - cohérence de version entre la candidate et la version stable.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/versions.sh
source "$script_dir/../lib/versions.sh"

usage() {
  cat <<'USAGE'
Usage : validate-release.sh --tag <tag> --draft <true|false> \
          --prerelease <true|false> --body-file <fichier>

Valide une release GitHub publiée et extrait la candidate staging référencée.
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
is_draft=""
is_prerelease=""
body_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) tag="${2:-}"; shift 2 ;;
    --draft) is_draft="${2:-}"; shift 2 ;;
    --prerelease) is_prerelease="${2:-}"; shift 2 ;;
    --body-file) body_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ -z "$tag" || -z "$body_file" ]]; then
  usage >&2
  exit 64
fi

case "$is_draft" in
  true) fail "une release brouillon ne peut pas être déployée : $tag" ;;
  false) ;;
  *) fail "état brouillon inconnu : ${is_draft:-vide}" ;;
esac

case "$is_prerelease" in
  true) fail "une prérelease ne peut pas être déployée en production : $tag" ;;
  false) ;;
  *) fail "état de prérelease inconnu : ${is_prerelease:-vide}" ;;
esac

if version_is_rc "$tag"; then
  fail "un tag de release candidate ne peut pas être déployé en production : $tag"
fi

version_is_stable "$tag" || fail "tag stable invalide : $tag"

if [[ ! -f "$body_file" ]]; then
  fail "corps de release introuvable : $body_file"
fi

candidates="$(
  grep -E '^Staging-Candidate: v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc\.[1-9][0-9]*[[:space:]]*$' "$body_file" \
    | sed -E 's/^Staging-Candidate:[[:space:]]*//; s/[[:space:]]*$//' || true
)"

candidate_count="$(printf '%s' "$candidates" | grep -c . || true)"

if [[ "$candidate_count" -eq 0 ]]; then
  fail "la release $tag ne référence aucune candidate staging (Staging-Candidate: vX.Y.Z-rc.N)"
fi

if [[ "$candidate_count" -gt 1 ]]; then
  fail "la release $tag référence plusieurs candidates staging ; une seule est autorisée"
fi

candidate_tag="$candidates"

if ! version_is_rc "$candidate_tag"; then
  fail "référence de candidate staging invalide : $candidate_tag"
fi

if [[ "$(version_base "$candidate_tag")" != "$tag" ]]; then
  fail "la candidate $candidate_tag ne correspond pas à la version stable $tag"
fi

emit tag "$tag"
emit candidate_tag "$candidate_tag"
