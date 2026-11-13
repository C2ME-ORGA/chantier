#!/usr/bin/env bash
#
# Assemble le paquet de déploiement à partir d'une application déjà installée.
#
# Le paquet contient le code Laravel, `vendor/` et les assets Vite. Il exclut
# les fichiers locaux, les secrets, les journaux, les sessions, les fichiers
# IDE et les données applicatives. Aucun fichier de verrouillage n'est modifié.
# Les liens symboliques et physiques sont refusés.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/versions.sh
source "$script_dir/../lib/versions.sh"

usage() {
  cat <<'USAGE'
Usage : assemble-package.sh --source <dossier> --output-dir <dossier> --tag <tag>

Produit chantier-<tag>.tar.gz et chantier-<tag>.tar.gz.sha256.
Le tag doit être une version stable vX.Y.Z ou une release candidate vX.Y.Z-rc.N.
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

# Les extensions sensibles sont contrôlées sur le chemin complet : un fichier
# `server.pem` doit être refusé, pas seulement un fichier littéralement nommé
# `.pem`. Les noms d'outils locaux sont contrôlés séparément.
assert_no_sensitive_entries() {
  local entries="$1"
  local pattern

  local patterns=(
    '(^|/)\.envrc$'
    '(^|/)secrets\.json$'
    '(^|/)id_rsa[^/]*$'
    '(^|/)id_ed25519[^/]*$'
    '\.pem$'
    '\.key$'
    '\.p12$'
    '\.pfx$'
    '\.jks$'
    '\.crt$'
  )

  for pattern in "${patterns[@]}"; do
    if grep -Eq -- "$pattern" "$entries"; then
      fail "fichier sensible détecté dans l'archive : $pattern"
    fi
  done
}

assert_no_local_entries() {
  local entries="$1"
  local pattern

  pattern='^\./(\.idea|\.vscode|\.fleet|\.nova|\.zed|\.agents|\.amp|\.claude|\.codex|\.cursor|\.factory|\.grok|\.junie|\.kiro|\.pi)/|^\./(\.mcp\.json|boost\.json|opencode\.json|opencode\.jsonc|CLAUDE\.md|auth\.json|Homestead\.json|Homestead\.yaml|\.phpactor\.json|\.DS_Store|Thumbs\.db)$|^\./public/fonts-manifest\.dev\.json$'

  if grep -Eq -- "$pattern" "$entries"; then
    fail "fichier local détecté dans l'archive"
  fi
}

assert_vendor_complete() {
  local entries="$1"
  local required

  for required in \
    './vendor/autoload.php' \
    './vendor/composer/autoload_real.php' \
    './vendor/composer/autoload_static.php' \
    './vendor/composer/installed.php'; do
    grep -Fqx -- "$required" "$entries" || fail "dépendance Composer absente de l'archive : $required"
  done

  if grep -Eq '^\./vendor/bin($|/)' "$entries"; then
    fail "vendor/bin ne doit pas être présent dans l'archive"
  fi
}

main() {
  source_dir="."
  output_dir=""
  tag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source_dir="${2:-}"; shift 2 ;;
      --output-dir) output_dir="${2:-}"; shift 2 ;;
      --tag) tag="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; exit 64 ;;
    esac
  done

  if [[ -z "$output_dir" || -z "$tag" ]]; then
    usage >&2
    exit 64
  fi

  # Validation stricte avant toute création ou suppression de fichier : le tag
  # ne doit contenir aucun séparateur de chemin ni caractère supplémentaire.
  if ! version_is_stable "$tag" && ! version_is_rc "$tag"; then
    fail "tag invalide, format attendu vX.Y.Z ou vX.Y.Z-rc.N : $tag"
  fi

  if [[ "$tag" == */* || "$tag" == *..* || "$tag" == /* ]]; then
    fail "tag interdit : séparateur de chemin ou traversée détecté"
  fi

  [[ -d "$source_dir" ]] || fail "dossier source introuvable : $source_dir"

  for required in artisan composer.json composer.lock public/index.php bootstrap/app.php vendor/autoload.php public/build; do
    [[ -e "$source_dir/$required" ]] || fail "élément obligatoire absent du paquet : $required"
  done

  mkdir -p "$output_dir"

  archive_name="chantier-${tag}.tar.gz"
  archive_path="$output_dir/$archive_name"
  entries_file="$(mktemp "${TMPDIR:-/tmp}/chantier-entries.XXXXXX")"
  verbose_file="$(mktemp "${TMPDIR:-/tmp}/chantier-verbose.XXXXXX")"

  cleanup() {
    local status=$?

    trap - EXIT

    rm -f -- "$entries_file" "$verbose_file"

    if [[ "$status" -ne 0 ]]; then
      rm -f -- "$archive_path" "$archive_path.sha256"
    fi

    exit "$status"
  }

  trap cleanup EXIT

  rm -f "$archive_path" "$archive_path.sha256"

  tar \
    --exclude='.git' \
    --exclude='.github' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='.envrc' \
    --exclude='.phpunit.cache' \
    --exclude='.phpunit.result.cache' \
    --exclude='.phpactor.json' \
    --exclude='.idea' \
    --exclude='.vscode' \
    --exclude='.fleet' \
    --exclude='.nova' \
    --exclude='.zed' \
    --exclude='.agents' \
    --exclude='.amp' \
    --exclude='.claude' \
    --exclude='.codex' \
    --exclude='.cursor' \
    --exclude='.factory' \
    --exclude='.grok' \
    --exclude='.junie' \
    --exclude='.kiro' \
    --exclude='.pi' \
    --exclude='.mcp.json' \
    --exclude='boost.json' \
    --exclude='opencode.json' \
    --exclude='opencode.jsonc' \
    --exclude='CLAUDE.md' \
    --exclude='auth.json' \
    --exclude='secrets.json' \
    --exclude='id_rsa*' \
    --exclude='id_ed25519*' \
    --exclude='*.pem' \
    --exclude='*.key' \
    --exclude='*.p12' \
    --exclude='*.pfx' \
    --exclude='*.jks' \
    --exclude='*.crt' \
    --exclude='vendor/bin' \
    --exclude='./vendor/bin' \
    --exclude='vendor/bin/*' \
    --exclude='Homestead.json' \
    --exclude='Homestead.yaml' \
    --exclude='node_modules' \
    --exclude='tests' \
    --exclude='docs' \
    --exclude='storage' \
    --exclude='public/storage' \
    --exclude='public/hot' \
    --exclude='public/fonts-manifest.dev.json' \
    --exclude='bootstrap/cache/*.php' \
    --exclude='*.sqlite' \
    --exclude='*.log' \
    --exclude='*.iml' \
    --exclude='*.swp' \
    --exclude='*~' \
    --exclude='.DS_Store' \
    --exclude='Thumbs.db' \
    --exclude='.history' \
    --exclude='.cache' \
    --exclude='phpunit.xml' \
    --exclude='phpstan.neon' \
    --exclude='pint.json' \
    --exclude='.editorconfig' \
    --exclude='.gitattributes' \
    --exclude='.gitignore' \
    --exclude='AGENTS.md' \
    --exclude='README.md' \
    -czf "$archive_path" \
    -C "$source_dir" .

  [[ -s "$archive_path" ]] || fail "archive vide : $archive_path"

  tar -tzf "$archive_path" > "$entries_file"
  tar -tvzf "$archive_path" > "$verbose_file"

  if grep -Eq '^[lhbcp]' "$verbose_file"; then
    fail "lien symbolique, lien physique ou fichier spécial détecté dans l'archive"
  fi

  for required in './artisan' './vendor/autoload.php' './public/index.php' './bootstrap/app.php'; do
    grep -Fqx -- "$required" "$entries_file" || fail "entrée obligatoire absente de l'archive : $required"
  done

  assert_vendor_complete "$entries_file"

  grep -Eq '^\./public/build/' "$entries_file" || fail "assets Vite absents de l'archive"

  if grep -Eq '(^/)|(^|/)\.\.(/|$)' "$entries_file"; then
    fail "chemin absolu ou traversée de répertoire détecté dans l'archive"
  fi

  for forbidden in '\.env($|\.)' 'node_modules/' '(^|/)\.git/' 'storage/logs/'; do
    if grep -Eq -- "$forbidden" "$entries_file"; then
      fail "contenu interdit détecté dans l'archive : $forbidden"
    fi
  done

  assert_no_local_entries "$entries_file"
  assert_no_sensitive_entries "$entries_file"

  checksum="$(sha256sum "$archive_path" | awk '{print $1}')"

  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail "empreinte SHA-256 invalide pour $archive_name"

  printf '%s  %s\n' "$checksum" "$archive_name" > "$archive_path.sha256"

  emit archive_name "$archive_name"
  emit archive_path "$archive_path"
  emit sha256 "$checksum"
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
