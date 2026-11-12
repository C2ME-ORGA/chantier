#!/usr/bin/env bash
#
# Tests de l'automatisation de déploiement : validation des tags, des releases,
# de la promotion staging -> production, des scripts serveur et du paquet.
#
# Les fonctions des scripts serveur sont sourcées dynamiquement pour tester le
# nettoyage et les permissions ; les variables consommées par ces fonctions
# sont donc volontairement définies dans les sous-shells de test.
# shellcheck disable=SC1090,SC2034,SC2154

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
work_dir="$(mktemp -d)"
fake_bin="$work_dir/bin"

passed=0
failed=0

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

pass() {
  passed=$((passed + 1))
}

fail() {
  failed=$((failed + 1))
  printf 'FAIL: %s\n' "$*" >&2
}

skip() {
  printf 'SKIP: %s\n' "$*" >&2
}

assert_contains() {
  local file="$1"
  local expected="$2"
  local label="$3"

  if grep -Fq -- "$expected" "$file"; then
    pass
  else
    fail "$label : '$file' ne contient pas '$expected'."
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  local label="$3"

  if grep -Fq -- "$unexpected" "$file"; then
    fail "$label : '$file' contient '$unexpected'."
  else
    pass
  fi
}

assert_file_lacks() {
  local file="$1"
  local unexpected="$2"
  local label="$3"

  if grep -Fq -- "$unexpected" "$file"; then
    fail "$label : '$file' contient '$unexpected'."
  else
    pass
  fi
}

repo_init() {
  local repo="$1"

  mkdir -p "$repo"
  (
    cd "$repo"
    git init --quiet
    git config user.name "Deployment Test"
    git config user.email "deployment-test@example.com"
    printf 'initial\n' > file.txt
    git add file.txt
    git commit --quiet -m "feat: initialiser le dépôt"
    git branch -M develop
  )
}

tag_annotated() {
  local repo="$1"
  local tag="$2"

  git -C "$repo" tag -a "$tag" -m "$tag"
}

tag_lightweight() {
  local repo="$1"
  local tag="$2"

  git -C "$repo" tag "$tag"
}

set_remote_ref() {
  local repo="$1"
  local ref="$2"
  local sha="$3"

  git -C "$repo" update-ref "refs/remotes/origin/${ref}" "$sha"
}

run_in_repo() {
  local repo="$1"
  shift

  (cd "$repo" && "$@")
}

run_fails() {
  local label="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    fail "$label : la commande aurait dû échouer."
  else
    pass
  fi
}

run_fails_with_message() {
  local label="$1"
  local expected="$2"
  shift 2

  local log="$work_dir/last-failure.log"

  if "$@" >"$log" 2>&1; then
    fail "$label : la commande aurait dû échouer."
    return
  fi

  if grep -Fq -- "$expected" "$log"; then
    pass
  else
    fail "$label : message attendu '$expected' absent."
  fi
}

sha256_of() {
  sha256sum "$1" | awk '{print $1}'
}

fake_sha() {
  local char="$1"
  local output=""
  local index

  for index in $(seq 1 40); do
    output="${output}${char}"
  done

  printf '%s\n' "$output"
}

fake_sha256() {
  local char="$1"
  local output=""
  local index

  for index in $(seq 1 64); do
    output="${output}${char}"
  done

  printf '%s\n' "$output"
}

mkdir -p "$fake_bin"

# ---------------------------------------------------------------------------
# 1. Formats de version
# ---------------------------------------------------------------------------

# shellcheck source=../lib/versions.sh
source "$script_dir/lib/versions.sh"

if version_is_stable v1.4.0; then pass; else fail "v1.4.0 doit être une version stable."; fi
if version_is_stable v1.4.0-rc.1; then fail "v1.4.0-rc.1 ne doit pas être stable."; else pass; fi
if version_is_rc v1.4.0-rc.1; then pass; else fail "v1.4.0-rc.1 doit être une candidate."; fi
if version_is_rc v1.4.0-rc.0; then fail "rc.0 doit être refusé."; else pass; fi
if version_is_rc v01.4.0-rc.1; then fail "Un zéro initial doit être refusé."; else pass; fi
if [[ "$(version_base v1.4.0-rc.3)" == "v1.4.0" ]]; then pass; else fail "version_base est incorrect."; fi
if [[ "$(version_rc_number v1.4.0-rc.3)" == "3" ]]; then pass; else fail "version_rc_number est incorrect."; fi

# ---------------------------------------------------------------------------
# 2. Validation des tags
# ---------------------------------------------------------------------------

validate_tag="$script_dir/deploy/validate-tag.sh"

repo="$work_dir/tags"
repo_init "$repo"
tag_annotated "$repo" v0.2.0-rc.1
rc_commit="$(git -C "$repo" rev-parse HEAD)"
set_remote_ref "$repo" develop "$rc_commit"
set_remote_ref "$repo" main "$rc_commit"

output="$work_dir/tag-output"
run_in_repo "$repo" env GITHUB_OUTPUT="$output" bash "$validate_tag" \
  --channel staging --tag v0.2.0-rc.1 --ref origin/develop > "$output.stdout"

assert_contains "$output" "commit_sha=$rc_commit" "Tag RC sur develop"
assert_contains "$output" "tree_sha=$(git -C "$repo" rev-parse "v0.2.0-rc.1^{tree}")" "Tag RC sur develop"

tag_annotated "$repo" v0.2.0

run_fails "Tag stable refusé en staging" \
  run_in_repo "$repo" bash "$validate_tag" --channel staging --tag v0.2.0 --ref origin/develop

run_in_repo "$repo" bash "$validate_tag" --channel production --tag v0.2.0 --ref origin/main >/dev/null
pass

run_fails "Tag RC refusé en production" \
  run_in_repo "$repo" bash "$validate_tag" --channel production --tag v0.2.0-rc.1 --ref origin/main

(
  cd "$repo"
  printf 'nouveau\n' >> file.txt
  git add file.txt
  git commit --quiet -m "fix: avancer develop"
  git update-ref refs/remotes/origin/develop HEAD
)

# La branche a avancé après la création du tag : le tag reste valide tant que
# son commit appartient à l'historique de develop.
run_in_repo "$repo" bash "$validate_tag" --channel staging --tag v0.2.0-rc.1 --ref origin/develop > "$work_dir/tag-ancestor.out"
pass
assert_contains "$work_dir/tag-ancestor.out" "head_matches=false" "Tag ancêtre après avancée de develop"
assert_contains "$work_dir/tag-ancestor.out" "commit_sha=$(git -C "$repo" rev-parse 'v0.2.0-rc.1^{commit}')" "Tag ancêtre après avancée de develop"

repo="$work_dir/divergent-tag"
repo_init "$repo"
(
  cd "$repo"
  git switch --quiet -c side
  printf 'side\n' >> file.txt
  git add file.txt
  git commit --quiet -m "feat: branche divergente"
  git tag -a v0.4.0-rc.1 -m v0.4.0-rc.1
  git switch --quiet develop
  printf 'develop\n' >> file.txt
  git add file.txt
  git commit --quiet -m "fix: develop avance"
  git update-ref refs/remotes/origin/develop HEAD
)

run_fails "Tag hors de l'historique de develop refusé" \
  run_in_repo "$repo" bash "$validate_tag" --channel staging --tag v0.4.0-rc.1 --ref origin/develop

repo="$work_dir/lightweight"
repo_init "$repo"
tag_lightweight "$repo" v0.3.0-rc.1
set_remote_ref "$repo" develop "$(git -C "$repo" rev-parse HEAD)"

run_fails "Tag léger refusé" \
  run_in_repo "$repo" bash "$validate_tag" --channel staging --tag v0.3.0-rc.1 --ref origin/develop

run_fails "Format de tag invalide" \
  run_in_repo "$repo" bash "$validate_tag" --channel staging --tag v0.3.0-rc.0 --ref origin/develop

run_fails "Référence interdite" \
  run_in_repo "$repo" bash "$validate_tag" --channel staging --tag v0.3.0-rc.1 --ref origin/main

# ---------------------------------------------------------------------------
# 3. Validation des releases publiées
# ---------------------------------------------------------------------------

validate_release="$script_dir/deploy/validate-release.sh"
body="$work_dir/release-body.md"

write_body() {
  printf '%s\n' "$1" > "$body"
}

write_body '## Déploiement

Staging-Candidate: v0.2.0-rc.1'

run_in_repo "$repo" env GITHUB_OUTPUT="$work_dir/release-output" bash "$validate_release" \
  --tag v0.2.0 --draft false --prerelease false --body-file "$body" >/dev/null
pass

assert_contains "$work_dir/release-output" "candidate_tag=v0.2.0-rc.1" "Release avec candidate"

run_fails "Release brouillon refusée" \
  run_in_repo "$repo" bash "$validate_release" --tag v0.2.0 --draft true --prerelease false --body-file "$body"

run_fails "Prérelease refusée en production" \
  run_in_repo "$repo" bash "$validate_release" --tag v0.2.0 --draft false --prerelease true --body-file "$body"

run_fails "Tag RC refusé en production" \
  run_in_repo "$repo" bash "$validate_release" --tag v0.2.0-rc.1 --draft false --prerelease false --body-file "$body"

write_body 'Notes sans référence de candidate.'
run_fails "Release sans candidate staging refusée" \
  run_in_repo "$repo" bash "$validate_release" --tag v0.2.0 --draft false --prerelease false --body-file "$body"

write_body 'Staging-Candidate: v0.2.0-rc.1
Staging-Candidate: v0.2.0-rc.2'
run_fails "Release avec plusieurs candidates refusée" \
  run_in_repo "$repo" bash "$validate_release" --tag v0.2.0 --draft false --prerelease false --body-file "$body"

write_body 'Staging-Candidate: v0.3.0-rc.1'
run_fails "Candidate d'une autre version refusée" \
  run_in_repo "$repo" bash "$validate_release" --tag v0.2.0 --draft false --prerelease false --body-file "$body"

write_body 'Staging-Candidate: v0.2.0'
run_fails "Candidate non RC refusée" \
  run_in_repo "$repo" bash "$validate_release" --tag v0.2.0 --draft false --prerelease false --body-file "$body"

# ---------------------------------------------------------------------------
# 4. Manifestes JSON et schéma strict
# ---------------------------------------------------------------------------

manifest_tool="$script_dir/lib/manifest.php"
manifest_file="$work_dir/manifest.json"

create_staging_manifest() {
  local file="$1"
  local sha="${2:-$(fake_sha256 d)}"
  local version="${3:-v0.2.0-rc.1}"
  local status="${4:-success}"

  php "$manifest_tool" create "$file" \
    schema_version=1 \
    environment=staging \
    version="$version" \
    tag="$version" \
    channel=rc \
    commit_sha="$(fake_sha a)" \
    tree_sha="$(fake_sha b)" \
    workflow.name=deploy-staging \
    workflow.run_id=123 \
    workflow.run_attempt=1 \
    artifact.name="chantier-package-${version}" \
    artifact.id=456 \
    artifact.sha256="$sha" \
    staging_deployment.status="$status" \
    staging_deployment.run_id=123 \
    staging_deployment.job=deploy \
    created_at=2026-11-12T10:00:00Z
}

create_production_manifest() {
  local file="$1"

  php "$manifest_tool" create "$file" \
    schema_version=1 \
    environment=production \
    version=v0.2.0 \
    tag=v0.2.0 \
    channel=stable \
    commit_sha="$(fake_sha a)" \
    tree_sha="$(fake_sha b)" \
    workflow.name=deploy-production \
    workflow.run_id=999 \
    workflow.run_attempt=1 \
    artifact.name=chantier-package-v0.2.0-rc.1 \
    artifact.id=456 \
    artifact.sha256="$(fake_sha256 c)" \
    staging.candidate_tag=v0.2.0-rc.1 \
    staging.run_id=123 \
    staging.manifest_artifact_id=457 \
    staging_deployment.status=success \
    staging_deployment.run_id=123 \
    created_at=2026-11-12T10:00:00Z
}

create_staging_manifest "$manifest_file"
php "$manifest_tool" validate "$manifest_file"
pass

if [[ "$(php "$manifest_tool" get "$manifest_file" workflow.run_id)" == "123" ]]; then pass; else fail "Lecture du manifeste incorrecte."; fi
if [[ "$(php "$manifest_tool" get "$manifest_file" artifact.id)" == "456" ]]; then pass; else fail "Lecture imbriquée du manifeste incorrecte."; fi
if [[ "$(php "$manifest_tool" get "$manifest_file" artifact.sha256)" == "$(fake_sha256 d)" ]]; then pass; else fail "Les valeurs du manifeste doivent être conservées."; fi

run_fails "Clé de manifeste absente" \
  php "$manifest_tool" get "$manifest_file" artifact.absent

printf '{invalide' > "$work_dir/breaker.json"
run_fails "Manifeste JSON invalide refusé" \
  php "$manifest_tool" validate "$work_dir/breaker.json"

printf '{"status":"up"}' > "$work_dir/health.json"
run_fails "JSON non conforme au schéma refusé" \
  php "$manifest_tool" validate "$work_dir/health.json"

cp "$manifest_file" "$work_dir/manifest-missing.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);unset($d["artifact"]["id"]);file_put_contents($f,json_encode($d));' "$work_dir/manifest-missing.json"
run_fails_with_message "Champ obligatoire absent refusé" "Champ obligatoire absent" \
  php "$manifest_tool" validate "$work_dir/manifest-missing.json"

cp "$manifest_file" "$work_dir/manifest-empty.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);$d["version"]="";file_put_contents($f,json_encode($d));' "$work_dir/manifest-empty.json"
run_fails_with_message "Champ obligatoire vide refusé" "Champ obligatoire vide" \
  php "$manifest_tool" validate "$work_dir/manifest-empty.json"

create_staging_manifest "$work_dir/manifest-bad-sha.json" "pas-un-sha"
run_fails_with_message "Empreinte SHA-256 invalide refusée" "Format invalide pour artifact.sha256" \
  php "$manifest_tool" validate "$work_dir/manifest-bad-sha.json"

create_staging_manifest "$work_dir/manifest-bad-date.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);$d["created_at"]="2026-13-40T99:99:99Z";file_put_contents($f,json_encode($d));' "$work_dir/manifest-bad-date.json"
run_fails_with_message "Date invalide refusée" "Date invalide pour created_at" \
  php "$manifest_tool" validate "$work_dir/manifest-bad-date.json"

create_staging_manifest "$work_dir/manifest-bad-env.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);$d["environment"]="preprod";file_put_contents($f,json_encode($d));' "$work_dir/manifest-bad-env.json"
run_fails_with_message "Environnement inconnu refusé" "Valeur invalide pour environment" \
  php "$manifest_tool" validate "$work_dir/manifest-bad-env.json"

create_staging_manifest "$work_dir/manifest-bad-version.json" "$(fake_sha256 d)" "v0.2"
run_fails_with_message "Version SemVer invalide refusée" "Version de release candidate invalide" \
  php "$manifest_tool" validate "$work_dir/manifest-bad-version.json"

create_staging_manifest "$work_dir/manifest-bad-run.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);$d["workflow"]["run_id"]="abc";file_put_contents($f,json_encode($d));' "$work_dir/manifest-bad-run.json"
run_fails_with_message "Identifiant de run non numérique refusé" "identifiant numérique" \
  php "$manifest_tool" validate "$work_dir/manifest-bad-run.json"

create_staging_manifest "$work_dir/manifest-bad-commit.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);$d["commit_sha"]="abc";file_put_contents($f,json_encode($d));' "$work_dir/manifest-bad-commit.json"
run_fails_with_message "SHA Git invalide refusé" "Format invalide pour commit_sha" \
  php "$manifest_tool" validate "$work_dir/manifest-bad-commit.json"

create_staging_manifest "$work_dir/manifest-bad-channel.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);$d["channel"]="stable";file_put_contents($f,json_encode($d));' "$work_dir/manifest-bad-channel.json"
run_fails_with_message "Canal incohérent refusé" "Version stable invalide" \
  php "$manifest_tool" validate "$work_dir/manifest-bad-channel.json"

create_production_manifest "$work_dir/manifest-production.json"
php "$manifest_tool" validate "$work_dir/manifest-production.json"
pass

cp "$work_dir/manifest-production.json" "$work_dir/manifest-production-missing.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);unset($d["staging"]["candidate_tag"]);file_put_contents($f,json_encode($d));' "$work_dir/manifest-production-missing.json"
run_fails_with_message "Manifeste de production sans candidate refusé" "Champ obligatoire absent" \
  php "$manifest_tool" validate "$work_dir/manifest-production-missing.json"

cp "$work_dir/manifest-production.json" "$work_dir/manifest-production-mismatch.json"
php -r '$f=$argv[1];$d=json_decode(file_get_contents($f),true);$d["staging"]["candidate_tag"]="v0.3.0-rc.1";file_put_contents($f,json_encode($d));' "$work_dir/manifest-production-mismatch.json"
run_fails_with_message "Candidate incohérente refusée" "ne correspond pas à la version stable" \
  php "$manifest_tool" validate "$work_dir/manifest-production-mismatch.json"

# ---------------------------------------------------------------------------
# 5. Promotion staging -> production
# ---------------------------------------------------------------------------

resolve_promotion="$script_dir/deploy/resolve-promotion.sh"
gh_mock_dir="$work_dir/gh"
promotion_repo="$work_dir/promotion"
promotion_output="$work_dir/promotion-output"

write_fake_gh() {
  cat > "$fake_bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  api)
    url="${2:-}"
    case "$url" in
      *"/actions/runs?"*)
        if [[ "$url" == *"page=2"* && -f "$GH_MOCK_DIR/runs-page2.json" ]]; then
          cat "$GH_MOCK_DIR/runs-page2.json"
        else
          cat "$GH_MOCK_DIR/runs.json"
        fi
        ;;
      *"/actions/runs/"*"/artifacts"*)
        if [[ "$url" == *"page=2"* && -f "$GH_MOCK_DIR/artifacts-page2.json" ]]; then
          cat "$GH_MOCK_DIR/artifacts-page2.json"
        else
          cat "$GH_MOCK_DIR/artifacts.json"
        fi
        ;;
      *) echo "fake gh: endpoint inattendu: $url" >&2; exit 1 ;;
    esac
    ;;
  run)
    name=""
    dir=""
    shift 2
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name) name="$2"; shift 2 ;;
        --dir) dir="$2"; shift 2 ;;
        --repo) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$dir"
    if [[ "$name" == chantier-package-* ]]; then
      cp -R "$GH_MOCK_DIR/package/." "$dir/"
    elif [[ "$name" == chantier-manifest-* ]]; then
      cp -R "$GH_MOCK_DIR/manifest/." "$dir/"
    else
      echo "fake gh: artefact inconnu: $name" >&2
      exit 1
    fi
    ;;
  *)
    echo "fake gh: commande inattendue: $1" >&2
    exit 1
    ;;
esac
FAKE_GH
  chmod +x "$fake_bin/gh"
}

write_fake_gh

init_promotion_repo() {
  local repo="$1"
  local mode="${2:-same-tree}"

  repo_init "$repo"
  (
    cd "$repo"
    printf 'base\n' > file.txt
    git add file.txt
    git commit --quiet -m "feat: base"
    git tag -a v0.2.0-rc.1 -m v0.2.0-rc.1
    git update-ref refs/remotes/origin/develop HEAD
    git switch --quiet -c main

    if [[ "$mode" == "mutate-tree" ]]; then
      printf 'changement\n' >> file.txt
      git add file.txt
      git commit --quiet -m "fix: changement divergent"
    else
      git commit --quiet --allow-empty -m "chore: fusion develop dans main"
    fi

    git tag -a v0.2.0 -m v0.2.0
    git update-ref refs/remotes/origin/main HEAD
  )
}

write_runs() {
  local file="$1"
  local head_sha="$2"
  local conclusion="$3"

  cat > "$file" <<JSON
{"total_count":1,"workflow_runs":[{"id":123,"status":"completed","conclusion":"${conclusion}","head_sha":"${head_sha}","event":"push","head_branch":"v0.2.0-rc.1","path":".github/workflows/deploy-staging.yml","created_at":"2026-11-12T10:00:00Z"}]}
JSON
}

write_artifacts() {
  local file="$1"
  local package_expired="$2"
  local manifest_expired="$3"

  cat > "$file" <<JSON
{"total_count":2,"artifacts":[{"id":456,"expired":${package_expired},"name":"chantier-package-v0.2.0-rc.1","size_in_bytes":2048},{"id":457,"expired":${manifest_expired},"name":"chantier-manifest-v0.2.0-rc.1","size_in_bytes":512}]}
JSON
}

write_manifest_fixture() {
  local file="$1"
  local sha="$2"
  local status="${3:-success}"

  php "$manifest_tool" create "$file" \
    schema_version=1 \
    environment=staging \
    version=v0.2.0-rc.1 \
    tag=v0.2.0-rc.1 \
    channel=rc \
    commit_sha="$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')" \
    tree_sha="$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{tree}')" \
    "workflow.name=deploy-staging" \
    "workflow.run_id=123" \
    "workflow.run_attempt=1" \
    "artifact.name=chantier-package-v0.2.0-rc.1" \
    "artifact.id=456" \
    "artifact.sha256=$sha" \
    staging_deployment.status="$status" \
    "staging_deployment.run_id=123" \
    staging_deployment.job=deploy \
    created_at=2026-11-12T10:00:00Z
}

run_promotion() {
  (
    cd "$promotion_repo"
    PATH="$fake_bin:$PATH" \
    GH_MOCK_DIR="$gh_mock_dir" \
    RELEASE_TAG=v0.2.0 \
    CANDIDATE_TAG=v0.2.0-rc.1 \
    GITHUB_REPOSITORY=C2ME-ORGA/chantier \
    WORK_DIR="$work_dir/promo-work" \
    GITHUB_OUTPUT="$promotion_output" \
    bash "$resolve_promotion"
  )
}

prepare_promotion_case() {
  local mode="${1:-same-tree}"

  rm -rf "$promotion_repo" "$gh_mock_dir" "$promotion_output" "$work_dir/promo-work"
  init_promotion_repo "$promotion_repo" "$mode"

  mkdir -p "$gh_mock_dir/package" "$gh_mock_dir/manifest"

  printf 'paquet\n' > "$gh_mock_dir/payload.txt"
  tar -czf "$gh_mock_dir/package/chantier-v0.2.0-rc.1.tar.gz" -C "$gh_mock_dir" payload.txt
  package_sha="$(sha256_of "$gh_mock_dir/package/chantier-v0.2.0-rc.1.tar.gz")"

  printf '%s  chantier-v0.2.0-rc.1.tar.gz\n' "$package_sha" \
    > "$gh_mock_dir/package/chantier-v0.2.0-rc.1.tar.gz.sha256"

  write_manifest_fixture "$gh_mock_dir/manifest/manifest.json" "$package_sha"
  write_runs "$gh_mock_dir/runs.json" "$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')" success
  write_artifacts "$gh_mock_dir/artifacts.json" false false
}

# 5.1 Promotion nominale.
prepare_promotion_case
: > "$promotion_output"

if run_promotion >/dev/null 2>&1; then
  pass
  assert_contains "$promotion_output" "candidate_tag=v0.2.0-rc.1" "Promotion nominale"
  assert_contains "$promotion_output" "staging_run_id=123" "Promotion nominale"
  assert_contains "$promotion_output" "package_artifact_id=456" "Promotion nominale"
  assert_contains "$promotion_output" "sha256=$package_sha" "Promotion nominale"
else
  fail "Promotion nominale : la résolution aurait dû réussir."
fi

# 5.2 Arbres Git différents.
prepare_promotion_case mutate-tree
run_fails "Arbres Git différents refusés" run_promotion

# 5.3 Artefact de paquet expiré.
prepare_promotion_case
write_artifacts "$gh_mock_dir/artifacts.json" true false
run_fails "Artefact expiré refusé" run_promotion

# 5.4 Manifeste manquant.
prepare_promotion_case
cat > "$gh_mock_dir/artifacts.json" <<'JSON'
{"total_count":1,"artifacts":[{"id":456,"expired":false,"name":"chantier-package-v0.2.0-rc.1","size_in_bytes":2048}]}
JSON
run_fails "Artefact de manifeste manquant refusé" run_promotion

# 5.5 Empreinte incorrecte.
prepare_promotion_case
printf 'contenu altéré\n' >> "$gh_mock_dir/package/chantier-v0.2.0-rc.1.tar.gz"
run_fails "Empreinte SHA-256 incorrecte refusée" run_promotion

# 5.6 Provenance incohérente.
prepare_promotion_case
write_runs "$gh_mock_dir/runs.json" "$(fake_sha b)" success
run_fails "Provenance incohérente refusée" run_promotion

# 5.7 Déploiement staging en échec.
prepare_promotion_case
write_runs "$gh_mock_dir/runs.json" "$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')" failure
run_fails "Exécution de staging en échec refusée" run_promotion

# 5.8 Tag de candidate non annoté.
prepare_promotion_case
git -C "$promotion_repo" tag -d v0.2.0-rc.1 >/dev/null
git -C "$promotion_repo" tag v0.2.0-rc.1 "$(git -C "$promotion_repo" rev-parse 'v0.2.0^{commit}')"
run_fails "Tag de candidate non annoté refusé" run_promotion

# 5.9 Statut de déploiement staging incohérent.
prepare_promotion_case
write_manifest_fixture "$gh_mock_dir/manifest/manifest.json" \
  "$(sha256_of "$gh_mock_dir/package/chantier-v0.2.0-rc.1.tar.gz")" failure
run_fails "Statut de staging incohérent refusé" run_promotion

# 5.10 Exécution de staging non terminée.
prepare_promotion_case
cat > "$gh_mock_dir/runs.json" <<JSON
{"total_count":1,"workflow_runs":[{"id":123,"status":"in_progress","conclusion":null,"head_sha":"$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')","event":"push","head_branch":"v0.2.0-rc.1","path":".github/workflows/deploy-staging.yml","created_at":"2026-11-12T10:00:00Z"}]}
JSON
run_fails "Exécution de staging non terminée refusée" run_promotion

# 5.11 Pagination des exécutions : la correspondance est en page 2.
prepare_promotion_case
rc_commit="$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')"
entries=""

for index in $(seq 1 100); do
  entries+="{\"id\":$((1000 + index)),\"status\":\"completed\",\"conclusion\":\"success\",\"head_sha\":\"$(fake_sha e)\",\"head_branch\":\"other-${index}\",\"event\":\"push\",\"path\":\".github/workflows/deploy-staging.yml\",\"created_at\":\"2026-11-12T09:00:00Z\"},"
done

printf '{"total_count":101,"workflow_runs":[%s]}\n' "${entries%,}" > "$gh_mock_dir/runs.json"
write_runs "$gh_mock_dir/runs-page2.json" "$rc_commit" success

if run_promotion >/dev/null 2>&1; then pass; else fail "Pagination des exécutions : la résolution aurait dû réussir."; fi

# 5.12 Pagination des artefacts.
prepare_promotion_case
entries=""

for index in $(seq 1 100); do
  entries+="{\"id\":$((2000 + index)),\"expired\":false,\"name\":\"other-${index}\",\"size_in_bytes\":1},"
done

printf '{"total_count":102,"artifacts":[%s]}\n' "${entries%,}" > "$gh_mock_dir/artifacts.json"
cat > "$gh_mock_dir/artifacts-page2.json" <<'JSON'
{"total_count":2,"artifacts":[{"id":456,"expired":false,"name":"chantier-package-v0.2.0-rc.1","size_in_bytes":2048},{"id":457,"expired":false,"name":"chantier-manifest-v0.2.0-rc.1","size_in_bytes":512}]}
JSON

if run_promotion >/dev/null 2>&1; then pass; else fail "Pagination des artefacts : la résolution aurait dû réussir."; fi

# 5.13 Plusieurs artefacts portant le même nom.
prepare_promotion_case
cat > "$gh_mock_dir/artifacts.json" <<'JSON'
{"total_count":3,"artifacts":[{"id":456,"expired":false,"name":"chantier-package-v0.2.0-rc.1","size_in_bytes":2048},{"id":458,"expired":false,"name":"chantier-package-v0.2.0-rc.1","size_in_bytes":2048},{"id":457,"expired":false,"name":"chantier-manifest-v0.2.0-rc.1","size_in_bytes":512}]}
JSON
run_fails_with_message "Artefact ambigu refusé" "ambiguïté" run_promotion

# 5.14 Événement de déclenchement inattendu.
prepare_promotion_case
rc_commit="$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')"
cat > "$gh_mock_dir/runs.json" <<JSON
{"total_count":1,"workflow_runs":[{"id":123,"status":"completed","conclusion":"success","head_sha":"$rc_commit","head_branch":"v0.2.0-rc.1","event":"workflow_dispatch","path":".github/workflows/deploy-staging.yml","created_at":"2026-11-12T10:00:00Z"}]}
JSON
run_fails_with_message "Événement inattendu refusé" "déclenchée par un push" run_promotion

# 5.15 Workflow inattendu.
prepare_promotion_case
rc_commit="$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')"
cat > "$gh_mock_dir/runs.json" <<JSON
{"total_count":1,"workflow_runs":[{"id":123,"status":"completed","conclusion":"success","head_sha":"$rc_commit","head_branch":"v0.2.0-rc.1","event":"push","path":".github/workflows/other.yml","created_at":"2026-11-12T10:00:00Z"}]}
JSON
run_fails_with_message "Workflow inattendu refusé" "workflow inattendu" run_promotion

# 5.16 Exécution sur un autre tag.
prepare_promotion_case
rc_commit="$(git -C "$promotion_repo" rev-parse 'v0.2.0-rc.1^{commit}')"
cat > "$gh_mock_dir/runs.json" <<JSON
{"total_count":1,"workflow_runs":[{"id":123,"status":"completed","conclusion":"success","head_sha":"$rc_commit","head_branch":"v0.2.0-rc.2","event":"push","path":".github/workflows/deploy-staging.yml","created_at":"2026-11-12T10:00:00Z"}]}
JSON
run_fails_with_message "Exécution d'un autre tag refusée" "aucune exécution" run_promotion

# ---------------------------------------------------------------------------
# 6. Script serveur : validation et dry-run
# ---------------------------------------------------------------------------

remote_deploy="$script_dir/deploy/remote-deploy.sh"
remote_check="$script_dir/deploy/remote-check.sh"

build_deploy_package() {
  local dir="$1"
  local include_env="${2:-no}"
  local payload="$dir/payload"

  rm -rf "$dir"
  mkdir -p "$payload/vendor" "$payload/public"

  printf '<?php\n' > "$payload/artisan"
  printf '<?php\n' > "$payload/vendor/autoload.php"
  printf '<?php\n' > "$payload/public/index.php"

  if [[ "$include_env" == "yes" ]]; then
    printf 'APP_ENV=staging\n' > "$payload/.env"
  fi

  tar -czf "$dir/package.tar.gz" -C "$payload" .

  rm -rf "$payload"
  sha256_of "$dir/package.tar.gz"
}

deploy_sha="$(build_deploy_package "$work_dir/deploy-pkg")"
deploy_commit="$(fake_sha a)"
deploy_tree="$(fake_sha b)"

run_deploy() {
  local environment="$1"
  local expected_path="$2"
  local sha="$3"
  local package="$4"

  bash "$remote_deploy" \
    --environment "$environment" \
    --release-id "v0.2.0-rc.1-123-1" \
    --version v0.2.0-rc.1 \
    --commit "$deploy_commit" \
    --tree "$deploy_tree" \
    --artifact-id 456 \
    --sha256 "$sha" \
    --package "$package" \
    --expected-path "$expected_path" \
    --route-cache true \
    --queue-restart false \
    --dry-run >/dev/null
}

run_deploy staging /www/wwwroot/chantier-staging "$deploy_sha" "$work_dir/deploy-pkg/package.tar.gz"
pass

run_fails "Environnement incorrect refusé" \
  bash "$remote_deploy" --environment testing --release-id "v0.2.0-rc.1-1-1" \
    --version v0.2.0-rc.1 --commit "$deploy_commit" --tree "$deploy_tree" \
    --artifact-id 456 --sha256 "$deploy_sha" --package "$work_dir/deploy-pkg/package.tar.gz" \
    --expected-path /www/wwwroot/chantier-staging --dry-run

run_fails "Chemin de production refusé en staging" \
  run_deploy staging /www/wwwroot/chantier "$deploy_sha" "$work_dir/deploy-pkg/package.tar.gz"

run_fails "Chemin de staging refusé en production" \
  run_deploy production /www/wwwroot/chantier-staging "$deploy_sha" "$work_dir/deploy-pkg/package.tar.gz"

run_fails "Empreinte incorrecte refusée" \
  run_deploy staging /www/wwwroot/chantier-staging "$(fake_sha256 c)" "$work_dir/deploy-pkg/package.tar.gz"

run_fails "Identifiant de release interdit refusé" \
  bash "$remote_deploy" --environment staging --release-id "../production" \
    --version v0.2.0-rc.1 --commit "$deploy_commit" --tree "$deploy_tree" \
    --artifact-id 456 --sha256 "$deploy_sha" --package "$work_dir/deploy-pkg/package.tar.gz" \
    --expected-path /www/wwwroot/chantier-staging --dry-run

env_sha="$(build_deploy_package "$work_dir/deploy-env" yes)"
run_fails "Paquet contenant un .env refusé" \
  run_deploy staging /www/wwwroot/chantier-staging "$env_sha" "$work_dir/deploy-env/package.tar.gz"

run_fails "Contrôle post-déploiement avec chemin interdit" \
  bash "$remote_check" --environment staging --release-id "v0.2.0-rc.1-123-1" \
    --version v0.2.0-rc.1 --commit "$deploy_commit" --sha256 "$deploy_sha" \
    --expected-path /www/wwwroot/chantier --dry-run

bash "$remote_check" --environment production --release-id "v0.2.0-123-1" \
  --version v0.2.0 --commit "$deploy_commit" --sha256 "$deploy_sha" \
  --expected-path /www/wwwroot/chantier --dry-run >/dev/null
pass

# 6.1 Contrôle du binaire PHP 8.4.
fake_php_dir="$work_dir/php"
mkdir -p "$fake_php_dir"

printf '#!/usr/bin/env bash\necho 8.4.27\n' > "$fake_php_dir/php84"
printf '#!/usr/bin/env bash\necho 8.3.9\n' > "$fake_php_dir/php83"
chmod +x "$fake_php_dir/php84" "$fake_php_dir/php83"

DEPLOY_PHP_BIN="$fake_php_dir/php84" bash "$remote_deploy" \
  --environment staging --expected-path /www/wwwroot/chantier-staging --preflight \
  > "$work_dir/preflight.out" 2>&1
pass
assert_contains "$work_dir/preflight.out" "php-version=8.4.27" "Contrôle PHP 8.4"

run_fails_with_message "PHP 8.3 refusé" "PHP 8.4 requis" \
  env DEPLOY_PHP_BIN="$fake_php_dir/php83" bash "$remote_deploy" \
  --environment production --expected-path /www/wwwroot/chantier --preflight

run_fails_with_message "Préflight avec chemin interdit refusé" "chemin cible refusé" \
  env DEPLOY_PHP_BIN="$fake_php_dir/php84" bash "$remote_deploy" \
  --environment staging --expected-path /www/wwwroot/chantier --preflight

# 6.2 Archives malveillantes.
archive_fixture="$script_dir/tests/create-archive-fixture.php"

build_fixture_archive() {
  local file="$1"
  shift

  php "$archive_fixture" "$file" "$@"
  sha256_of "$file"
}

symlink_sha="$(build_fixture_archive "$work_dir/evil-symlink.tar.gz" \
  "file:./artisan" "file:./vendor/autoload.php" "file:./public/index.php" \
  "symlink:./evil:/etc/passwd")"

run_fails_with_message "Archive avec lien symbolique refusée" "lien symbolique" \
  run_deploy staging /www/wwwroot/chantier-staging "$symlink_sha" "$work_dir/evil-symlink.tar.gz"

hardlink_sha="$(build_fixture_archive "$work_dir/evil-hardlink.tar.gz" \
  "file:./artisan" "file:./vendor/autoload.php" "file:./public/index.php" \
  "hardlink:./hardlink:./artisan")"

run_fails_with_message "Archive avec lien physique refusée" "lien physique" \
  run_deploy staging /www/wwwroot/chantier-staging "$hardlink_sha" "$work_dir/evil-hardlink.tar.gz"

absolute_sha="$(build_fixture_archive "$work_dir/evil-absolute.tar.gz" \
  "file:./artisan" "file:./vendor/autoload.php" "file:./public/index.php" \
  "file:/etc/passwd")"

run_fails_with_message "Archive avec chemin absolu refusée" "chemin absolu" \
  run_deploy staging /www/wwwroot/chantier-staging "$absolute_sha" "$work_dir/evil-absolute.tar.gz"

traversal_sha="$(build_fixture_archive "$work_dir/evil-traversal.tar.gz" \
  "file:./artisan" "file:./vendor/autoload.php" "file:./public/index.php" \
  "file:../evil")"

run_fails_with_message "Archive avec traversée de répertoire refusée" "traversée" \
  run_deploy staging /www/wwwroot/chantier-staging "$traversal_sha" "$work_dir/evil-traversal.tar.gz"

# 6.3 Politique de permissions de shared/.env.
for mode in 600 640 700 750; do
  if ( source "$remote_deploy"; env_mode_is_secure "$mode" ); then
    pass
  else
    fail "mode $mode : devrait être accepté."
  fi
done

for mode in 660 770; do
  if ( source "$remote_deploy"; env_mode_is_secure "$mode" ); then
    fail "mode $mode : devrait être refusé (écriture de groupe ou accès des autres)."
  else
    pass
  fi
done

if ( source "$remote_check"; env_mode_is_secure 640 ); then pass; else fail "remote-check : mode 640 devrait être accepté."; fi
if ( source "$remote_check"; env_mode_is_secure 660 ); then fail "remote-check : mode 660 devrait être refusé."; else pass; fi
if ( source "$remote_deploy"; env_mode_is_secure "abc" ); then fail "mode invalide : devrait être refusé."; else pass; fi

# 6.3bis Journalisation obligatoire dès que shared existe.
prepare_logging_check() {
  local case_dir="$1"
  local expected="$2"

  (
    source "$remote_deploy"
    root="$case_dir"
    shared="$case_dir/shared"
    prepare_logging
    [[ "$log_ready" -eq "$expected" ]]
  ) >/dev/null 2>&1
}

logging_case="$work_dir/log-absent"
rm -rf "$logging_case"
mkdir -p "$logging_case"
if prepare_logging_check "$logging_case" 0; then pass; else fail "shared absent : pré-déploiement attendu."; fi

logging_case="$work_dir/log-no-file"
rm -rf "$logging_case"
mkdir -p "$logging_case/shared"
if prepare_logging_check "$logging_case" 1; then pass; else fail "journal absent avec shared inscriptible : journalisation attendue."; fi

logging_case="$work_dir/log-writable"
rm -rf "$logging_case"
mkdir -p "$logging_case/shared"
printf 'log\n' > "$logging_case/shared/deployment.log"
chmod 600 "$logging_case/shared/deployment.log"
if prepare_logging_check "$logging_case" 1; then pass; else fail "journal inscriptible refusé."; fi

logging_case="$work_dir/log-symlink"
rm -rf "$logging_case"
mkdir -p "$logging_case/shared"
MSYS=winsymlinks:nativestrict ln -s /etc/passwd "$logging_case/shared/deployment.log"
if prepare_logging_check "$logging_case" 1; then fail "journal symbolique accepté."; else pass; fi

logging_case="$work_dir/log-directory"
rm -rf "$logging_case"
mkdir -p "$logging_case/shared/deployment.log"
if prepare_logging_check "$logging_case" 1; then fail "journal répertoire accepté."; else pass; fi

logging_case="$work_dir/log-readonly"
rm -rf "$logging_case"
mkdir -p "$logging_case/shared"
printf 'log\n' > "$logging_case/shared/deployment.log"
chmod 400 "$logging_case/shared/deployment.log"
if [[ -w "$logging_case/shared/deployment.log" ]]; then
  skip "journal non inscriptible non simulable sur ce système."
else
  if prepare_logging_check "$logging_case" 1; then fail "journal non inscriptible accepté."; else pass; fi
fi
chmod 600 "$logging_case/shared/deployment.log" 2>/dev/null || true

logging_case="$work_dir/shared-readonly"
rm -rf "$logging_case"
mkdir -p "$logging_case/shared"
chmod 500 "$logging_case/shared"
if [[ -w "$logging_case/shared" ]]; then
  skip "shared non inscriptible non simulable sur ce système."
else
  if prepare_logging_check "$logging_case" 0; then fail "shared non inscriptible accepté."; else pass; fi
fi
chmod 700 "$logging_case/shared" 2>/dev/null || true

logging_case="$work_dir/shared-symlink"
rm -rf "$logging_case"
mkdir -p "$logging_case/real-shared"
MSYS=winsymlinks:nativestrict ln -s "$logging_case/real-shared" "$logging_case/shared"
if prepare_logging_check "$logging_case" 1; then fail "shared symbolique accepté."; else pass; fi

logging_case="$work_dir/shared-file"
rm -rf "$logging_case"
mkdir -p "$logging_case"
printf 'not a directory\n' > "$logging_case/shared"
if prepare_logging_check "$logging_case" 0; then fail "shared fichier accepté."; else pass; fi

# 6.4 Nettoyage sécurisé : seuls les répertoires créés par l'exécution courante
# peuvent être supprimés.
cleanup_case="$work_dir/cleanup-inactive"
rm -rf "$cleanup_case"
mkdir -p "$cleanup_case/releases/old" "$cleanup_case/releases/other" "$cleanup_case/shared"
MSYS=winsymlinks:nativestrict ln -s "$cleanup_case/releases/other" "$cleanup_case/current"
(
  source "$remote_deploy"
  root="$cleanup_case"
  shared="$cleanup_case/shared"
  release_dir="$cleanup_case/releases/old"
  release_created=0
  activated=0
  cleanup_incomplete
)
[[ -d "$cleanup_case/releases/old" ]] && pass || fail "Une release inactive préexistante a été supprimée."
[[ -L "$cleanup_case/current" ]] && pass || fail "Le lien current a été supprimé."

cleanup_case="$work_dir/cleanup-active"
rm -rf "$cleanup_case"
mkdir -p "$cleanup_case/releases/old" "$cleanup_case/shared"
MSYS=winsymlinks:nativestrict ln -s "$cleanup_case/releases/old" "$cleanup_case/current"
(
  source "$remote_deploy"
  root="$cleanup_case"
  shared="$cleanup_case/shared"
  release_dir="$cleanup_case/releases/old"
  release_created=0
  activated=1
  cleanup_incomplete
)
[[ -d "$cleanup_case/releases/old" ]] && pass || fail "Une release active préexistante a été supprimée."

cleanup_case="$work_dir/cleanup-incoming-preexisting"
rm -rf "$cleanup_case"
mkdir -p "$cleanup_case/releases/.incoming-existing" "$cleanup_case/shared"
(
  source "$remote_deploy"
  root="$cleanup_case"
  shared="$cleanup_case/shared"
  incoming_dir="$cleanup_case/releases/.incoming-existing"
  incoming_created=0
  cleanup_incomplete
)
[[ -d "$cleanup_case/releases/.incoming-existing" ]] && pass || fail "Un répertoire .incoming préexistant a été supprimé."

cleanup_case="$work_dir/cleanup-incoming-created"
rm -rf "$cleanup_case"
mkdir -p "$cleanup_case/releases/.incoming-created" "$cleanup_case/shared"
(
  source "$remote_deploy"
  root="$cleanup_case"
  shared="$cleanup_case/shared"
  incoming_dir="$cleanup_case/releases/.incoming-created"
  incoming_created=1
  cleanup_incomplete
)
[[ ! -d "$cleanup_case/releases/.incoming-created" ]] && pass || fail "Le répertoire .incoming créé n'a pas été nettoyé."

cleanup_case="$work_dir/cleanup-release-created"
rm -rf "$cleanup_case"
mkdir -p "$cleanup_case/releases/active" "$cleanup_case/releases/new" "$cleanup_case/shared"
MSYS=winsymlinks:nativestrict ln -s "$cleanup_case/releases/active" "$cleanup_case/current"
(
  source "$remote_deploy"
  root="$cleanup_case"
  shared="$cleanup_case/shared"
  release_dir="$cleanup_case/releases/new"
  release_created=1
  activated=0
  cleanup_incomplete
)
[[ ! -d "$cleanup_case/releases/new" ]] && pass || fail "La release créée mais non activée n'a pas été nettoyée."
[[ -d "$cleanup_case/releases/active" ]] && pass || fail "La release active a été supprimée lors du nettoyage."

cleanup_case="$work_dir/cleanup-release-active"
rm -rf "$cleanup_case"
mkdir -p "$cleanup_case/releases/new" "$cleanup_case/shared"
MSYS=winsymlinks:nativestrict ln -s "$cleanup_case/releases/new" "$cleanup_case/current"
(
  source "$remote_deploy"
  root="$cleanup_case"
  shared="$cleanup_case/shared"
  release_dir="$cleanup_case/releases/new"
  release_created=1
  activated=1
  cleanup_incomplete
)
[[ -d "$cleanup_case/releases/new" ]] && pass || fail "La release activée a été supprimée."

# 6.5 Interruptions : les traps nettoient uniquement les répertoires créés.
signal_case="$work_dir/signal-term"
rm -rf "$signal_case"
mkdir -p "$signal_case/releases" "$signal_case/shared"
signal_status=0
(
  source "$remote_deploy"
  root="$signal_case"
  shared="$signal_case/shared"
  incoming_dir="$signal_case/releases/.incoming-signal"
  mkdir -p "$incoming_dir"
  incoming_created=1
  install_traps
  kill -TERM "$BASHPID"
  sleep 5
) >/dev/null 2>&1 || signal_status=$?
[[ "$signal_status" -eq 143 ]] && pass || fail "TERM : code de sortie inattendu ($signal_status)."
[[ ! -d "$signal_case/releases/.incoming-signal" ]] && pass || fail "TERM : le répertoire créé n'a pas été nettoyé."

signal_case="$work_dir/signal-term-preexisting"
rm -rf "$signal_case"
mkdir -p "$signal_case/releases/.incoming-existing" "$signal_case/shared"
(
  source "$remote_deploy"
  root="$signal_case"
  shared="$signal_case/shared"
  incoming_dir="$signal_case/releases/.incoming-existing"
  incoming_created=0
  install_traps
  kill -TERM "$BASHPID"
  sleep 5
) >/dev/null 2>&1 || true
[[ -d "$signal_case/releases/.incoming-existing" ]] && pass || fail "TERM : un répertoire préexistant a été supprimé."

for signal_name in HUP INT; do
  signal_case="$work_dir/signal-${signal_name}"
  rm -rf "$signal_case"
  mkdir -p "$signal_case/releases" "$signal_case/shared"
  (
    source "$remote_deploy"
    root="$signal_case"
    shared="$signal_case/shared"
    incoming_dir="$signal_case/releases/.incoming-signal"
    mkdir -p "$incoming_dir"
    incoming_created=1
    install_traps
    kill -"$signal_name" "$BASHPID"
    sleep 5
  ) >/dev/null 2>&1 || true
  [[ ! -d "$signal_case/releases/.incoming-signal" ]] && pass || fail "$signal_name : le répertoire créé n'a pas été nettoyé."
done

# 6.6 Sections critiques : les signaux sont ignorés entre création et indicateur.
for signal_name in HUP INT TERM; do
  mask_case="$work_dir/mask-${signal_name}"
  rm -rf "$mask_case"
  mkdir -p "$mask_case"
  mask_status=0
  (
    source "$remote_deploy"
    mask_signals
    kill -"$signal_name" "$BASHPID"
    sleep 1
    printf 'survived\n' > "$mask_case/survived"
  ) >/dev/null 2>&1 || mask_status=$?

  if [[ "$mask_status" -eq 0 && -f "$mask_case/survived" ]]; then
    pass
  else
    fail "mask_signals n'a pas ignoré $signal_name (status $mask_status)."
  fi
done

# ---------------------------------------------------------------------------
# 7. Assemblage du paquet
# ---------------------------------------------------------------------------
assemble="$script_dir/package/assemble-package.sh"
source_dir="$work_dir/app"
mkdir -p "$source_dir"/{vendor,public/build,bootstrap,storage/logs,node_modules,tests}
printf '<?php\n' > "$source_dir/artisan"
printf '{}\n' > "$source_dir/composer.json"
printf '{}\n' > "$source_dir/composer.lock"
printf '<?php\n' > "$source_dir/vendor/autoload.php"
printf '<?php\n' > "$source_dir/public/index.php"
printf '{}\n' > "$source_dir/public/build/manifest.json"
printf '<?php\n' > "$source_dir/bootstrap/app.php"
printf 'APP_KEY=secret\n' > "$source_dir/.env"
printf 'log\n' > "$source_dir/storage/logs/laravel.log"
printf 'dep\n' > "$source_dir/node_modules/index.js"
printf '<?php\n' > "$source_dir/tests/ExampleTest.php"

mkdir -p "$source_dir/.idea" "$source_dir/.vscode" "$source_dir/.fleet" "$source_dir/.nova" "$source_dir/.zed"
printf 'ide\n' > "$source_dir/.idea/workspace.xml"
printf 'ide\n' > "$source_dir/.vscode/settings.json"
printf 'ide\n' > "$source_dir/.fleet/settings.json"
printf 'ide\n' > "$source_dir/.nova/workspace.json"
printf 'ide\n' > "$source_dir/.zed/settings.json"
printf '{"secret":"local"}\n' > "$source_dir/.mcp.json"
printf '{}\n' > "$source_dir/boost.json"
printf '{}\n' > "$source_dir/opencode.json"
printf 'local\n' > "$source_dir/CLAUDE.md"
printf 'local\n' > "$source_dir/.phpactor.json"
printf '{}\n' > "$source_dir/auth.json"
printf '{}\n' > "$source_dir/public/fonts-manifest.dev.json"

# Fichiers sensibles et binaires Composer.
printf 'secret\n' > "$source_dir/.envrc"
printf 'secret\n' > "$source_dir/secrets.json"
printf 'secret\n' > "$source_dir/server.pem"
printf 'secret\n' > "$source_dir/app.key"
printf 'secret\n' > "$source_dir/id_rsa"
printf 'secret\n' > "$source_dir/id_ed25519"
printf 'secret\n' > "$source_dir/store.p12"
printf 'secret\n' > "$source_dir/store.pfx"
printf 'secret\n' > "$source_dir/store.jks"
printf 'secret\n' > "$source_dir/server.crt"

mkdir -p "$source_dir/resources/views" "$source_dir/vendor/bin"
printf 'view\n' > "$source_dir/resources/views/welcome.blade.php"
printf 'bin\n' > "$source_dir/vendor/bin/tool"
MSYS=winsymlinks:nativestrict ln -s ../autoload.php "$source_dir/vendor/bin/tool-link"

assemble_output="$work_dir/assemble-output"
bash "$assemble" --source "$source_dir" --output-dir "$assemble_output" --tag v0.2.0-rc.1 > "$assemble_output.stdout"

archive="$assemble_output/chantier-v0.2.0-rc.1.tar.gz"

if [[ -f "$archive" ]]; then pass; else fail "L'archive de déploiement doit être créée."; fi
assert_contains "$assemble_output.stdout" "archive_name=chantier-v0.2.0-rc.1.tar.gz" "Assemblage"

if [[ -f "$archive" ]]; then
  assert_contains "$assemble_output.stdout" "sha256=$(sha256_of "$archive")" "Assemblage"
else
  fail "Empreinte du paquet impossible à vérifier : archive absente."
fi

if [[ -f "$archive.sha256" ]]; then pass; else fail "L'empreinte du paquet doit être écrite."; fi

entries_file="$work_dir/entries.txt"
if [[ -f "$archive" ]]; then
  tar -tzf "$archive" > "$entries_file"
else
  : > "$entries_file"
fi
assert_contains "$entries_file" "./artisan" "Contenu du paquet"
assert_contains "$entries_file" "./public/build/manifest.json" "Contenu du paquet"
assert_not_contains "$entries_file" "./.env" "Contenu du paquet"
assert_not_contains "$entries_file" "./node_modules/" "Contenu du paquet"
assert_not_contains "$entries_file" "./storage/" "Contenu du paquet"
assert_not_contains "$entries_file" "./tests/" "Contenu du paquet"
assert_not_contains "$entries_file" "./.idea/" "Exclusion IDE"
assert_not_contains "$entries_file" "./.vscode/" "Exclusion IDE"
assert_not_contains "$entries_file" "./.fleet/" "Exclusion IDE"
assert_not_contains "$entries_file" "./.nova/" "Exclusion IDE"
assert_not_contains "$entries_file" "./.zed/" "Exclusion IDE"
assert_not_contains "$entries_file" "./.mcp.json" "Exclusion configuration locale"
assert_not_contains "$entries_file" "./boost.json" "Exclusion configuration locale"
assert_not_contains "$entries_file" "./opencode.json" "Exclusion configuration locale"
assert_not_contains "$entries_file" "./CLAUDE.md" "Exclusion configuration locale"
assert_not_contains "$entries_file" "./.phpactor.json" "Exclusion configuration locale"
assert_not_contains "$entries_file" "./auth.json" "Exclusion configuration locale"
assert_not_contains "$entries_file" "./public/fonts-manifest.dev.json" "Exclusion manifeste de développement"
assert_not_contains "$entries_file" "./.envrc" "Exclusion fichier d'environnement local"
assert_not_contains "$entries_file" "./secrets.json" "Exclusion secrets"
assert_not_contains "$entries_file" "./server.pem" "Exclusion certificat/clé"
assert_not_contains "$entries_file" "./app.key" "Exclusion clé"
assert_not_contains "$entries_file" "./id_rsa" "Exclusion clé SSH"
assert_not_contains "$entries_file" "./id_ed25519" "Exclusion clé SSH"
assert_not_contains "$entries_file" "./store.p12" "Exclusion keystore"
assert_not_contains "$entries_file" "./store.pfx" "Exclusion keystore"
assert_not_contains "$entries_file" "./store.jks" "Exclusion keystore"
assert_not_contains "$entries_file" "./server.crt" "Exclusion certificat"
assert_not_contains "$entries_file" "./vendor/bin/" "Exclusion binaires Composer"
assert_contains "$entries_file" "./resources/views/welcome.blade.php" "Fichier applicatif conservé"
assert_contains "$entries_file" "./vendor/autoload.php" "Autoload Composer conservé"

# Les liens sont refusés dès l'assemblage.
if MSYS=winsymlinks:nativestrict ln -s /etc/passwd "$source_dir/link-escape" 2>/dev/null; then
  run_fails_with_message "Lien symbolique refusé à l'assemblage" "lien symbolique" \
    bash "$assemble" --source "$source_dir" --output-dir "$work_dir/assemble-symlink" --tag v0.2.0-rc.1
  rm -f "$source_dir/link-escape"
else
  fail "Impossible de créer le lien symbolique de test."
fi

if ln "$source_dir/artisan" "$source_dir/hardlink-escape" 2>/dev/null; then
  run_fails_with_message "Lien physique refusé à l'assemblage" "lien physique" \
    bash "$assemble" --source "$source_dir" --output-dir "$work_dir/assemble-hardlink" --tag v0.2.0-rc.1
  rm -f "$source_dir/hardlink-escape"
else
  fail "Impossible de créer le lien physique de test."
fi

# Tags malveillants ou invalides : refus avant toute création de fichier.
for bad_tag in '../../evil' '/tmp/evil' 'v1.0.0/../evil' 'v1.0.0;touch-evil' 'v1.0.0 extra' 'v1.0.0-rc.0' 'v01.0.0' 'v1.0'; do
  run_fails "Tag invalide refusé : $bad_tag" \
    bash "$assemble" --source "$source_dir" --output-dir "$work_dir/assemble-bad-tag" --tag "$bad_tag"
done

[[ ! -d "$work_dir/assemble-bad-tag" ]] && pass || fail "Un tag invalide a créé un répertoire de sortie."
[[ ! -e "$work_dir/touch-evil" ]] && pass || fail "Un tag invalide a exécuté une commande."

bash "$assemble" --source "$source_dir" --output-dir "$work_dir/assemble-stable" --tag v1.0.0 >/dev/null
pass

rm -rf "$source_dir/vendor"
run_fails "Paquet incomplet refusé" \
  bash "$assemble" --source "$source_dir" --output-dir "$work_dir/assemble-broken" --tag v0.2.0-rc.1

# ---------------------------------------------------------------------------
# 8. Référence de la candidate dans les notes de release
# ---------------------------------------------------------------------------

stable_candidate="$script_dir/deploy/stable-candidate.sh"
notes_repo="$work_dir/notes"
notes_file="$work_dir/notes.md"

repo_init "$notes_repo"
(
  cd "$notes_repo"
  printf 'v1\n' > file.txt
  git add file.txt
  git commit --quiet -m "feat: version candidate"
  git tag -a v0.2.0-rc.1 -m v0.2.0-rc.1
  git switch --quiet -c main
  git commit --quiet --allow-empty -m "chore: fusion"
  git tag -a v0.2.0 -m v0.2.0
)

printf '# Release v0.2.0\n' > "$notes_file"
run_in_repo "$notes_repo" bash "$stable_candidate" --tag v0.2.0 --notes "$notes_file"
assert_contains "$notes_file" "Staging-Candidate: v0.2.0-rc.1" "Candidate staging référencée"

printf '# Release v0.2.0\n' > "$notes_file"
run_in_repo "$notes_repo" bash "$stable_candidate" --tag v0.2.0-rc.1 --notes "$notes_file"
assert_not_contains "$notes_file" "Staging-Candidate:" "Aucune section pour une candidate"

notes_repo="$work_dir/notes-divergent"
repo_init "$notes_repo"
(
  cd "$notes_repo"
  printf 'v1\n' > file.txt
  git add file.txt
  git commit --quiet -m "feat: version candidate"
  git tag -a v0.2.0-rc.1 -m v0.2.0-rc.1
  git switch --quiet -c main
  printf 'v2\n' >> file.txt
  git add file.txt
  git commit --quiet -m "fix: contenu différent"
  git tag -a v0.2.0 -m v0.2.0
)

printf '# Release v0.2.0\n' > "$notes_file"
run_in_repo "$notes_repo" bash "$stable_candidate" --tag v0.2.0 --notes "$notes_file"
assert_not_contains "$notes_file" "Staging-Candidate:" "Arbre différent non référencé"
assert_contains "$notes_file" "sera refusé" "Arbre différent non référencé"

# ---------------------------------------------------------------------------
# 9. Invariants statiques des scripts
# ---------------------------------------------------------------------------

scripts_dir="$script_dir"
workflows_dir="$project_root/.github/workflows"

if grep -rEl 'artisan[[:space:]]+migrate|migrate[[:space:]]+--force' \
  "$scripts_dir/lib" "$scripts_dir/deploy" "$scripts_dir/package" "$workflows_dir" >/dev/null 2>&1; then
  fail "Aucune migration automatique ne doit être déclenchée."
else
  pass
fi

if grep -rEl 'artisan[[:space:]]+down|maintenance:activate' \
  "$scripts_dir/lib" "$scripts_dir/deploy" "$scripts_dir/package" "$workflows_dir" >/dev/null 2>&1; then
  fail "Le mode maintenance ne doit pas être activé automatiquement."
else
  pass
fi

if grep -rEq '(^|[[:space:]])sudo([[:space:]]|$)' \
  "$scripts_dir/deploy/remote-deploy.sh" "$scripts_dir/deploy/remote-check.sh"; then
  fail "Les scripts serveur ne doivent pas utiliser sudo."
else
  pass
fi

if grep -rEq 'echo[[:space:]]+"?\$\{?SSH_PRIVATE_KEY|set[[:space:]]+-x' "$workflows_dir"; then
  fail "Aucun secret SSH ne doit être affiché dans les journaux."
else
  pass
fi

if grep -rEq 'cat[[:space:]]+[^|]*\.env' "$scripts_dir/deploy" "$workflows_dir"; then
  fail "Aucun fichier .env ne doit être affiché."
else
  pass
fi

if grep -Fq 'chantier.c2me.fr' "$workflows_dir/deploy-staging.yml"; then
  fail "Le workflow de staging ne doit pas référencer la production."
else
  pass
fi

if grep -Fq 'StrictHostKeyChecking=yes' "$workflows_dir/deploy-staging.yml" \
  && grep -Fq 'StrictHostKeyChecking=yes' "$workflows_dir/deploy-production.yml"; then
  pass
else
  fail "Les workflows doivent imposer une vérification stricte de l'hôte SSH."
fi

# ---------------------------------------------------------------------------
# Résultat
# ---------------------------------------------------------------------------

printf '%d assertions réussies, %d échec(s).\n' "$passed" "$failed"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
