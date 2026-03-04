#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ralph <command> [options]

Commands:
  run      Run Ralph loop
  init     Scaffold ralph.conf and ralph/ files
  status   Show PRD task table
  log      Show progress log

Run options:
  -n, --iterations N     Iterations (tdd/legacy)
  -a, --agent AGENT      Agent (opencode|claude)
  -m, --model MODEL      Model name
  --mode MODE            once|tdd|legacy
  --migration-cmd CMD    Migration generation command (e.g. "bunx drizzle-kit generate")
  -h, --help             Help
EOF
}

RALPH_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}")")" && pwd)"

# Defaults
AGENT="opencode"
MODEL=""
MODE=""
ITERATIONS="1"
PRD="ralph/PRD.md"
PROGRESS="ralph/progress.txt"
QUALITY_GATE="bun run lint && bun run test:run"
COMMIT_PREFIX="TDD"
MIGRATION_CMD=""

if [ -f ./ralph.conf ]; then
  # shellcheck disable=SC1091
  source ./ralph.conf
fi

if [ -n "${RALPH_AGENT:-}" ]; then AGENT="$RALPH_AGENT"; fi
if [ -n "${RALPH_MODEL:-}" ]; then MODEL="$RALPH_MODEL"; fi
if [ -n "${RALPH_MODE:-}" ]; then MODE="$RALPH_MODE"; fi
if [ -n "${RALPH_PRD:-}" ]; then PRD="$RALPH_PRD"; fi
if [ -n "${RALPH_PROGRESS:-}" ]; then PROGRESS="$RALPH_PROGRESS"; fi
if [ -n "${RALPH_QUALITY_GATE:-}" ]; then QUALITY_GATE="$RALPH_QUALITY_GATE"; fi
if [ -n "${RALPH_COMMIT_PREFIX:-}" ]; then COMMIT_PREFIX="$RALPH_COMMIT_PREFIX"; fi
if [ -n "${RALPH_MIGRATION_CMD:-}" ]; then MIGRATION_CMD="$RALPH_MIGRATION_CMD"; fi

parse_run_flags() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -n|--iterations)
        if [ -z "${2:-}" ]; then
          echo "Missing value for $1"
          exit 1
        fi
        ITERATIONS="$2"
        shift 2
        ;;
      --iterations=*)
        ITERATIONS="${1#*=}"
        shift
        ;;
      -a|--agent)
        if [ -z "${2:-}" ]; then
          echo "Missing value for $1"
          exit 1
        fi
        AGENT="$2"
        shift 2
        ;;
      --agent=*)
        AGENT="${1#*=}"
        shift
        ;;
      -m|--model)
        if [ -z "${2:-}" ]; then
          echo "Missing value for $1"
          exit 1
        fi
        MODEL="$2"
        shift 2
        ;;
      --model=*)
        MODEL="${1#*=}"
        shift
        ;;
      --mode)
        if [ -z "${2:-}" ]; then
          echo "Missing value for $1"
          exit 1
        fi
        MODE="$2"
        shift 2
        ;;
      --mode=*)
        MODE="${1#*=}"
        shift
        ;;
      --migration-cmd)
        if [ -z "${2:-}" ]; then
          echo "Missing value for $1"
          exit 1
        fi
        MIGRATION_CMD="$2"
        shift 2
        ;;
      --migration-cmd=*)
        MIGRATION_CMD="${1#*=}"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\\\&/g'
}

render_prompt() {
  local prompt_file="$1"
  local quality_gate
  local prd_path
  local progress_path
  local commit_prefix
  local migration_cmd
  quality_gate="$(sed_escape "$QUALITY_GATE")"
  prd_path="$(sed_escape "$PRD")"
  progress_path="$(sed_escape "$PROGRESS")"
  commit_prefix="$(sed_escape "$COMMIT_PREFIX")"
  migration_cmd="$(sed_escape "$MIGRATION_CMD")"

  local rendered
  if [ -z "$MIGRATION_CMD" ]; then
    rendered=$(sed -e '/{{MIGRATION_CMD}}/d' "$prompt_file")
  else
    rendered=$(cat "$prompt_file")
  fi

  printf '%s\n' "$rendered" | sed \
    -e "s|{{QUALITY_GATE}}|$quality_gate|g" \
    -e "s|{{PRD_PATH}}|$prd_path|g" \
    -e "s|{{PROGRESS_PATH}}|$progress_path|g" \
    -e "s|{{COMMIT_PREFIX}}|$commit_prefix|g" \
    -e "s|{{MIGRATION_CMD}}|$migration_cmd|g"
}

LAST_RESULT=""
run_agent() {
  local prompt="$1"
  local result=""
  case "$AGENT" in
    opencode)
      RUN_CMD=(opencode run)
      if [ -n "$MODEL" ]; then
        RUN_CMD+=(-m "$MODEL")
      fi
      RUN_CMD+=("$prompt")
      ;;
    claude)
      RUN_CMD=(claude -p --dangerously-skip-permissions)
      if [ -n "$MODEL" ]; then
        RUN_CMD+=(--model "$MODEL")
      fi
      RUN_CMD+=("$prompt")
      ;;
    *)
      echo "Unknown agent: $AGENT"
      exit 1
      ;;
  esac

  result="$("${RUN_CMD[@]}" | tee /dev/tty)"
  LAST_RESULT="$result"
  printf '%s\n' "$result"
}

validate_iterations() {
  if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || [ "$ITERATIONS" -lt 1 ]; then
    echo "Iterations must be a positive integer"
    exit 1
  fi
}

do_run() {
  if [ -z "$MODE" ]; then
    if [ "$ITERATIONS" -gt 1 ]; then
      MODE="tdd"
    else
      MODE="once"
    fi
  fi

  case "$MODE" in
    once|tdd|legacy) ;;
    *)
      echo "Unknown mode: $MODE"
      exit 1
      ;;
  esac

  if [ "$MODE" = "once" ]; then
    if [ "$ITERATIONS" -gt 1 ]; then
      echo "once mode does not support iterations > 1"
      exit 1
    fi
  else
    validate_iterations
  fi

  local prompt_file=""
  case "$MODE" in
    once) prompt_file="$RALPH_DIR/prompts/once-tdd.txt" ;;
    tdd) prompt_file="$RALPH_DIR/prompts/tdd.txt" ;;
    legacy) prompt_file="$RALPH_DIR/prompts/legacy.txt" ;;
  esac

  if [ ! -f "$prompt_file" ]; then
    echo "Missing prompt file: $prompt_file"
    exit 1
  fi

  local prompt
  prompt="$(render_prompt "$prompt_file")"

  if [ "$MODE" = "once" ]; then
    run_agent "$prompt"

    if [[ "$LAST_RESULT" == *"<promise>COMPLETE</promise>"* ]]; then
      exit 0
    fi

    if [[ "$LAST_RESULT" =~ \<promise\>ONCE_DONE:T[0-9]{2,}\</promise\> ]]; then
      exit 0
    fi

    echo "Prompt contract violated: once mode returned no stop token"
    echo "Expected <promise>ONCE_DONE:Txx</promise> or <promise>COMPLETE</promise>"
    exit 1
  fi

  for ((i=1; i<=ITERATIONS; i++)); do
    run_agent "$prompt"

    if [[ "$LAST_RESULT" == *"<promise>COMPLETE</promise>"* ]]; then
      echo "PRD complete after $i iterations."
      exit 0
    fi

    if [ "$MODE" = "tdd" ]; then
      if [[ "$LAST_RESULT" =~ \<promise\>ITERATION_DONE:T[0-9]{2,}\</promise\> ]]; then
        continue
      fi
      echo "Prompt contract violated on iteration $i: missing iteration token"
      echo "Expected <promise>ITERATION_DONE:Txx</promise> or <promise>COMPLETE</promise>"
      exit 1
    fi
  done
}

do_init() {
  if [ -e ./ralph.conf ] || [ -e ./ralph/PRD.md ] || [ -e ./ralph/progress.txt ]; then
    echo "Init aborted: ralph files already exist in this directory"
    exit 1
  fi

  if [ ! -f "$RALPH_DIR/init/ralph.conf" ] || [ ! -f "$RALPH_DIR/init/PRD.md" ] || [ ! -f "$RALPH_DIR/init/progress.txt" ]; then
    echo "Init templates missing in $RALPH_DIR/init"
    exit 1
  fi

  mkdir -p ./ralph
  cp "$RALPH_DIR/init/ralph.conf" ./ralph.conf
  cp "$RALPH_DIR/init/PRD.md" ./ralph/PRD.md
  cp "$RALPH_DIR/init/progress.txt" ./ralph/progress.txt
}

do_status() {
  if [ ! -f "$PRD" ]; then
    echo "Missing PRD: $PRD"
    exit 1
  fi

  printf '%s\t%s\t%s\t%s\n' "ID" "Status" "Risk" "Name"

  awk '
    /^### T[0-9]+:/ {
      id=$2
      sub(":", "", id)
      name=$0
      sub(/^### T[0-9]+: /, "", name)
      risk=""
      status=""
    }
    /^- Risk:/ { risk=$3 }
    /^- Status:/ {
      status=$3
      if (id != "") {
        printf "%s\t%s\t%s\t%s\n", id, status, risk, name
        id=""
      }
    }
  ' "$PRD"
}

do_log() {
  if [ ! -f "$PROGRESS" ]; then
    echo "Missing progress log: $PROGRESS"
    exit 1
  fi
  cat "$PROGRESS"
}

case "${1:-}" in
  run)
    shift
    parse_run_flags "$@"
    do_run
    ;;
  init)
    do_init
    ;;
  status)
    do_status
    ;;
  log)
    do_log
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "Unknown command: $1"
    usage
    exit 1
    ;;
esac
