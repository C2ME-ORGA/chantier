#!/usr/bin/env bash
#
# Simulation des artefacts, du registre local et des déploiements.
#
# - construit le paquet avec le script réel assemble-package.sh ;
# - crée et valide les manifestes avec le script réel manifest.php ;
# - publie dans un registre local consommé par un faux `gh` ;
# - exécute les scripts réels resolve-promotion.sh et validate-*.sh ;
# - déploie dans des environnements locaux et vérifie /up par HTTP réel.
#
# Aucun artefact n'est reconstruit entre staging et production : le paquet
# promu est celui publié par le registre staging.

set -uo pipefail

SIM_FAKE_GH_DIR=""

sim_fake_gh_init() {
  SIM_FAKE_GH_DIR="$SIM_OUT/fake-bin"
  mkdir -p "$SIM_FAKE_GH_DIR"

  cat >"$SIM_FAKE_GH_DIR/gh" <<'FAKE_GH'
#!/usr/bin/env bash
#
# Faux client GitHub CLI de la simulation. Il ne contacte aucun service.
# Toutes les réponses proviennent de GH_SIM_DIR.

set -euo pipefail

dir="${GH_SIM_DIR:?GH_SIM_DIR est obligatoire}"

case "${1:-}" in
  api)
    url="${2:-}"
    case "$url" in
      *"/actions/runs?"*) cat "$dir/runs.json" ;;
      *"/actions/runs/"*"/artifacts"*) cat "$dir/artifacts.json" ;;
      *) printf 'faux gh: endpoint inattendu: %s\n' "$url" >&2; exit 1 ;;
    esac
    ;;
  run)
    name=""
    dest=""
    shift 2
    while (($#)); do
      case "$1" in
        --name) name="${2:-}"; shift 2 ;;
        --dir) dest="${2:-}"; shift 2 ;;
        --repo) shift 2 ;;
        *) shift ;;
      esac
    done
    [[ -n "$name" && -n "$dest" ]] || { printf 'faux gh: arguments incomplets\n' >&2; exit 64; }
    mkdir -p "$dest"
    case "$name" in
      chantier-package-*) cp -R "$dir/package/." "$dest/" ;;
      chantier-manifest-*) cp -R "$dir/manifest/." "$dest/" ;;
      *) printf 'faux gh: artefact inconnu: %s\n' "$name" >&2; exit 1 ;;
    esac
    ;;
  *)
    printf 'faux gh: commande inattendue: %s\n' "${1:-}" >&2
    exit 1
    ;;
esac
FAKE_GH
  chmod +x "$SIM_FAKE_GH_DIR/gh"
}

sim_build_package() {
  local repo="$1"
  local ref="$2"
  local tag="$3"
  local output_dir="$4"
  local sha worktree

  sha="$(git -C "$repo" rev-parse "${ref}^{commit}")"
  worktree="$SIM_OUT/tmp/package-${tag}-$$"

  rm -rf "$worktree"
  git -C "$repo" worktree add --quiet --detach "$worktree" "$sha" || return 1

  mkdir -p "$output_dir"

  local status=0
  bash "$SIM_PROJECT_ROOT/.github/scripts/package/assemble-package.sh" \
    --source "$worktree" \
    --output-dir "$output_dir" \
    --tag "$tag" \
    >>"$SIM_OUT/log/assemble-${tag}.log" 2>&1 || status=$?

  git -C "$repo" worktree remove --force "$worktree" >/dev/null 2>&1 || true

  ((status == 0))
}

sim_manifest_create_staging() {
  local file="$1"
  local tag="$2"
  local commit="$3"
  local tree="$4"
  local run_id="$5"
  local artifact_id="$6"
  local sha256="$7"

  php "$SIM_PROJECT_ROOT/.github/scripts/lib/manifest.php" create "$file" \
    "schema_version=1" \
    "environment=staging" \
    "channel=rc" \
    "version=${tag}" \
    "tag=${tag}" \
    "commit_sha=${commit}" \
    "tree_sha=${tree}" \
    "workflow.name=deploy-staging" \
    "workflow.run_id=${run_id}" \
    "workflow.run_attempt=1" \
    "artifact.id=${artifact_id}" \
    "artifact.name=chantier-package-${tag}" \
    "artifact.sha256=${sha256}" \
    "staging_deployment.status=success" \
    "staging_deployment.job=deploy" \
    "staging_deployment.run_id=${run_id}" \
    "created_at=$(sim_timestamp)"
}

sim_manifest_validate() {
  local file="$1"

  php "$SIM_PROJECT_ROOT/.github/scripts/lib/manifest.php" validate "$file"
}

sim_manifest_get() {
  local file="$1"
  local key="$2"

  php "$SIM_PROJECT_ROOT/.github/scripts/lib/manifest.php" get "$file" "$key"
}

sim_registry_publish() {
  local registry="$1"
  local tag="$2"
  local package_path="$3"
  local manifest_path="$4"
  local run_id="$5"
  local artifact_id="$6"
  local manifest_artifact_id="$7"
  local commit="$8"
  local package_name="chantier-package-${tag}"
  local manifest_name="chantier-manifest-${tag}"
  local size

  rm -rf "$registry"
  mkdir -p "$registry/package" "$registry/manifest"

  cp "$package_path" "$registry/package/$(basename "$package_path")"
  cp "${package_path}.sha256" "$registry/package/$(basename "$package_path").sha256"
  cp "$manifest_path" "$registry/manifest/manifest.json"

  size="$(stat -c '%s' "$registry/package/$(basename "$package_path")")"

  cat >"$registry/runs.json" <<JSON
{
  "total_count": 1,
  "workflow_runs": [
    {
      "id": ${run_id},
      "status": "completed",
      "conclusion": "success",
      "head_sha": "${commit}",
      "head_branch": "${tag}",
      "event": "push",
      "path": ".github/workflows/deploy-staging.yml",
      "created_at": "2026-11-18T10:00:00Z"
    }
  ]
}
JSON

  cat >"$registry/artifacts.json" <<JSON
{
  "total_count": 2,
  "artifacts": [
    {
      "id": ${artifact_id},
      "expired": false,
      "name": "${package_name}",
      "size_in_bytes": ${size}
    },
    {
      "id": ${manifest_artifact_id},
      "expired": false,
      "name": "${manifest_name}",
      "size_in_bytes": 2048
    }
  ]
}
JSON
}

sim_promotion_run() {
  local repo="$1"
  local registry="$2"
  local release_tag="$3"
  local candidate_tag="$4"
  local work_dir="$5"
  shift 5

  (
    cd "$repo" || exit 1
    GH_SIM_DIR="$registry" \
    PATH="$SIM_FAKE_GH_DIR:$PATH" \
    RELEASE_TAG="$release_tag" \
    CANDIDATE_TAG="$candidate_tag" \
    GITHUB_REPOSITORY="simulation/local" \
    WORK_DIR="$work_dir" \
    bash "$SIM_PROJECT_ROOT/.github/scripts/deploy/resolve-promotion.sh"
  ) 2>&1
}

sim_kv_get() {
  local output="$1"
  local key="$2"

  printf '%s\n' "$output" | awk -F= -v key="$key" '$1 == key {print substr($0, index($0, "=") + 1); exit}'
}

sim_release_json() {
  local file="$1"
  local environment="$2"
  local release_id="$3"
  local version="$4"
  local commit="$5"
  local tree="$6"
  local artifact_id="$7"
  local sha256="$8"

  cat >"$file" <<JSON
{
  "environment": "$environment",
  "release": "$release_id",
  "version": "$version",
  "commit_sha": "$commit",
  "tree_sha": "$tree",
  "artifact_id": "$artifact_id",
  "sha256": "$sha256",
  "deployed_at": "$(sim_timestamp)"
}
JSON
}

sim_env_prepare() {
  local environment="$1"
  local root="$SIM_OUT/envs/$environment"

  mkdir -p \
    "$root/releases" \
    "$root/shared/storage/app/private" \
    "$root/shared/storage/app/public" \
    "$root/shared/storage/framework" \
    "$root/shared/storage/logs"

  if [[ ! -f "$root/shared/.env" ]]; then
    printf 'APP_ENV=%s\nAPP_KEY=simulation\n' "$environment" >"$root/shared/.env"
    printf 'document simulé persistant\n' >"$root/shared/storage/app/private/document.txt"
  fi

  printf '%s\n' "$root"
}

sim_deploy_release() {
  local environment="$1"
  local release_id="$2"
  local package_path="$3"
  local version="$4"
  local commit="$5"
  local tree="$6"
  local artifact_id="$7"
  local sha256="$8"
  local functional_left="${9:-3}"
  local functional_right="${10:-2}"
  local expected_total="${11:-5}"
  local root release_dir port pid health version_body total_body

  root="$(sim_env_prepare "$environment")"
  release_dir="$root/releases/$release_id"

  rm -rf "$release_dir"
  mkdir -p "$release_dir"

  if ! tar -xzf "$package_path" -C "$release_dir"; then
    printf 'extraction impossible\n' >&2
    return 1
  fi

  [[ -f "$release_dir/artisan" ]] || { printf 'artisan absent du paquet\n' >&2; return 1; }
  [[ -f "$release_dir/public/index.php" ]] || { printf 'index.php absent du paquet\n' >&2; return 1; }

  mkdir -p "$release_dir/bootstrap/cache"
  : >"$release_dir/bootstrap/cache/config.php"
  chmod 0640 "$release_dir/bootstrap/cache/config.php"

  ln -s "$root/shared/.env" "$release_dir/.env"
  ln -s "$root/shared/storage" "$release_dir/storage"
  ln -s "$root/shared/storage/app/public" "$release_dir/public/storage"

  sim_release_json "$release_dir/release.json" "$environment" "$release_id" \
    "$version" "$commit" "$tree" "$artifact_id" "$sha256"

  ln -s "$release_dir" "$root/current.new"
  mv -Tf "$root/current.new" "$root/current"

  local server
  server="$(sim_start_health_server "$release_dir/public")" || {
    printf 'serveur de santé impossible\n' >&2
    return 1
  }
  pid="${server%% *}"
  port="${server##* }"

  sleep 1

  if ! health="$(sim_http_get "$port" '/up')"; then
    sim_stop_health_server "$pid"
    printf 'health check /up en échec : %s\n' "$health" >&2
    return 1
  fi

  if [[ "$health" != *'"status":"up"'* ]]; then
    sim_stop_health_server "$pid"
    printf 'health check /up incohérent : %s\n' "$health" >&2
    return 1
  fi

  if ! version_body="$(sim_http_get "$port" '/version')"; then
    sim_stop_health_server "$pid"
    printf 'lecture de version en échec\n' >&2
    return 1
  fi

  if ! total_body="$(sim_http_get "$port" "/api/total?a=${functional_left}&b=${functional_right}")"; then
    sim_stop_health_server "$pid"
    printf 'vérification fonctionnelle en échec\n' >&2
    return 1
  fi

  sim_stop_health_server "$pid"

  if [[ "$total_body" != *"\"total\":${expected_total}"* ]]; then
    printf 'vérification fonctionnelle incohérente : %s (attendu %s)\n' "$total_body" "$expected_total" >&2
    return 1
  fi

  local evidence
  evidence="$(sim_evidence_dir "deploy-${environment}")"
  cat >"$evidence/${release_id}.json" <<JSON
{
  "environment": "$environment",
  "release": "$release_id",
  "version": "$version",
  "commit_sha": "$commit",
  "tree_sha": "$tree",
  "artifact_id": "$artifact_id",
  "sha256": "$sha256",
  "health": "ok",
  "health_body": $(printf '%s' "$health" | php -r 'echo json_encode(stream_get_contents(STDIN));'),
  "version_body": $(printf '%s' "$version_body" | php -r 'echo json_encode(stream_get_contents(STDIN));'),
  "functional_body": $(printf '%s' "$total_body" | php -r 'echo json_encode(stream_get_contents(STDIN));'),
  "deployed_at": "$(sim_timestamp)"
}
JSON

  printf '%s\n' "$release_dir"
}

sim_deploy_fails_health() {
  local environment="$1"
  local release_id="$2"
  local package_path="$3"
  local version="$4"
  local commit="$5"
  local tree="$6"
  local artifact_id="$7"
  local sha256="$8"
  local root release_dir port pid health

  root="$(sim_env_prepare "$environment")"
  release_dir="$root/releases/$release_id"

  rm -rf "$release_dir"
  mkdir -p "$release_dir"
  tar -xzf "$package_path" -C "$release_dir" || return 1

  mkdir -p "$release_dir/bootstrap/cache"
  : >"$release_dir/bootstrap/cache/config.php"
  chmod 0640 "$release_dir/bootstrap/cache/config.php"
  ln -s "$root/shared/.env" "$release_dir/.env"
  ln -s "$root/shared/storage" "$release_dir/storage"
  ln -s "$root/shared/storage/app/public" "$release_dir/public/storage"

  sim_release_json "$release_dir/release.json" "$environment" "$release_id" \
    "$version" "$commit" "$tree" "$artifact_id" "$sha256"

  # Injection volontaire : la page /up répond 500. L'artefact est intact.
  cat >"$release_dir/public/index.php" <<'PHP'
<?php

declare(strict_types=1);

http_response_code(500);
header('Content-Type: application/json');
echo '{"status":"down"}';
PHP

  local server
  server="$(sim_start_health_server "$release_dir/public")" || return 1
  pid="${server%% *}"
  port="${server##* }"
  sleep 1

  if health="$(sim_http_get "$port" '/up')"; then
    sim_stop_health_server "$pid"
    printf 'le health check aurait dû échouer : %s\n' "$health" >&2
    return 1
  fi

  sim_stop_health_server "$pid"
  printf 'health check en échec comme attendu : %s\n' "$health"
  return 0
}

sim_assert_artifact_identical() {
  local first="$1"
  local second="$2"

  [[ -f "$first" && -f "$second" ]] || return 1
  cmp -s "$first" "$second" || return 1
  [[ "$(sim_sha256 "$first")" == "$(sim_sha256 "$second")" ]]
}
