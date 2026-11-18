#!/usr/bin/env bash
#
# Harnais de simulation CHAN-99 (Lot 6).
#
# Ce fichier est sourcé par run-hotfix-simulation.sh. Il fournit :
# - la journalisation et les assertions ;
# - l'enregistrement PASS / FAIL / NOT RUN par étape et par scénario ;
# - la génération du rapport de simulation.
#
# Aucune fonction de ce fichier n'accède à un dépôt distant réel, à GitHub ou
# à la production. Toutes les opérations sont confinées à SIM_OUT.

set -uo pipefail

SIM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_PROJECT_ROOT="$(cd "$SIM_SCRIPT_DIR/../../.." && pwd)"

SIM_OUT="${SIM_OUT:-}"
SIM_REPO=""
SIM_PASS=0
SIM_FAIL=0
SIM_CHECKS_TOTAL=0
SIM_STEP_CHECKS=0
SIM_CURRENT_STEP=""
SIM_CURRENT_TITLE=""
SIM_STEP_FAILED=0
SIM_LAST_OUTPUT=""
SIM_LAST_STATUS=0
SIM_TMP_PORTS=""
SIM_TMP_SERVERS=""

sim_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

sim_log() {
  printf '[%s] %s\n' "$(date -u '+%H:%M:%S')" "$*"
}

sim_section() {
  printf '\n================================================================\n'
  printf '%s\n' "$*"
  printf '================================================================\n'
}

sim_init_output() {
  local output="$1"

  [[ -n "$output" ]] || {
    printf 'ERREUR: répertoire de sortie vide.\n' >&2
    exit 64
  }

  SIM_OUT="$output"

  if [[ -e "$SIM_OUT" && ! -d "$SIM_OUT" ]]; then
    printf 'ERREUR: le chemin de sortie existe et n’est pas un répertoire : %s\n' "$SIM_OUT" >&2
    exit 64
  fi

  mkdir -p \
    "$SIM_OUT/evidence" \
    "$SIM_OUT/state" \
    "$SIM_OUT/log" \
    "$SIM_OUT/report" \
    "$SIM_OUT/tmp"

  : >"$SIM_OUT/report/results.tsv"
  : >"$SIM_OUT/log/checks.log"
  : >"$SIM_OUT/log/commands.log"

  printf 'started_at\t%s\n' "$(sim_timestamp)" >"$SIM_OUT/report/run-meta.tsv"
  printf 'project_root\t%s\n' "$SIM_PROJECT_ROOT" >>"$SIM_OUT/report/run-meta.tsv"
  printf 'uname\t%s\n' "$(uname -a)" >>"$SIM_OUT/report/run-meta.tsv"
  printf 'bash\t%s\n' "$(bash --version | head -n 1)" >>"$SIM_OUT/report/run-meta.tsv"
  printf 'git\t%s\n' "$(git --version)" >>"$SIM_OUT/report/run-meta.tsv"
  printf 'php\t%s\n' "$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo indisponible)" >>"$SIM_OUT/report/run-meta.tsv"
  printf 'tar\t%s\n' "$(tar --version 2>/dev/null | head -n 1 || echo indisponible)" >>"$SIM_OUT/report/run-meta.tsv"
  printf 'sha256sum\t%s\n' "$(sha256sum --version 2>/dev/null | head -n 1 || echo indisponible)" >>"$SIM_OUT/report/run-meta.tsv"
}

sim_token() {
  printf '%s' "${1//[^A-Za-z0-9_.-]/_}"
}

sim_evidence_dir() {
  local dir="$SIM_OUT/evidence/$(sim_token "${1:-misc}")"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

sim_escape_tsv() {
  local value="${1:-}"
  value="${value//$'\t'/ }"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  printf '%s' "$value"
}

sim_record() {
  local id="$1"
  local title="$2"
  local status="$3"
  local detail="$4"

  printf '%s\t%s\t%s\t%s\n' \
    "$(sim_escape_tsv "$id")" \
    "$(sim_escape_tsv "$title")" \
    "$(sim_escape_tsv "$status")" \
    "$(sim_escape_tsv "$detail")" >>"$SIM_OUT/report/results.tsv"

  case "$status" in
    PASS) SIM_PASS=$((SIM_PASS + 1)) ;;
    FAIL) SIM_FAIL=$((SIM_FAIL + 1)) ;;
  esac

  printf '%-4s %-72s %s\n' "$status" "$title" "$detail"
}

sim_step_begin() {
  SIM_CURRENT_STEP="$1"
  SIM_CURRENT_TITLE="$2"
  SIM_STEP_FAILED=0
  SIM_STEP_CHECKS=0
  sim_section "$SIM_CURRENT_STEP — $SIM_CURRENT_TITLE"
}

sim_step_end() {
  local detail="${1:-$SIM_STEP_CHECKS contrôle(s)}"
  local status="PASS"

  if ((SIM_STEP_FAILED != 0)); then
    status="FAIL"
  fi

  # Les étapes « Sxx » enregistrent elles-mêmes leur scénario ; éviter une
  # ligne de synthèse en double dans le rapport.
  if [[ "$SIM_CURRENT_STEP" != S* ]]; then
    sim_record "$SIM_CURRENT_STEP" "$SIM_CURRENT_TITLE" "$status" "$detail"
  fi

  SIM_CURRENT_STEP=""
  SIM_CURRENT_TITLE=""
}

sim_step_record_current() {
  local id="$1"
  local title="$2"
  local detail="${3:-$SIM_STEP_CHECKS contrôle(s)}"
  local status="PASS"

  if ((SIM_STEP_FAILED != 0)); then
    status="FAIL"
  fi

  sim_record "$id" "$title" "$status" "$detail"
}

sim_not_run() {
  local id="$1"
  local title="$2"
  local reason="$3"

  sim_record "$id" "$title" "NOT RUN" "$reason"
}

sim_check_ok() {
  local label="$1"
  shift
  local output status

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  output="$("$@" 2>&1)"
  status=$?

  SIM_LAST_OUTPUT="$output"
  SIM_LAST_STATUS=$status

  printf 'CHECK %s\n' "$label" >>"$SIM_OUT/log/checks.log"
  printf 'CMD   %s\n' "$*" >>"$SIM_OUT/log/checks.log"
  printf 'EXIT  %s\n' "$status" >>"$SIM_OUT/log/checks.log"
  printf '%s\n---\n' "$output" >>"$SIM_OUT/log/checks.log"

  if ((status == 0)); then
    sim_log "OK   $label"
    return 0
  fi

  SIM_STEP_FAILED=1
  sim_log "FAIL $label (code $status)"
  printf '%s\n' "$output" | sed 's/^/     /' >&2
  return 1
}

sim_check_fail() {
  local label="$1"
  local expected_pattern="$2"
  shift 2

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  local output status
  output="$("$@" 2>&1)"
  status=$?
  SIM_LAST_OUTPUT="$output"
  SIM_LAST_STATUS=$status

  printf 'CHECK(fail attendu) %s\n' "$label" >>"$SIM_OUT/log/checks.log"
  printf 'CMD   %s\n' "$*" >>"$SIM_OUT/log/checks.log"
  printf 'EXIT  %s\n' "$status" >>"$SIM_OUT/log/checks.log"
  printf '%s\n---\n' "$output" >>"$SIM_OUT/log/checks.log"

  if ((status == 0)); then
    SIM_STEP_FAILED=1
    sim_log "FAIL $label : la commande a réussi alors qu’un refus était attendu"
    return 1
  fi

  if [[ -n "$expected_pattern" ]] && ! printf '%s' "$output" | grep -Fq -- "$expected_pattern"; then
    SIM_STEP_FAILED=1
    sim_log "FAIL $label : refus obtenu mais message inattendu (attendu : $expected_pattern)"
    printf '%s\n' "$output" | sed 's/^/     /' >&2
    return 1
  fi

  sim_log "OK   $label (refus attendu, code $status)"
  return 0
}

sim_assert() {
  local label="$1"
  shift

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  if "$@"; then
    sim_log "OK   $label"
    return 0
  fi

  SIM_STEP_FAILED=1
  sim_log "FAIL $label"
  return 1
}

sim_assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  if [[ "$expected" == "$actual" ]]; then
    sim_log "OK   $label"
    return 0
  fi

  SIM_STEP_FAILED=1
  sim_log "FAIL $label : attendu '$expected', obtenu '$actual'"
  return 1
}

sim_assert_ne() {
  local label="$1"
  local unexpected="$2"
  local actual="$3"

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  if [[ "$unexpected" != "$actual" ]]; then
    sim_log "OK   $label"
    return 0
  fi

  SIM_STEP_FAILED=1
  sim_log "FAIL $label : valeur interdite '$unexpected'"
  return 1
}

sim_assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    sim_log "OK   $label"
    return 0
  fi

  SIM_STEP_FAILED=1
  sim_log "FAIL $label : '$needle' absent"
  return 1
}

sim_assert_file() {
  local label="$1"
  local path="$2"

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  if [[ -f "$path" && -r "$path" ]]; then
    sim_log "OK   $label"
    return 0
  fi

  SIM_STEP_FAILED=1
  sim_log "FAIL $label : fichier absent ou illisible $path"
  return 1
}

sim_assert_no_file() {
  local label="$1"
  local path="$2"

  SIM_STEP_CHECKS=$((SIM_STEP_CHECKS + 1))
  SIM_CHECKS_TOTAL=$((SIM_CHECKS_TOTAL + 1))

  if [[ ! -e "$path" ]]; then
    sim_log "OK   $label"
    return 0
  fi

  SIM_STEP_FAILED=1
  sim_log "FAIL $label : fichier inattendu $path"
  return 1
}

sim_save() {
  local file="$1"
  shift

  "$@" >"$file" 2>&1 || true
  printf '%s\n' "$file"
}

sim_sha256() {
  sha256sum "$1" | awk '{print $1}'
}

sim_free_port() {
  local port

  for port in $(seq 18120 18190); do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      printf '%s\n' "$port"
      return 0
    fi
    exec 3>&- 2>/dev/null || true
  done

  return 1
}

sim_start_health_server() {
  local document_root="$1"
  local port
  local log_file="$SIM_OUT/log/health-server.log"

  port="$(sim_free_port)" || return 1

  php -S "127.0.0.1:${port}" -t "$document_root" "$document_root/index.php" \
    >>"$log_file" 2>&1 &
  local pid=$!

  SIM_TMP_SERVERS="$SIM_TMP_SERVERS $pid"
  printf '%s %s\n' "$pid" "$port"
}

sim_stop_health_server() {
  local pid="$1"

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

sim_http_get() {
  local port="$1"
  local path="$2"

  php -r '
    $port = (int) $argv[1];
    $path = $argv[2];
    $body = @file_get_contents("http://127.0.0.1:{$port}{$path}");
    $status = isset($http_response_header[0]) ? $http_response_header[0] : "";
    if ($body === false) {
        fwrite(STDERR, "connexion impossible : {$status}\n");
        exit(1);
    }
    fwrite(STDOUT, $body);
    if (strpos($status, "200") === false) {
        fwrite(STDERR, "statut HTTP inattendu : {$status}\n");
        exit(2);
    }
  ' "$port" "$path" 2>&1
}

sim_cleanup() {
  local pid

  for pid in $SIM_TMP_SERVERS; do
    kill "$pid" 2>/dev/null || true
  done

  SIM_TMP_SERVERS=""
}

sim_write_report() {
  local report="$SIM_OUT/report/simulation-report.md"
  local generated
  generated="$(sim_timestamp)"

  {
    printf '# Rapport de simulation — CHAN-99 Lot 6\n\n'
    printf -- '- Généré : `%s`\n' "$generated"
    printf -- '- Répertoire de preuves : `%s`\n' "$SIM_OUT"
    printf -- '- Portée : simulation locale isolée, aucun dépôt distant réel, aucune production.\n\n'

    printf '## Environnement\n\n'
    printf '```text\n'
    cat "$SIM_OUT/report/run-meta.tsv"
    printf '```\n\n'

    printf '## Résultats\n\n'
    printf '| Étape | Résultat | Détail |\n'
    printf '| --- | --- | --- |\n'
    while IFS=$'\t' read -r id title status detail; do
      printf '| %s — %s | **%s** | %s |\n' "$id" "$title" "$status" "$detail"
    done <"$SIM_OUT/report/results.tsv"

    printf '\n## Compteurs\n\n'
    printf -- '- PASS : %d\n' "$SIM_PASS"
    printf -- '- FAIL : %d\n' "$SIM_FAIL"
    printf -- '- NOT RUN : %d\n' "$(awk -F '\t' '$3 == "NOT RUN" {count++} END {print count + 0}' "$SIM_OUT/report/results.tsv")"
    printf -- '- Contrôles élémentaires exécutés : %d\n\n' "$SIM_CHECKS_TOTAL"

    printf '## Sécurité de la simulation\n\n'
    printf -- '- Remote Git : `%s` (dépôt bare local uniquement).\n' "${SIM_REMOTE_PATH:-non initialisé}"
    printf -- '- Aucun appel réseau sortant vers GitHub.\n'
    printf -- '- Aucun accès au serveur de production.\n'
    printf -- '- Toutes les écritures sont confinées à `%s`.\n\n' "$SIM_OUT"

    printf '## Traçabilité Git\n\n'
    if [[ -f "$SIM_OUT/evidence/git/final-graph.txt" ]]; then
      printf '```text\n'
      cat "$SIM_OUT/evidence/git/final-graph.txt"
      printf '```\n'
    else
      printf '_Graphe final non disponible._\n'
    fi
  } >"$report"

  {
    printf '{\n'
    printf '  "generated_at": "%s",\n' "$generated"
    printf '  "output": "%s",\n' "$SIM_OUT"
    printf '  "pass": %d,\n' "$SIM_PASS"
    printf '  "fail": %d,\n' "$SIM_FAIL"
    printf '  "results": [\n'
    local first=1
    while IFS=$'\t' read -r id title status detail; do
      if ((first == 0)); then printf ',\n'; fi
      first=0
      printf '    {"id": "%s", "title": "%s", "status": "%s", "detail": "%s"}' \
        "${id//\"/\\\"}" "${title//\"/\\\"}" "$status" "${detail//\"/\\\"}"
    done <"$SIM_OUT/report/results.tsv"
    printf '\n  ]\n}\n'
  } >"$SIM_OUT/report/summary.json"

  printf '%s\n' "$report"
}
