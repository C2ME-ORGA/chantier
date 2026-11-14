#!/usr/bin/env bash
#
# Fonctions communes aux scripts d'exploitation CHAN-98 (lot 2).
#
# Ce fichier est sourcé par backup.sh et restore.sh. Il ne doit contenir
# aucun secret et ne doit jamais être exécuté directement.

if [[ -n "${C2ME_OPS_COMMON_LOADED:-}" ]]; then
  return 0
fi
C2ME_OPS_COMMON_LOADED=1

set -Eeuo pipefail
umask 027

OPS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPS_LIB_DIR="$OPS_SCRIPT_DIR/lib"
OPS_MANIFEST_TOOL="$OPS_LIB_DIR/manifest.php"

C2ME_SUPPORTED_ENVIRONMENTS=(staging production)

# ---------------------------------------------------------------------------
# Environnements : table fixe, jamais déduite d'une variable libre.
# ---------------------------------------------------------------------------

c2me_env_root() {
  case "$1" in
    staging) printf '%s\n' '/www/wwwroot/chantier-staging.c2me.ovh' ;;
    production) printf '%s\n' '/www/wwwroot/chantier.c2me.fr' ;;
    *) return 1 ;;
  esac
}

c2me_env_database() {
  case "$1" in
    staging) printf '%s\n' 'chantier_staging' ;;
    production) printf '%s\n' 'chantier_production' ;;
    *) return 1 ;;
  esac
}

c2me_env_group() {
  case "$1" in
    staging) printf '%s\n' 'c2me-staging' ;;
    production) printf '%s\n' 'c2me-production' ;;
    *) return 1 ;;
  esac
}

c2me_env_url() {
  case "$1" in
    staging) printf '%s\n' 'https://chantier-staging.c2me.ovh' ;;
    production) printf '%s\n' 'https://chantier.c2me.fr' ;;
    *) return 1 ;;
  esac
}

c2me_env_backup_root() {
  case "$1" in
    staging | production) printf '%s\n' "/var/backups/c2me/$1" ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Journalisation
# ---------------------------------------------------------------------------

c2me_json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' \
    | tr -d '\r\n'
}

c2me_iso_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

c2me_iso_compact() {
  date -u '+%Y%m%dT%H%M%SZ'
}

c2me_random_hex8() {
  if command -v od >/dev/null 2>&1 && [[ -r /dev/urandom ]]; then
    od -An -tx1 -N4 /dev/urandom | tr -d ' \n'
  else
    printf '%08x' "${RANDOM:-0}"
  fi
}

c2me_log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(c2me_iso_now)"

  printf '[%s] %s: %s\n' "$timestamp" "$level" "$message" >&2

  if [[ -n "${C2ME_BACKUP_ROOT:-}" && -d "${C2ME_BACKUP_ROOT:-}" && -w "${C2ME_BACKUP_ROOT:-}" ]]; then
    printf '{"timestamp":"%s","level":"%s","environment":"%s","event":"%s","message":"%s","pid":%d}\n' \
      "$timestamp" \
      "$(c2me_json_escape "$level")" \
      "$(c2me_json_escape "${C2ME_ENV:-unknown}")" \
      "$(c2me_json_escape "${C2ME_EVENT:-ops}")" \
      "$(c2me_json_escape "$message")" \
      "$$" >>"$C2ME_BACKUP_ROOT/ops.log" 2>/dev/null || true
  fi
}

c2me_info() {
  c2me_log info "$@"
}

c2me_warn() {
  c2me_log warning "$@"
}

c2me_die() {
  c2me_log error "$@"
  exit 1
}

# ---------------------------------------------------------------------------
# Nettoyage et verrou
# ---------------------------------------------------------------------------

C2ME_CLEANUP_PATHS=()

c2me_register_cleanup() {
  C2ME_CLEANUP_PATHS+=("$1")
}

C2ME_CLEANUP_DONE=0
C2ME_LOCK_TOKEN=""
C2ME_LOCK_INODE=""
C2ME_LOCK_OWNED=0
C2ME_GUARD_FD=""

# ---------------------------------------------------------------------------
# Garde de sérialisation des mutations de verrou (Linux : flock sur répertoire)
#
# Le garde est un répertoire persistant `<verrou>.guard`. Il est créé par mkdir,
# ouvert en lecture, puis son descripteur est vérifié (chemin résolu, type,
# inode) avant et après flock. Une ouverture qui suivrait un lien symbolique ou
# un remplacement est détectée et refusée. Le garde n'est jamais supprimé.
# ---------------------------------------------------------------------------

c2me_guard_validate_fd() {
  local guard="$1"
  local fd="$2"

  [[ -n "$fd" && -e "/proc/self/fd/$fd" ]] || return 1
  [[ -d "$guard" && ! -L "$guard" ]] || return 1

  local fd_path path_real fd_inode path_inode
  fd_path="$(readlink -f "/proc/self/fd/$fd" 2>/dev/null || true)"
  path_real="$(readlink -f "$guard" 2>/dev/null || true)"

  [[ -n "$fd_path" && -n "$path_real" && "$fd_path" == "$path_real" ]] || return 1

  fd_inode="$(stat -Lc '%d:%i' "/proc/self/fd/$fd" 2>/dev/null || true)"
  path_inode="$(stat -c '%d:%i' "$guard" 2>/dev/null || true)"

  [[ -n "$fd_inode" && "$fd_inode" == "$path_inode" ]]
}

c2me_guard_enter() {
  local lock_dir="$1"
  local guard="${lock_dir}.guard"
  local timeout="${C2ME_LOCK_GUARD_TIMEOUT:-30}"
  local flock_bin="${C2ME_FLOCK_BIN:-$(command -v flock || true)}"

  if [[ -z "$flock_bin" || ! -x "$flock_bin" ]]; then
    if [[ "${C2ME_ALLOW_MISSING_FLOCK:-0}" -eq 1 ]]; then
      case "${C2ME_ENV:-}" in
        production)
          C2ME_GUARD_FD=""
          c2me_die 'flock est requis en production : le contournement C2ME_ALLOW_MISSING_FLOCK est interdit.'
          ;;
        '')
          C2ME_GUARD_FD=""
          c2me_die 'flock absent et C2ME_ENV non déterminé : contournement de test refusé.'
          ;;
        *)
          C2ME_GUARD_FD=""
          c2me_warn 'mode de test explicite : flock absent, garde de verrou non appliqué.'

          return 0
          ;;
      esac
    fi

    C2ME_GUARD_FD=""
    c2me_die 'flock est requis pour sérialiser les mutations de verrou : opération refusée.'
  fi

  if [[ -L "$guard" ]]; then
    c2me_die "fichier de garde symbolique interdit : $guard"
  fi

  if [[ ! -e "$guard" ]]; then
    if ! mkdir -- "$guard" 2>/dev/null; then
      c2me_die "création du garde de verrou impossible : $guard"
    fi

    c2me_chmod 0700 -- "$guard" || {
      c2me_die "permissions du garde de verrou non appliquées : $guard"
    }
  fi

  if [[ -L "$guard" || ! -d "$guard" ]]; then
    c2me_die "fichier de garde non régulier (répertoire attendu) : $guard"
  fi

  if ! exec {C2ME_GUARD_FD}<"$guard"; then
    C2ME_GUARD_FD=""
    c2me_die "ouverture du garde de verrou impossible : $guard"
  fi

  if ! c2me_guard_validate_fd "$guard" "$C2ME_GUARD_FD"; then
    exec {C2ME_GUARD_FD}>&-
    C2ME_GUARD_FD=""
    c2me_die "garde de verrou remplacé ou incohérent à l ouverture : $guard"
  fi

  if ! "$flock_bin" -x -w "$timeout" "$C2ME_GUARD_FD"; then
    exec {C2ME_GUARD_FD}>&-
    C2ME_GUARD_FD=""
    c2me_die "garde de verrou indisponible après ${timeout}s : opération refusée."
  fi

  if ! c2me_guard_validate_fd "$guard" "$C2ME_GUARD_FD"; then
    "$flock_bin" -u "$C2ME_GUARD_FD" 2>/dev/null || true
    exec {C2ME_GUARD_FD}>&-
    C2ME_GUARD_FD=""
    c2me_die "garde de verrou remplacé après ouverture : opération refusée."
  fi
}

c2me_guard_exit() {
  [[ -n "${C2ME_GUARD_FD:-}" ]] || return 0

  flock -u "$C2ME_GUARD_FD" 2>/dev/null || true
  exec {C2ME_GUARD_FD}>&-
  C2ME_GUARD_FD=""
}

c2me_lock_inode() {
  local path="$1"

  stat -c '%d:%i' -- "$path" 2>/dev/null || return 1
}

# Écrit les métadonnées obligatoires du verrou et vérifie leur relecture.
# Toute erreur est fatale pour l'acquisition.
c2me_lock_write_metadata() {
  local lock_dir="$1"
  local token="$2"
  local pid="$3"
  local host="$4"
  local started_at="$5"

  printf '%s\n' "$pid" >"$lock_dir/pid" || return 1
  printf '%s\n' "$host" >"$lock_dir/host" || return 1
  printf '%s\n' "$started_at" >"$lock_dir/started_at" || return 1
  printf '%s\n' "$token" >"$lock_dir/token" || return 1

  c2me_chmod 0600 -- "$lock_dir/token" || return 1
  c2me_chmod 0640 -- "$lock_dir/pid" "$lock_dir/started_at" "$lock_dir/host" || return 1

  [[ "$(cat "$lock_dir/token" 2>/dev/null || true)" == "$token" ]] || return 1
  [[ "$(cat "$lock_dir/pid" 2>/dev/null || true)" == "$pid" ]] || return 1
  [[ "$(cat "$lock_dir/host" 2>/dev/null || true)" == "$host" ]] || return 1
  [[ "$(cat "$lock_dir/started_at" 2>/dev/null || true)" == "$started_at" ]] || return 1

  return 0
}

# Supprime un verrou partiellement créé uniquement si son inode et son jeton
# correspondent encore à ceux de l'exécution courante. Appelé sous garde.
c2me_remove_lock_if_owned() {
  local lock_dir="$1"
  local token="$2"
  local inode="$3"

  [[ -L "$lock_dir" || ! -d "$lock_dir" ]] && return 0
  [[ -n "$inode" && "$(c2me_lock_inode "$lock_dir" || true)" == "$inode" ]] || return 0

  local recorded=""
  recorded="$(cat "$lock_dir/token" 2>/dev/null || true)"
  [[ -n "$token" && "$recorded" == "$token" ]] || return 0

  rm -rf -- "$lock_dir" 2>/dev/null || true
}

c2me_cleanup() {
  if ((C2ME_CLEANUP_DONE == 1)); then
    return 0
  fi

  C2ME_CLEANUP_DONE=1
  local path
  set +e

  for path in "${C2ME_CLEANUP_PATHS[@]:-}"; do
    if [[ -n "$path" && -e "$path" ]]; then
      local attempt=0

      while [[ -e "$path" && attempt -lt 20 ]]; do
        rm -rf -- "$path" 2>/dev/null || true
        attempt=$((attempt + 1))

        if [[ -e "$path" ]]; then
          sleep 0.25
        fi
      done
    fi
  done

  if [[ -n "${C2ME_LOCK_DIR:-}" && -d "${C2ME_LOCK_DIR:-}" ]]; then
    c2me_release_lock
  fi

  return 0
}

C2ME_CHILD_PIDS=()

c2me_track_child() {
  C2ME_CHILD_PIDS+=("$1")
}

c2me_untrack_child() {
  local target="$1"
  local pid
  local remaining=()

  for pid in "${C2ME_CHILD_PIDS[@]:-}"; do
    if [[ -n "$pid" && "$pid" != "$target" ]]; then
      remaining+=("$pid")
    fi
  done

  C2ME_CHILD_PIDS=()

  if ((${#remaining[@]} > 0)); then
    C2ME_CHILD_PIDS=("${remaining[@]}")
  fi
}

c2me_child_pids_of() {
  local parent="$1"

  if command -v pgrep >/dev/null 2>&1; then
    pgrep -P "$parent" 2>/dev/null || true

    return 0
  fi

  if command -v ps >/dev/null 2>&1 && ps -eo pid=,ppid= >/dev/null 2>&1; then
    ps -eo pid=,ppid= 2>/dev/null | awk -v parent="$parent" '$2 == parent {print $1}' || true

    return 0
  fi

  # Repli sans ps ni pgrep : lecture directe de /proc sur Linux.
  if [[ -d /proc ]]; then
    local status_file pid ppid

    for status_file in /proc/[0-9]*/status; do
      [[ -r "$status_file" ]] || continue
      pid="${status_file#/proc/}"
      pid="${pid%/status}"
      ppid="$(awk '/^PPid:/ {print $2; exit}' "$status_file" 2>/dev/null || true)"

      if [[ "$ppid" == "$parent" ]]; then
        printf '%s\n' "$pid"
      fi
    done
  fi
}

# Liste récursivement les descendants d'un PID, dans l'ordre de découverte.
# La liste des enfants est capturée avant traitement : aucune boucle ne doit
# énumérer un processus d'aide encore vivant.
c2me_descendant_pids() {
  local root="$1"
  local queue=("$root")
  local current children child

  while ((${#queue[@]} > 0)); do
    current="${queue[0]}"
    queue=("${queue[@]:1}")
    children="$(c2me_child_pids_of "$current")"

    if [[ -z "$children" ]]; then
      continue
    fi

    while IFS= read -r child; do
      [[ -n "$child" ]] || continue
      printf '%s\n' "$child"
      queue+=("$child")
    done <<<"$children"
  done
}

c2me_pid_alive() {
  local pid="$1"

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

# Termine les processus enfants critiques avant tout nettoyage. Le verrou
# n'est libéré qu'après leur disparition effective.
c2me_terminate_children() {
  local pids=()
  local listing
  local pid
  local unique=()
  local attempt alive

  listing="$(c2me_descendant_pids "$$")"

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pids+=("$pid")
  done <<<"$listing"

  for pid in "${C2ME_CHILD_PIDS[@]:-}"; do
    if [[ -n "$pid" ]]; then
      pids+=("$pid")
    fi
  done

  for pid in "${pids[@]:-}"; do
    [[ -n "$pid" ]] || continue
    if [[ " ${unique[*]:-} " != *" ${pid} "* ]]; then
      unique+=("$pid")
    fi
  done

  if ((${#unique[@]} == 0)); then
    return 0
  fi

  for pid in "${unique[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done

  for attempt in $(seq 1 50); do
    alive=0

    for pid in "${unique[@]}"; do
      if c2me_pid_alive "$pid"; then
        alive=1
      fi
    done

    if ((alive == 0)); then
      break
    fi

    sleep 0.1
  done

  for pid in "${unique[@]}"; do
    if c2me_pid_alive "$pid"; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done

  for pid in "${unique[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  C2ME_CHILD_PIDS=()
}

# Exécute une commande externe critique en suivant son PID. Le signal reçu
# pendant l'attente est traité par le gestionnaire, qui termine l'enfant.
c2me_run() {
  local pid
  local status

  "$@" <&0 &
  pid=$!
  c2me_track_child "$pid"

  if wait "$pid"; then
    status=0
  else
    status=$?
  fi

  c2me_untrack_child "$pid"

  return "$status"
}

# Gestionnaire de signal : termine les enfants, nettoie puis termine le
# processus avec un code explicite. Aucune opération ne reprend après.
c2me_on_signal() {
  local code="$1"

  trap - EXIT HUP INT TERM
  c2me_terminate_children

  # Ferme les descripteurs hérités par le shell (redirections de fonction en
  # cours) avant de supprimer la zone de travail : certains systèmes refusent
  # la suppression d'un fichier encore ouvert par le processus courant.
  exec </dev/null >/dev/null 2>&1
  c2me_cleanup
  exit "$code"
}

c2me_lock_pid_alive() {
  local pid="$1"

  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

c2me_acquire_lock() {
  local lock_dir="$1"
  local unlock_hint="${C2ME_UNLOCK_HINT:-scripts/ops/backup.sh unlock --env <env> --confirm-stale-lock}"

  if [[ -z "$C2ME_HOST_ID" ]]; then
    c2me_die "identité d'hôte non déterminable : définir un hostname stable ou C2ME_HOST_ID. Prise de verrou refusée."
  fi

  c2me_guard_enter "$lock_dir"

  if [[ -e "$lock_dir" || -L "$lock_dir" ]]; then
    if [[ -L "$lock_dir" || ! -d "$lock_dir" ]]; then
      c2me_die "verrou invalide (non répertoire ou symbolique) : $lock_dir"
    fi

    local pid started_at lock_host
    pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
    started_at="$(cat "$lock_dir/started_at" 2>/dev/null || true)"
    lock_host="$(cat "$lock_dir/host" 2>/dev/null || true)"

    if [[ -z "$lock_host" || "${lock_host,,}" == 'unknown' ]]; then
      c2me_die "verrou sans hôte fiable (absent, vide ou unknown ; pid ${pid:-inconnu}, depuis ${started_at:-date inconnue}) : suppression automatique interdite. Vérifier manuellement l'absence de processus, puis exécuter '${unlock_hint}' sur l'hôte concerné."
    fi

    if [[ "$lock_host" != "$C2ME_HOST_ID" ]]; then
      c2me_die "verrou détenu par un autre hôte ($lock_host) : un PID distant ne prouve pas qu'un processus est mort. Libération locale refusée ; résoudre le verrou sur $lock_host après vérification manuelle."
    fi

    if c2me_lock_pid_alive "$pid"; then
      c2me_die "une autre opération est déjà en cours (pid $pid, depuis ${started_at:-date inconnue}, verrou : $lock_dir)."
    fi

    c2me_die "verrou orphelin détecté (pid ${pid:-inconnu}, depuis ${started_at:-date inconnue}, hôte $lock_host) : suppression automatique interdite. Vérifier qu'aucun processus n'est actif, puis exécuter '${unlock_hint}'."
  fi

  if ! mkdir -- "$lock_dir" 2>/dev/null; then
    c2me_die "impossible de créer le verrou (course concurrente ?) : $lock_dir"
  fi

  local created_inode=""
  created_inode="$(c2me_lock_inode "$lock_dir" || true)"

  local random=""
  random="$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || true)"
  [[ -n "$random" ]] || random="$$-${RANDOM}-${RANDOM}-$(date -u '+%s')"
  local token="lock-$$-${random}"

  if ! c2me_chmod 0700 -- "$lock_dir"; then
    c2me_remove_lock_if_owned "$lock_dir" "$token" "$created_inode"
    c2me_guard_exit
    c2me_die "permissions du verrou non appliquées : $lock_dir"
  fi

  if ! c2me_lock_write_metadata "$lock_dir" "$token" "$$" "$C2ME_HOST_ID" "$(c2me_iso_now)"; then
    c2me_remove_lock_if_owned "$lock_dir" "$token" "$created_inode"
    c2me_guard_exit
    c2me_die "écriture des métadonnées du verrou impossible ou incohérente : $lock_dir"
  fi

  C2ME_LOCK_DIR="$lock_dir"
  C2ME_LOCK_TOKEN="$token"
  C2ME_LOCK_INODE="$created_inode"
  C2ME_LOCK_OWNED=1

  c2me_guard_exit
}

# Libère uniquement un verrou dont le jeton et l'inode correspondent à ceux
# créés par ce processus. La vérification et la suppression se font sous le
# garde flock : aucune opération coopérative ne peut remplacer le verrou entre
# les deux.
c2me_release_lock() {
  local lock_dir="${C2ME_LOCK_DIR:-}"

  [[ "$C2ME_LOCK_OWNED" -eq 1 && -n "$lock_dir" ]] || {
    C2ME_LOCK_OWNED=0
    C2ME_LOCK_TOKEN=""
    C2ME_LOCK_INODE=""

    return 0
  }

  c2me_guard_enter "$lock_dir"

  if [[ -L "$lock_dir" || ! -d "$lock_dir" ]]; then
    C2ME_LOCK_OWNED=0
    C2ME_LOCK_TOKEN=""
    C2ME_LOCK_INODE=""
    C2ME_LOCK_DIR=""
    c2me_guard_exit

    return 0
  fi

  local recorded=""
  local current_inode=""
  recorded="$(cat "$lock_dir/token" 2>/dev/null || true)"
  current_inode="$(c2me_lock_inode "$lock_dir" || true)"

  if [[ -n "$recorded" && "$recorded" == "$C2ME_LOCK_TOKEN" \
    && -n "$C2ME_LOCK_INODE" && "$current_inode" == "$C2ME_LOCK_INODE" ]]; then
    local attempt=0

    while [[ -d "$lock_dir" && attempt -lt 20 ]]; do
      rm -rf -- "$lock_dir" 2>/dev/null || true
      attempt=$((attempt + 1))

      if [[ -d "$lock_dir" ]]; then
        sleep 0.25
      fi
    done
  else
    printf 'AVERTISSEMENT: verrou non libéré (jeton ou identité différents) : %s\n' "$lock_dir" >&2
  fi

  C2ME_LOCK_OWNED=0
  C2ME_LOCK_TOKEN=""
  C2ME_LOCK_INODE=""
  C2ME_LOCK_DIR=""
  c2me_guard_exit
}

# Récupération explicite d'un verrou orphelin. Refuse si le PID est vivant.
# Toutes les vérifications et la suppression sont sous le garde flock.
c2me_release_stale_lock() {
  local lock_dir="$1"

  if [[ -z "$C2ME_HOST_ID" ]]; then
    c2me_die "identité d'hôte locale non déterminable : libération de verrou refusée."
  fi

  c2me_guard_enter "$lock_dir"

  if [[ -L "$lock_dir" ]]; then
    c2me_die "le verrou est un lien symbolique : libération refusée ($lock_dir)."
  fi

  if [[ ! -d "$lock_dir" ]]; then
    c2me_die "aucun verrou à libérer : $lock_dir"
  fi

  local pid started_at lock_host
  pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
  started_at="$(cat "$lock_dir/started_at" 2>/dev/null || true)"
  lock_host="$(cat "$lock_dir/host" 2>/dev/null || true)"

  if [[ -z "$lock_host" || "${lock_host,,}" == 'unknown' || "${lock_host,,}" == 'localhost' || "${lock_host,,}" == 'localhost.localdomain' ]]; then
    c2me_die "verrou sans hôte fiable (absent, vide ou réservé) : libération refusée. Vérifier manuellement l'absence de processus sur l'hôte concerné."
  fi

  if [[ "$lock_host" != "$C2ME_HOST_ID" ]]; then
    c2me_die "le verrou appartient à l'hôte $lock_host, pas à $C2ME_HOST_ID : libération locale refusée. Résoudre le verrou sur $lock_host après vérification manuelle."
  fi

  if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
    c2me_die 'pid absent ou invalide dans le verrou : libération refusée, vérification manuelle requise.'
  fi

  if [[ -z "$started_at" ]]; then
    c2me_die 'date de création absente dans le verrou : libération refusée.'
  fi

  if [[ -e "$lock_dir/token" ]]; then
    if [[ -L "$lock_dir/token" || ! -f "$lock_dir/token" || ! -r "$lock_dir/token" ]]; then
      c2me_die 'jeton de verrou non régulier ou illisible : libération refusée.'
    fi
  fi

  if c2me_lock_pid_alive "$pid"; then
    c2me_die "le verrou est actif (pid $pid depuis $started_at) : libération refusée."
  fi

  local inode_before inode_after
  inode_before="$(c2me_lock_inode "$lock_dir" || true)"
  [[ -n "$inode_before" ]] || c2me_die 'identité du verrou illisible : libération refusée.'

  # Revalidation immédiate de l'identité avant suppression : un remplacement
  # externe non coopératif est détecté même sous garde.
  inode_after="$(c2me_lock_inode "$lock_dir" || true)"
  [[ "$inode_after" == "$inode_before" ]] \
    || c2me_die 'le verrou a été remplacé pendant les contrôles : libération refusée.'

  rm -rf -- "$lock_dir"
  c2me_info "verrou orphelin libéré explicitement (pid $pid, depuis $started_at, hôte $lock_host)."

  c2me_guard_exit
}

# Applique un mode. Sur les systèmes de test non POSIX (MSYS), chmod est sans
# effet : l'échec y est toléré, jamais sur Linux.
c2me_chmod() {
  if chmod "$@" 2>/dev/null; then
    return 0
  fi

  case "$(uname -s 2>/dev/null || true)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

c2me_mkdir_mode() {
  local directory="$1"
  local mode="$2"

  mkdir -p -- "$directory" || return 1
  c2me_chmod "$mode" -- "$directory" || return 1
}

# Indique si la plateforme applique réellement les modes POSIX. Utilisé pour
# ne pas déclarer conformes des permissions qui ne peuvent pas être posées.
c2me_posix_modes_enforced() {
  local probe mode

  probe="$(mktemp 2>/dev/null)" || return 1

  if ! chmod 0600 "$probe" 2>/dev/null; then
    rm -f -- "$probe"
    return 1
  fi

  mode="$(stat -c '%a' -- "$probe" 2>/dev/null || stat -f '%Lp' -- "$probe" 2>/dev/null || printf 'unknown')"
  rm -f -- "$probe"

  [[ "$mode" == '600' ]]
}

# Indique si la plateforme applique réellement le bit setgid. Utilisé pour ne
# pas déclarer conformes des permissions qui ne peuvent pas être posées.
c2me_setgid_supported() {
  local probe
  probe="$(mktemp -d 2>/dev/null)" || return 1

  if ! chmod 2770 "$probe" 2>/dev/null; then
    rm -rf -- "$probe"
    return 1
  fi

  if [[ -n "$(find "$probe" -maxdepth 0 -perm -2000 -print 2>/dev/null)" ]]; then
    rm -rf -- "$probe"
    return 0
  fi

  rm -rf -- "$probe"
  return 1
}

# ---------------------------------------------------------------------------
# Validation des chemins
# ---------------------------------------------------------------------------

c2me_assert_absolute() {
  local path="$1"
  local label="$2"

  [[ "$path" = /* ]] || c2me_die "$label doit être un chemin absolu : $path"
  [[ "$path" != *".."* ]] || c2me_die "$label ne doit pas contenir de traversée de chemin : $path"
}

c2me_realpath() {
  local path="$1"

  if realpath -m -- "$path" >/dev/null 2>&1; then
    realpath -m -- "$path"
    return 0
  fi

  local parent base
  parent="$(dirname -- "$path")"
  base="$(basename -- "$path")"

  while [[ ! -d "$parent" && "$parent" != '/' ]]; do
    parent="$(dirname -- "$parent")"
  done

  if [[ -d "$parent" ]]; then
    (cd "$parent" && printf '%s/%s\n' "$(pwd -P)" "$base")
  else
    printf '%s\n' "$path"
  fi
}

# Refuse tout chemin situé sous une racine applicative, une release, un
# répertoire public ou la racine de sauvegarde.
c2me_assert_not_forbidden_path() {
  local candidate="$1"
  local label="$2"
  local resolved candidate_resolved resolved_root

  c2me_assert_absolute "$candidate" "$label"

  candidate_resolved="$(c2me_realpath "$candidate")"

  for resolved in \
    "${C2ME_ROOT:-}" \
    "${C2ME_ROOT:-}/releases" \
    "${C2ME_ROOT:-}/current" \
    "${C2ME_ROOT:-}/public" \
    "${C2ME_ROOT:-}/shared" \
    "${C2ME_ROOT:-}/shared/storage" \
    "${C2ME_BACKUP_ROOT:-}/sets" \
    "${C2ME_BACKUP_ROOT:-}/incoming" \
    "${C2ME_BACKUP_ROOT:-}/expired" \
    "${C2ME_BACKUP_ROOT:-}/ledger"; do
    [[ -n "$resolved" ]] || continue
    resolved_root="$(c2me_realpath "$resolved")"
    [[ -n "$resolved_root" ]] || resolved_root="$resolved"

    if [[ "$candidate_resolved" == "$resolved_root" || "$candidate_resolved" == "$resolved_root"/* ]]; then
      c2me_die "$label est interdite : $candidate (sous $resolved_root)."
    fi
  done

  case "$candidate_resolved" in
    /www/wwwroot | /www/wwwroot/*)
      c2me_die "$label est interdite : $candidate (racine web)."
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Résolution de l'environnement
# ---------------------------------------------------------------------------

c2me_resolve_environment() {
  local environment="$1"

  [[ -n "$environment" ]] || c2me_die "l'environnement est obligatoire (staging ou production)."

  case "$environment" in
    staging | production) ;;
    *) c2me_die "environnement non autorisé : $environment" ;;
  esac

  C2ME_ENV="$environment"

  local expected_root expected_db expected_group expected_backup_root
  expected_root="$(c2me_env_root "$environment")"
  expected_db="$(c2me_env_database "$environment")"
  expected_group="$(c2me_env_group "$environment")"
  expected_backup_root="$(c2me_env_backup_root "$environment")"

  C2ME_ROOT="${C2ME_ROOT:-$expected_root}"
  C2ME_DB_NAME="${C2ME_DB_NAME:-$expected_db}"
  C2ME_GROUP="${C2ME_GROUP:-$expected_group}"
  C2ME_BACKUP_ROOT="${C2ME_BACKUP_ROOT:-$expected_backup_root}"

  c2me_assert_absolute "$C2ME_ROOT" 'C2ME_ROOT'
  c2me_assert_absolute "$C2ME_BACKUP_ROOT" 'C2ME_BACKUP_ROOT'

  [[ "$(basename "$C2ME_ROOT")" == "$(basename "$expected_root")" ]] \
    || c2me_die "C2ME_ROOT ne correspond pas à l'environnement $environment (attendu : $expected_root)."

  [[ "$C2ME_DB_NAME" == "$expected_db" ]] \
    || c2me_die "C2ME_DB_NAME ne correspond pas à l'environnement $environment (attendu : $expected_db)."

  [[ "$C2ME_GROUP" == "$expected_group" ]] \
    || c2me_die "C2ME_GROUP ne correspond pas à l'environnement $environment (attendu : $expected_group)."

  if [[ "$C2ME_BACKUP_ROOT" == "$C2ME_ROOT" || "$C2ME_BACKUP_ROOT" == "$C2ME_ROOT"/* ]]; then
    c2me_die "C2ME_BACKUP_ROOT doit être hors de la racine applicative."
  fi

  if [[ "$C2ME_BACKUP_ROOT" == /www/wwwroot || "$C2ME_BACKUP_ROOT" == /www/wwwroot/* ]]; then
    c2me_die "C2ME_BACKUP_ROOT ne doit pas être une racine web."
  fi

  C2ME_STORAGE_ROOT="$C2ME_ROOT/shared/storage"
  C2ME_MAINTENANCE_MARKER="$C2ME_STORAGE_ROOT/framework/down"
  C2ME_RELEASE_FILE="$C2ME_ROOT/current/release.json"
  C2ME_OPERATOR="${C2ME_OPERATOR:-${USER:-unknown}}"
  local detected_host host_source
  detected_host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"

  if [[ -n "${C2ME_HOST_ID+x}" ]]; then
    host_source="$C2ME_HOST_ID"
  else
    host_source="$detected_host"
  fi

  C2ME_OPERATOR="$(printf '%s' "$C2ME_OPERATOR" | tr -cd 'A-Za-z0-9._-')"
  C2ME_HOST_ID="$(printf '%s' "$host_source" | tr -cd 'A-Za-z0-9._-')"
  [[ -n "$C2ME_OPERATOR" ]] || C2ME_OPERATOR='unknown'

  # Une identité d'hôte inconnue ou réservée n'est jamais fiable : le verrou
  # est refusé plutôt que rattaché à un hôte ambigu. Une valeur explicitement
  # invalide n'est jamais remplacée par l'identité détectée.
  case "${C2ME_HOST_ID,,}" in
    '' | 'unknown' | 'localhost' | 'localhost.localdomain')
      C2ME_HOST_ID=''
      ;;
  esac

  C2ME_PHP_BIN="${C2ME_PHP_BIN:-$(command -v php || true)}"
  C2ME_MYSQL_BIN="${C2ME_MYSQL_BIN:-$(command -v mariadb || command -v mysql || true)}"
  C2ME_DB_DUMP_BIN="${C2ME_DB_DUMP_BIN:-$(command -v mariadb-dump || command -v mysqldump || true)}"
  C2ME_AGE_BIN="${C2ME_AGE_BIN:-$(command -v age || true)}"
  C2ME_TAR_BIN="${C2ME_TAR_BIN:-$(command -v tar || true)}"
  C2ME_ZSTD_BIN="${C2ME_ZSTD_BIN:-$(command -v zstd || true)}"
  C2ME_GZIP_BIN="${C2ME_GZIP_BIN:-$(command -v gzip || true)}"
  C2ME_SUPERVISORCTL_BIN="${C2ME_SUPERVISORCTL_BIN:-$(command -v supervisorctl || true)}"

  C2ME_RETENTION_DAILY_DAYS="${C2ME_RETENTION_DAILY_DAYS:-30}"
  C2ME_RETENTION_MONTHLY_DAYS="${C2ME_RETENTION_MONTHLY_DAYS:-365}"
  C2ME_QUARANTINE_DAYS="${C2ME_QUARANTINE_DAYS:-7}"

  export C2ME_ENV C2ME_ROOT C2ME_DB_NAME C2ME_GROUP C2ME_BACKUP_ROOT C2ME_STORAGE_ROOT
}

c2me_require_file() {
  local path="$1"
  local label="$2"

  [[ -f "$path" ]] || c2me_die "$label introuvable : $path"
}

c2me_require_dir() {
  local path="$1"
  local label="$2"

  [[ -d "$path" ]] || c2me_die "$label introuvable : $path"
}

c2me_require_command() {
  local path="$1"
  local label="$2"

  [[ -n "$path" && -x "$path" ]] || c2me_die "$label absent ou non exécutable : ${path:-<vide>}"
}

c2me_sha256() {
  local path="$1"

  sha256sum -- "$path" | awk '{print $1}'
}

c2me_file_bytes() {
  local path="$1"

  wc -c <"$path" | tr -d ' '
}

c2me_available_kb() {
  local path="$1"

  df -Pk -- "$path" | awk 'NR==2 {print $4}'
}

c2me_require_free_space() {
  local path="$1"
  local required_kb="$2"
  local available_kb

  available_kb="$(c2me_available_kb "$path")"
  [[ -n "$available_kb" ]] || c2me_die "impossible de mesurer l'espace disque de $path."

  if ((available_kb < required_kb)); then
    c2me_die "espace disque insuffisant : ${available_kb} Ko disponibles, ${required_kb} Ko requis."
  fi
}

# ---------------------------------------------------------------------------
# Outils externes
# ---------------------------------------------------------------------------

c2me_select_compressor() {
  local requested="${C2ME_COMPRESSION:-auto}"

  case "$requested" in
    zstd)
      c2me_require_command "$C2ME_ZSTD_BIN" 'zstd'
      C2ME_COMPRESSION_TOOL='zstd'
      C2ME_COMPRESSION_EXT='zst'
      ;;
    gzip)
      c2me_require_command "$C2ME_GZIP_BIN" 'gzip'
      C2ME_COMPRESSION_TOOL='gzip'
      C2ME_COMPRESSION_EXT='gz'
      ;;
    auto)
      if [[ -n "$C2ME_ZSTD_BIN" && -x "$C2ME_ZSTD_BIN" ]]; then
        C2ME_COMPRESSION_TOOL='zstd'
        C2ME_COMPRESSION_EXT='zst'
      elif [[ -n "$C2ME_GZIP_BIN" && -x "$C2ME_GZIP_BIN" ]]; then
        C2ME_COMPRESSION_TOOL='gzip'
        C2ME_COMPRESSION_EXT='gz'
      else
        c2me_die 'aucun outil de compression disponible (zstd ou gzip).'
      fi
      ;;
    *)
      c2me_die "C2ME_COMPRESSION invalide : $requested"
      ;;
  esac
}

c2me_compress() {
  local source="$1"
  local destination="$2"

  if [[ "$C2ME_COMPRESSION_TOOL" == 'zstd' ]]; then
    c2me_run "$C2ME_ZSTD_BIN" -q -T0 -10 -o "$destination" -- "$source"
  else
    c2me_run "$C2ME_GZIP_BIN" -9 -c -- "$source" >"$destination"
  fi
}

c2me_test_compression() {
  local path="$1"

  if [[ "$C2ME_COMPRESSION_TOOL" == 'zstd' ]]; then
    c2me_run "$C2ME_ZSTD_BIN" -q -t -- "$path"
  else
    c2me_run "$C2ME_GZIP_BIN" -t -- "$path" 2>/dev/null
  fi
}

c2me_decompress() {
  local source="$1"
  local destination="$2"
  local tool="$3"

  case "$tool" in
    zstd)
      c2me_require_command "$C2ME_ZSTD_BIN" 'zstd'

      if ! c2me_run "$C2ME_ZSTD_BIN" -d -q -o "$destination" -- "$source"; then
        c2me_die "échec de la décompression zstd de $source."
      fi
      ;;
    gzip)
      c2me_require_command "$C2ME_GZIP_BIN" 'gzip'

      if ! c2me_run "$C2ME_GZIP_BIN" -d -c -- "$source" >"$destination"; then
        c2me_die "échec de la décompression gzip de $source."
      fi
      ;;
    *)
      c2me_die "outil de compression inconnu : $tool"
      ;;
  esac

  [[ -s "$destination" ]] || c2me_die "le fichier décompressé est vide : $destination"
}

c2me_age_encrypt() {
  local source="$1"
  local destination="$2"
  local recipient_file="$3"

  c2me_require_command "$C2ME_AGE_BIN" 'age'
  c2me_require_file "$recipient_file" 'fichier destinataire age'

  if ! c2me_run "$C2ME_AGE_BIN" --encrypt --recipients-file "$recipient_file" --output "$destination" -- "$source"; then
    c2me_die "échec du chiffrement age de $source."
  fi

  [[ -s "$destination" ]] || c2me_die "l'artefact chiffré est vide : $destination"
}

c2me_age_decrypt() {
  local source="$1"
  local destination="$2"
  local identity_file="$3"

  c2me_require_command "$C2ME_AGE_BIN" 'age'
  c2me_require_file "$identity_file" 'clé privée age'

  if ! c2me_run "$C2ME_AGE_BIN" --decrypt --identity "$identity_file" --output "$destination" -- "$source"; then
    c2me_die "échec du déchiffrement de $source."
  fi

  [[ -s "$destination" ]] || c2me_die "le fichier déchiffré est vide : $destination"
}

c2me_age_recipient() {
  local recipient_file="$1"

  c2me_require_file "$recipient_file" 'fichier destinataire age'
  head -n 1 "$recipient_file" | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Manifeste
# ---------------------------------------------------------------------------

c2me_manifest_validate() {
  local manifest="$1"

  "$C2ME_PHP_BIN" "$OPS_MANIFEST_TOOL" validate "$manifest"
}

c2me_manifest_summary() {
  local manifest="$1"
  local key="$2"

  "$C2ME_PHP_BIN" "$OPS_MANIFEST_TOOL" summary "$manifest" "$key"
}

c2me_release_value() {
  local key="$1"
  local fallback="$2"

  if [[ ! -f "$C2ME_RELEASE_FILE" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  local value
  value="$(sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$C2ME_RELEASE_FILE" | head -n 1)"

  if [[ -z "$value" ]]; then
    printf '%s\n' "$fallback"
  else
    printf '%s\n' "$value"
  fi
}
