#!/usr/bin/env bash
#
# Test d'assemblage du paquet sur Linux : vérifie que les liens symboliques
# générés par Composer dans vendor/bin sont exclus, que le paquet reste complet
# et que les liens présents ailleurs sont toujours refusés.
#
# Ce test copie le working tree courant (fichiers suivis modifiés et non suivis
# inclus) dans un répertoire temporaire, puis construit réellement les
# dépendances et les assets.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
work_dir="$(mktemp -d)"
out_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$work_dir" "$out_dir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'SKIP: test Linux uniquement (système détecté : %s).\n' "$(uname -s)"
  exit 0
fi

php -r 'exit(PHP_VERSION_ID >= 80400 && PHP_VERSION_ID < 80500 ? 0 : 1);' \
  || fail "PHP 8.4 requis, version détectée : $(php -r 'echo PHP_VERSION;')"

node --version | grep -Eq '^v22\.' \
  || fail "Node 22 requis, version détectée : $(node --version)"

tar \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='vendor' \
  --exclude='.env' \
  --exclude='public/build' \
  --exclude='bootstrap/cache/*.php' \
  --exclude='.phpunit.cache' \
  -C "$project_root" -cf - . | tar -C "$work_dir" -xf -

cd "$work_dir"

composer_lock_before="$(sha256sum composer.lock | awk '{print $1}')"
package_lock_before="$(sha256sum package-lock.json | awk '{print $1}')"

composer install \
  --no-dev \
  --no-interaction \
  --prefer-dist \
  --optimize-autoloader \
  --no-progress

npm ci
npm run build

[[ "$(sha256sum composer.lock | awk '{print $1}')" == "$composer_lock_before" ]] \
  || fail "composer.lock a été modifié pendant le build"

[[ "$(sha256sum package-lock.json | awk '{print $1}')" == "$package_lock_before" ]] \
  || fail "package-lock.json a été modifié pendant le build"

vendor_bin_symlinks=0

if [[ -d vendor/bin ]]; then
  vendor_bin_symlinks="$(find vendor/bin -type l | wc -l)"
fi

printf 'Liens symboliques dans vendor/bin : %s\n' "$vendor_bin_symlinks"

if [[ "$vendor_bin_symlinks" -eq 0 ]]; then
  printf 'AVERTISSEMENT: aucun lien vendor/bin détecté ; le test reste valide.\n'
fi

tag='v0.0.0-rc.1'
archive="$out_dir/chantier-${tag}.tar.gz"

bash .github/scripts/package/assemble-package.sh \
  --source . \
  --output-dir "$out_dir" \
  --tag "$tag" > "$out_dir/assemble.log"

[[ -f "$archive" ]] || fail "archive absente après assemblage"

tar -tzf "$archive" > "$work_dir/entries.txt"

if grep -Eq '^\./vendor/bin/' "$work_dir/entries.txt"; then
  fail "vendor/bin est présent dans l'archive"
fi

grep -Fqx -- './vendor/autoload.php' "$work_dir/entries.txt" \
  || fail "vendor/autoload.php absent de l'archive"

grep -Fqx -- './artisan' "$work_dir/entries.txt" \
  || fail "artisan absent de l'archive"

# Contenu local, sensible ou de développement interdit.
for pattern in \
  '^\./(\.idea|\.vscode|\.fleet|\.nova|\.zed)/' \
  '^\./(\.mcp\.json|boost\.json|opencode\.json|CLAUDE\.md|auth\.json|secrets\.json|\.envrc)$' \
  '^\./public/fonts-manifest\.dev\.json$' \
  '^\./\.env$' \
  '^\./(storage|tests|docs|\.github)/' \
  '(^|/)\.(pem|key|p12|pfx|jks|crt)$' \
  '(^|/)id_(rsa|ed25519)[^/]*$'; do
  if grep -Eq -- "$pattern" "$work_dir/entries.txt"; then
    fail "contenu interdit dans l'archive : $pattern"
  fi
done

tar -tvzf "$archive" > "$work_dir/verbose.txt"

if grep -Eq '^[lhbcp]' "$work_dir/verbose.txt"; then
  fail "lien ou fichier spécial présent dans l'archive"
fi

mkdir -p "$work_dir/extract"
tar -xzf "$archive" -C "$work_dir/extract"

if grep -RIlE 'BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|APP_KEY=base64:|DB_PASSWORD=|SSH_PRIVATE_KEY' \
  "$work_dir/extract" >/dev/null 2>&1; then
  fail "motif de secret détecté dans l'archive"
fi

# Un lien ailleurs que vendor/bin doit toujours être refusé.
ln -s /etc/passwd "$work_dir/link-escape"

if bash .github/scripts/package/assemble-package.sh \
  --source . \
  --output-dir "$out_dir/refused" \
  --tag "$tag" > "$out_dir/refused.log" 2>&1; then
  fail "un lien symbolique hors vendor/bin a été accepté"
fi

rm -f "$work_dir/link-escape"

[[ ! -f "$out_dir/refused/chantier-${tag}.tar.gz" ]] \
  || fail "une archive invalide a été conservée après refus"

printf 'PASS: build Linux, vendor/bin exclu, liens hors vendor/bin refusés.\n'
printf 'SHA-256 du paquet : %s\n' "$(sha256sum "$archive" | awk '{print $1}')"
