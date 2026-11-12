#!/usr/bin/env bash
#
# Tests de l'automatisation de release : génération des notes et filtres du
# workflow GitHub Actions.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
notes_script="$script_dir/generate-release-notes.sh"
workflow="$project_root/.github/workflows/release.yml"
work_dir="$(mktemp -d)"

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

init_repo() {
  local repo="$1"

  mkdir -p "$repo"
  (
    cd "$repo"
    git init --quiet
    git config user.name "Release Automation Test"
    git config user.email "release-test@example.com"
    printf 'initial\n' > file.txt
    git add file.txt
    git commit --quiet -m "feat: initialiser le dépôt"
  )
}

commit_change() {
  local repo="$1"
  local message="$2"
  local body="${3:-}"

  (
    cd "$repo"
    printf '%s\n' "$message" >> file.txt
    git add file.txt

    if [[ -n "$body" ]]; then
      git commit --quiet -m "$message" -m "$body"
    else
      git commit --quiet -m "$message"
    fi
  )
}

tag_annotated() {
  local repo="$1"
  local tag="$2"

  (
    cd "$repo"
    git tag -a "$tag" -m "$tag"
  )
}

tag_lightweight() {
  local repo="$1"
  local tag="$2"

  (
    cd "$repo"
    git tag "$tag"
  )
}

current_branch() {
  (
    cd "$1"
    git branch --show-current
  )
}

run_notes() {
  local repo="$1"
  shift

  (
    cd "$repo"
    GITHUB_REPOSITORY="C2ME-ORGA/chantier" bash "$notes_script" "$@"
  )
}

run_notes_fails() {
  local repo="$1"
  shift

  if (
    cd "$repo"
    GITHUB_REPOSITORY="C2ME-ORGA/chantier" bash "$notes_script" "$@"
  ) >/dev/null 2>&1; then
    fail "La commande de génération aurait dû échouer : $*."
  else
    pass
  fi
}

# 1. Première release sans tag précédent.
repo="$work_dir/first-release"
init_repo "$repo"
tag_annotated "$repo" v0.1.0
run_notes "$repo" v0.1.0 notes.md
assert_contains "$repo/notes.md" '# Release v0.1.0' 'Première release'
assert_contains "$repo/notes.md" 'Première version publiée.' 'Première release'
assert_contains "$repo/notes.md" 'initialiser le dépôt' 'Première release'
assert_not_contains "$repo/notes.md" 'Changements depuis' 'Première release'

# 2. Version stable avec plusieurs tags stables.
repo="$work_dir/stable-multiple"
init_repo "$repo"
tag_annotated "$repo" v0.1.0
commit_change "$repo" "feat(stable): première version stable"
tag_annotated "$repo" v0.2.0
commit_change "$repo" "fix(stable): correction de la version suivante"
tag_annotated "$repo" v0.3.0
run_notes "$repo" v0.3.0 notes.md
assert_contains "$repo/notes.md" 'Changements depuis `v0.2.0`' 'Tags stables multiples'
assert_contains "$repo/notes.md" 'correction de la version suivante' 'Tags stables multiples'
assert_not_contains "$repo/notes.md" 'première version stable' 'Tags stables multiples'

# 3. Tags stables divergents non ancêtres.
repo="$work_dir/divergent-stable"
init_repo "$repo"
tag_annotated "$repo" v0.1.0
base_branch="$(current_branch "$repo")"
(
  cd "$repo"
  git switch --quiet -c side v0.1.0
)
commit_change "$repo" "feat(divergent): changement hors historique"
tag_annotated "$repo" v0.9.0
(
  cd "$repo"
  git switch --quiet "$base_branch"
)
commit_change "$repo" "feat(stable): changement principal"
tag_annotated "$repo" v0.2.0
run_notes "$repo" v0.2.0 notes.md
assert_contains "$repo/notes.md" 'Changements depuis `v0.1.0`' 'Tag stable divergent'
assert_contains "$repo/notes.md" 'changement principal' 'Tag stable divergent'
assert_not_contains "$repo/notes.md" 'changement hors historique' 'Tag stable divergent'
assert_not_contains "$repo/notes.md" 'v0.9.0' 'Tag stable divergent'
run_notes_fails "$repo" v0.2.0 explicit.md v0.9.0

# 4. Première release candidate.
repo="$work_dir/first-rc"
init_repo "$repo"
tag_annotated "$repo" v0.1.0
commit_change "$repo" "feat(rc): fonctionnalité candidate"
tag_annotated "$repo" v0.2.0-rc.1
run_notes "$repo" v0.2.0-rc.1 notes.md
assert_contains "$repo/notes.md" '# Release candidate v0.2.0-rc.1' 'Première RC'
assert_contains "$repo/notes.md" 'Changements depuis `v0.1.0`' 'Première RC'
assert_contains "$repo/notes.md" 'fonctionnalité candidate' 'Première RC'

# 5. RC suivante de la même version.
commit_change "$repo" "fix(rc): correction de la candidate"
tag_annotated "$repo" v0.2.0-rc.2
run_notes "$repo" v0.2.0-rc.2 notes.md
assert_contains "$repo/notes.md" 'Changements depuis `v0.2.0-rc.1`' 'RC suivante'
assert_contains "$repo/notes.md" 'correction de la candidate' 'RC suivante'
assert_not_contains "$repo/notes.md" 'fonctionnalité candidate' 'RC suivante'

# 6. RC divergente non ancêtre.
repo="$work_dir/divergent-rc"
init_repo "$repo"
tag_annotated "$repo" v0.1.0
commit_change "$repo" "feat(rc): fonctionnalité de base"
tag_annotated "$repo" v0.2.0-rc.1
base_branch="$(current_branch "$repo")"
(
  cd "$repo"
  git switch --quiet -c side v0.1.0
)
commit_change "$repo" "feat(rc): candidate divergente"
tag_annotated "$repo" v0.2.0-rc.9
(
  cd "$repo"
  git switch --quiet "$base_branch"
)
commit_change "$repo" "fix(rc): correction de la candidate"
tag_annotated "$repo" v0.2.0-rc.2
run_notes "$repo" v0.2.0-rc.2 notes.md
assert_contains "$repo/notes.md" 'Changements depuis `v0.2.0-rc.1`' 'RC divergente'
assert_contains "$repo/notes.md" 'correction de la candidate' 'RC divergente'
assert_not_contains "$repo/notes.md" 'candidate divergente' 'RC divergente'
assert_not_contains "$repo/notes.md" 'v0.2.0-rc.9' 'RC divergente'

# 7. Tags invalides.
repo="$work_dir/invalid-tags"
init_repo "$repo"
tag_annotated "$repo" v0.1.0
run_notes_fails "$repo" v0.2 notes.md
run_notes_fails "$repo" v0.2.0-rc.0 notes.md
run_notes_fails "$repo" v01.2.0 notes.md

# 8. Tag léger au lieu d'un tag annoté.
repo="$work_dir/lightweight-tag"
init_repo "$repo"
tag_lightweight "$repo" v0.1.0
run_notes_fails "$repo" v0.1.0 notes.md

# 9. Filtres de déclenchement du workflow.
filters="$(
  awk '
    /^on:[[:space:]]*$/ { in_on = 1; next }
    in_on && /^[^[:space:]]/ { in_on = 0 }
    in_on && /^[[:space:]]+tags:[[:space:]]*$/ { in_tags = 1; next }
    in_tags && /^[[:space:]]+-[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]+-[[:space:]]*/, "", value)
      print value
      next
    }
    in_tags { in_tags = 0 }
  ' "$workflow" | tr -d "'"
)"

if [[ "$filters" == "v*" ]]; then
  pass
else
  fail "Le filtre de tags du workflow doit être 'v*', obtenu : '$filters'."
fi

for tag in v0.1.0 v0.1.0-rc.1; do
  case "$tag" in
    $filters) pass ;;
    *) fail "Le filtre '$filters' ne correspond pas au tag '$tag'." ;;
  esac
done

if grep -Fq -- '[0-9]+' "$workflow"; then
  fail "Le workflow ne doit plus utiliser de filtre de tags avec '[0-9]+'."
else
  pass
fi

if grep -Fq 'target_ref="origin/main"' "$workflow" \
  && grep -Fq 'target_ref="origin/develop"' "$workflow" \
  && grep -Fq 'tag_sha="$(git rev-parse "${RELEASE_TAG}^{commit}")"' "$workflow"; then
  pass
else
  fail "Le workflow doit comparer exactement le commit du tag avec origin/main ou origin/develop."
fi

validate_line="$(grep -n 'name: Validate release tag' "$workflow" | head -n 1 | cut -d: -f1 || true)"
release_line="$(grep -n 'name: Create or update GitHub release' "$workflow" | head -n 1 | cut -d: -f1 || true)"

if [[ -n "$validate_line" && -n "$release_line" && "$validate_line" -lt "$release_line" ]]; then
  pass
else
  fail "La validation du tag doit précéder la création de la release."
fi

if grep -Fq 'Tag de release invalide' "$workflow" \
  && grep -Fq 'git cat-file -t "refs/tags/${RELEASE_TAG}"' "$workflow"; then
  pass
else
  fail "Le workflow doit conserver la validation stricte du format et du tag annoté."
fi

printf '%d assertions réussies, %d échec(s).\n' "$passed" "$failed"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
