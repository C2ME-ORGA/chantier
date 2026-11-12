#!/usr/bin/env bash
#
# Résout et vérifie la promotion d'une release candidate vers la production.
#
# Le paquet de production n'est jamais reconstruit : il est téléchargé depuis
# l'exécution du workflow de staging qui l'a publié. Toutes les informations
# sont revérifiées avant le téléchargement et après.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../../.." && pwd)"
manifest_tool="$project_root/.github/scripts/lib/manifest.php"
github_data_tool="$project_root/.github/scripts/lib/github-data.php"
# shellcheck source=../lib/versions.sh
source "$script_dir/../lib/versions.sh"

max_pages=20
page_size=100

usage() {
  cat <<'USAGE'
Usage (variables d'environnement) :
  RELEASE_TAG         tag stable publié
  CANDIDATE_TAG       release candidate référencée par la release
  GITHUB_REPOSITORY   dépôt propriétaire/nom
  WORK_DIR            répertoire de travail (facultatif)
  STAGING_WORKFLOW    fichier du workflow de staging (facultatif)

Vérifie la correspondance candidate/stable, retrouve l'exécution de staging,
télécharge l'artefact d'origine et son manifeste, puis contrôle leur intégrité.
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

manifest_get() {
  php "$manifest_tool" get "$1" "$2"
}

require_manifest_value() {
  local file="$1"
  local key="$2"
  local expected="$3"

  local actual
  actual="$(manifest_get "$file" "$key" 2>/dev/null || true)"

  if [[ "$actual" != "$expected" ]]; then
    fail "manifeste incohérent pour $key : attendu '$expected', obtenu '$actual'"
  fi
}

count_lines() {
  local file="$1"

  printf '%s\n' "$(grep -c . "$file" 2>/dev/null || true)"
}

# Récupère toutes les pages d'exécutions correspondant au commit de la
# candidate. La pagination est bornée : au-delà, la résolution échoue plutôt
# que de sélectionner une exécution au hasard.
fetch_all_runs() {
  local endpoint="$1"
  local output="$2"
  local page=1
  local file
  local count

  : > "$output"

  while (( page <= max_pages )); do
    file="$work_dir/runs-page-${page}.json"
    gh api "${endpoint}&per_page=${page_size}&page=${page}" > "$file"
    php "$github_data_tool" runs "$file" "$candidate_tag" >> "$output"
    count="$(php "$github_data_tool" count "$file" workflow_runs)"

    if (( count < page_size )); then
      return 0
    fi

    page=$((page + 1))
  done

  fail "pagination des exécutions dépassée pour $candidate_tag"
}

# Récupère toutes les pages d'artefacts portant le nom demandé.
fetch_all_artifacts() {
  local endpoint="$1"
  local name="$2"
  local output="$3"
  local page=1
  local file
  local count

  : > "$output"

  while (( page <= max_pages )); do
    file="$work_dir/artifacts-${page}.json"
    gh api "${endpoint}&per_page=${page_size}&page=${page}" > "$file"
    php "$github_data_tool" artifacts "$file" "$name" >> "$output"
    count="$(php "$github_data_tool" count "$file" artifacts)"

    if (( count < page_size )); then
      return 0
    fi

    page=$((page + 1))
  done

  fail "pagination des artefacts dépassée pour $name"
}

release_tag="${RELEASE_TAG:-}"
candidate_tag="${CANDIDATE_TAG:-}"
repository="${GITHUB_REPOSITORY:-}"
work_dir="${WORK_DIR:-${RUNNER_TEMP:-/tmp}/promotion}"
staging_workflow="${STAGING_WORKFLOW:-deploy-staging.yml}"

if [[ -z "$release_tag" || -z "$candidate_tag" || -z "$repository" ]]; then
  usage >&2
  exit 64
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

version_is_stable "$release_tag" || fail "tag stable invalide : $release_tag"
version_is_rc "$candidate_tag" || fail "tag de release candidate invalide : $candidate_tag"

if [[ "$(version_base "$candidate_tag")" != "$release_tag" ]]; then
  fail "la candidate $candidate_tag ne correspond pas à la version stable $release_tag"
fi

for tag in "$release_tag" "$candidate_tag"; do
  if [[ "$(git cat-file -t "refs/tags/${tag}" 2>/dev/null || true)" != "tag" ]]; then
    fail "le tag $tag doit exister et être annoté"
  fi
done

candidate_commit="$(git rev-parse "${candidate_tag}^{commit}")"
candidate_tree="$(git rev-parse "${candidate_tag}^{tree}")"
release_commit="$(git rev-parse "${release_tag}^{commit}")"
release_tree="$(git rev-parse "${release_tag}^{tree}")"

if ! git rev-parse -q --verify "origin/develop^{commit}" >/dev/null; then
  fail "référence origin/develop introuvable : historique incomplet"
fi

if ! git merge-base --is-ancestor "$candidate_commit" "origin/develop^{commit}"; then
  fail "la candidate $candidate_tag n'appartient pas à l'historique de origin/develop"
fi

if [[ "$candidate_tree" != "$release_tree" ]]; then
  fail "les arbres Git diffèrent entre $candidate_tag ($candidate_tree) et $release_tag ($release_tree)"
fi

rm -rf "$work_dir"
mkdir -p "$work_dir"

runs_list="$work_dir/staging-runs.txt"
fetch_all_runs "repos/${repository}/actions/runs?head_sha=${candidate_commit}" "$runs_list"

if [[ ! -s "$runs_list" ]]; then
  fail "aucune exécution du workflow de staging trouvée pour le tag $candidate_tag"
fi

first_run="$(head -n 1 "$runs_list")"
IFS=$'\t' read -r staging_run_id run_status run_conclusion run_head_sha run_head_branch run_event run_path _run_created_at <<< "$first_run"

if [[ ! "$staging_run_id" =~ ^[0-9]+$ ]]; then
  fail "identifiant d'exécution de staging invalide : ${staging_run_id:-vide}"
fi

if [[ "$run_status" != "completed" ]]; then
  fail "l'exécution de staging la plus récente ($staging_run_id) n'est pas terminée : $run_status"
fi

if [[ "$run_conclusion" != "success" ]]; then
  fail "l'exécution de staging la plus récente ($staging_run_id) a échoué : ${run_conclusion:-inconnu}"
fi

if [[ "$run_head_sha" != "$candidate_commit" ]]; then
  fail "provenance incohérente : l'exécution $staging_run_id porte sur $run_head_sha et non $candidate_commit"
fi

if [[ "$run_head_branch" != "$candidate_tag" ]]; then
  fail "provenance incohérente : l'exécution $staging_run_id porte sur le tag $run_head_branch et non $candidate_tag"
fi

if [[ "$run_event" != "push" ]]; then
  fail "provenance incohérente : l'exécution $staging_run_id n'a pas été déclenchée par un push ($run_event)"
fi

if [[ "$run_path" != ".github/workflows/${staging_workflow}" ]]; then
  fail "provenance incohérente : workflow inattendu pour l'exécution $staging_run_id ($run_path)"
fi

package_name="chantier-package-${candidate_tag}"
manifest_name="chantier-manifest-${candidate_tag}"

package_lines="$work_dir/package-artifacts.txt"
manifest_lines="$work_dir/manifest-artifacts.txt"
artifacts_endpoint="repos/${repository}/actions/runs/${staging_run_id}/artifacts?"

fetch_all_artifacts "$artifacts_endpoint" "$package_name" "$package_lines"
fetch_all_artifacts "$artifacts_endpoint" "$manifest_name" "$manifest_lines"

package_count="$(count_lines "$package_lines")"
manifest_count="$(count_lines "$manifest_lines")"

if [[ "$package_count" -eq 0 ]]; then
  fail "artefact de paquet introuvable pour $candidate_tag"
fi

if [[ "$package_count" -gt 1 ]]; then
  fail "plusieurs artefacts de paquet portent le nom $package_name : ambiguïté refusée"
fi

if [[ "$manifest_count" -eq 0 ]]; then
  fail "artefact de manifeste introuvable pour $candidate_tag"
fi

if [[ "$manifest_count" -gt 1 ]]; then
  fail "plusieurs artefacts de manifeste portent le nom $manifest_name : ambiguïté refusée"
fi

IFS=$'\t' read -r package_artifact_id package_expired _package_name _package_size <<< "$(head -n 1 "$package_lines")"
IFS=$'\t' read -r manifest_artifact_id manifest_expired _manifest_name _manifest_size <<< "$(head -n 1 "$manifest_lines")"

if [[ "$package_expired" != "false" ]]; then
  fail "artefact de paquet expiré pour $candidate_tag : déploiement refusé"
fi

if [[ "$manifest_expired" != "false" ]]; then
  fail "artefact de manifeste expiré pour $candidate_tag : déploiement refusé"
fi

package_dir="$work_dir/package"
manifest_dir="$work_dir/manifest"

gh run download "$staging_run_id" --repo "$repository" --name "$package_name" --dir "$package_dir"
gh run download "$staging_run_id" --repo "$repository" --name "$manifest_name" --dir "$manifest_dir"

package_file="$package_dir/chantier-${candidate_tag}.tar.gz"
manifest_file="$manifest_dir/manifest.json"

[[ -f "$package_file" ]] || fail "paquet téléchargé introuvable : $package_file"
[[ -f "$manifest_file" ]] || fail "manifeste téléchargé introuvable : $manifest_file"

computed_sha="$(sha256sum "$package_file" | awk '{print $1}')"

[[ "$computed_sha" =~ ^[0-9a-f]{64}$ ]] || fail "empreinte SHA-256 invalide pour le paquet téléchargé"

if [[ -f "$package_dir/chantier-${candidate_tag}.tar.gz.sha256" ]]; then
  published_sha="$(awk '{print $1}' "$package_dir/chantier-${candidate_tag}.tar.gz.sha256")"

  if [[ "$published_sha" != "$computed_sha" ]]; then
    fail "le paquet téléchargé ne correspond pas à son empreinte publiée"
  fi
fi

php "$manifest_tool" validate "$manifest_file" >/dev/null

require_manifest_value "$manifest_file" environment staging
require_manifest_value "$manifest_file" version "$candidate_tag"
require_manifest_value "$manifest_file" tag "$candidate_tag"
require_manifest_value "$manifest_file" commit_sha "$candidate_commit"
require_manifest_value "$manifest_file" tree_sha "$candidate_tree"
require_manifest_value "$manifest_file" workflow.run_id "$staging_run_id"
require_manifest_value "$manifest_file" workflow.name "deploy-staging"
require_manifest_value "$manifest_file" artifact.id "$package_artifact_id"
require_manifest_value "$manifest_file" artifact.name "$package_name"
require_manifest_value "$manifest_file" artifact.sha256 "$computed_sha"
require_manifest_value "$manifest_file" staging_deployment.status success
require_manifest_value "$manifest_file" staging_deployment.run_id "$staging_run_id"

emit release_tag "$release_tag"
emit release_commit "$release_commit"
emit release_tree "$release_tree"
emit candidate_tag "$candidate_tag"
emit candidate_commit "$candidate_commit"
emit candidate_tree "$candidate_tree"
emit staging_run_id "$staging_run_id"
emit package_artifact_id "$package_artifact_id"
emit manifest_artifact_id "$manifest_artifact_id"
emit package_name "$package_name"
emit manifest_name "$manifest_name"
emit package_path "$package_file"
emit manifest_path "$manifest_file"
emit sha256 "$computed_sha"
