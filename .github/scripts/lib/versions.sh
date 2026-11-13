#!/usr/bin/env bash
#
# Helpers de validation des formats de version.
#
# Ce fichier est destiné à être sourcé (`source`). Il ne doit provoquer aucun
# effet de bord : aucune écriture, aucun accès réseau et aucune sortie.

# Version stable : vX.Y.Z, sans zéro initial.
version_is_stable() {
  local pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

  [[ "${1:-}" =~ $pattern ]]
}

# Release candidate : vX.Y.Z-rc.N, N commençant à 1.
version_is_rc() {
  local pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc\.([1-9][0-9]*)$'

  [[ "${1:-}" =~ $pattern ]]
}

# Version de base d'une release candidate : vX.Y.Z.
version_base() {
  local tag="${1:-}"

  if ! version_is_rc "$tag"; then
    return 1
  fi

  printf '%s\n' "${tag%%-rc.*}"
}

# Numéro de candidate d'une release candidate : N.
version_rc_number() {
  local tag="${1:-}"

  if ! version_is_rc "$tag"; then
    return 1
  fi

  printf '%s\n' "${tag##*-rc.}"
}
