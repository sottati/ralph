# Ralph CLI — Plan de implementacion

Ralph es un orquestador AFK de agentes de IA. Ejecuta loops autonomos de TDD sobre un PRD estructurado.

Actualmente vive dentro de `promograph/ralph/` como scripts acoplados a opencode. Este documento describe la transformacion a CLI standalone multi-agent.

## Estructura objetivo

```
~/Documents/ditherlabs/ralph/
├── ralph.sh                    # Entry point unico (se linkea al PATH)
├── prompts/
│   ├── once-tdd.txt            # Prompt mode once
│   ├── tdd.txt                 # Prompt mode tdd
│   └── legacy.txt              # Prompt mode legacy
├── init/                       # Templates para `ralph init`
│   ├── ralph.conf              # Config template
│   ├── PRD.md                  # PRD vacio con estructura correcta
│   └── progress.txt            # Vacio
├── IMPLEMENTATION.md           # Este archivo
└── README.md                   # Documentacion del CLI
```

Los archivos actuales (`afk-ralph.sh`, `ralph-once-tdd.sh`, `ralph-tdd.sh`, `ralph-once.sh`, `*-prompt.txt`) se eliminan tras completar la migracion.

## CLI interface

```bash
ralph run                           # 1 task (once mode), agent y config de ralph.conf
ralph run -n 5                      # 5 iteraciones (tdd loop)
ralph run -a claude                 # override agent
ralph run -a opencode -m prov/model # override agent + model
ralph run --mode legacy -n 10       # legacy mode, 10 iteraciones
ralph init                          # scaffold ralph.conf + ralph/PRD.md + ralph/progress.txt en CWD
ralph status                        # tabla de tasks parseada del PRD
ralph log                           # progress.txt formateado
```

Precedencia: `CLI flags > ralph.conf > defaults internos`.

## Config por proyecto: `ralph.conf`

Archivo bash sourceable. Se coloca en la raiz del proyecto target.

```bash
# ralph.conf
RALPH_AGENT=opencode
RALPH_MODEL=""
RALPH_PRD=ralph/PRD.md
RALPH_PROGRESS=ralph/progress.txt
RALPH_QUALITY_GATE="bun run lint && bun run test:run"
RALPH_COMMIT_PREFIX=TDD
RALPH_MODE=tdd
```

Se carga con `source ./ralph.conf`. Si no existe, el script usa defaults internos. Flags de CLI overridean la config.

## Agent dispatch

Cada agent CLI se invoca distinto. Un `case` de pocas lineas por agent:

```bash
case "$AGENT" in
  opencode)
    RUN_CMD=(opencode run)
    if [ -n "$MODEL" ]; then RUN_CMD+=(-m "$MODEL"); fi
    RUN_CMD+=("$PROMPT")
    ;;
  claude)
    RUN_CMD=(claude -p --dangerously-skip-permissions)
    if [ -n "$MODEL" ]; then RUN_CMD+=(--model "$MODEL"); fi
    RUN_CMD+=("$PROMPT")
    ;;
esac
result="$("${RUN_CMD[@]}")"
```

| | opencode | claude |
|---|---|---|
| Comando base | `opencode run` | `claude -p` |
| Model flag | `-m provider/model` | `--model name` |
| Permisos AFK | No necesita | `--dangerously-skip-permissions` |
| File injection | No (prompt dice "lee los archivos") | No (prompt dice "lee los archivos") |

Agregar un nuevo agent = agregar un `case` de 3-4 lineas.

### Porque no se usa `-f` (file flags)

Los scripts originales usan `opencode run -f PRD.md -f progress.txt` para attachar archivos. Esto es especifico de opencode — claude no tiene equivalente.

En vez de eso, el prompt instruye al agent a leer los archivos del filesystem. Ambos CLIs (opencode y claude) son coding agents con acceso al filesystem, asi que pueden leer archivos por su cuenta. Elimina la necesidad de adapters de file injection.

## Prompt templates

Los 3 prompts viven en `prompts/`. Usan placeholders que se reemplazan en runtime via `sed`:

| Placeholder | Reemplazado por | Default |
|---|---|---|
| `{{QUALITY_GATE}}` | `RALPH_QUALITY_GATE` | `bun run lint && bun run test:run` |
| `{{PRD_PATH}}` | `RALPH_PRD` | `ralph/PRD.md` |
| `{{PROGRESS_PATH}}` | `RALPH_PROGRESS` | `ralph/progress.txt` |
| `{{COMMIT_PREFIX}}` | `RALPH_COMMIT_PREFIX` | `TDD` |

### Cambios vs prompts actuales

| Cambio | Antes | Despues |
|---|---|---|
| Linea 1 | `@ralph/PRD.md @ralph/progress.txt` | Eliminada (file annotations de opencode, no aplica a claude) |
| File loading | Se pasan con `-f` flag | Prompt dice "Read {{PRD_PATH}} and {{PROGRESS_PATH}}" |
| Quality gate | `bun run lint && bun run test:run` | `{{QUALITY_GATE}}` |
| Paths | Hardcoded `ralph/PRD.md` | `{{PRD_PATH}}` |
| Commit prefix | `TDD(Txx)` | `{{COMMIT_PREFIX}}(Txx)` |
| Skill ref | `Use the tdd skill` | Se mantiene (ambos CLIs lo tienen via symlinks) |

### Prompt once-tdd.txt

```
You are running Ralph one-shot TDD mode.

Rules:
1. Read {{PRD_PATH}} and {{PROGRESS_PATH}}.
2. Use only the `## Tareas` section in PRD to select work.
3. Select exactly one task for this run:
   - only tasks with `Status: pending`
   - risk order: `high` before `medium` before `low`
   - tie-break by task id ascending (`T01`, `T02`, ...)
4. Work only on the selected task:
   - update selected task status to `in_progress`
   - apply TDD vertical slices for acceptance criteria and test targets
   - RED -> GREEN cycles can repeat until behavior is covered
5. Run feedback loops: `{{QUALITY_GATE}}`. Both must pass.
6. If both checks pass:
   - mark only completed acceptance criteria as checked (`- [x]`)
   - set selected task `Status: done`
   - append a dated progress entry to {{PROGRESS_PATH}}
   - commit with message: `{{COMMIT_PREFIX}}(Txx): <behavior tested>`
7. If any check fails:
   - do not set `Status: done`
   - keep or set status as `blocked` with a short reason in task notes
   - append failure details to {{PROGRESS_PATH}}
   - do not commit
8. Do not change other tasks, statuses, or checklists.
9. After finishing this single task, STOP immediately.
10. Do not mention or analyze the next task, priority queue, or future steps.

Output contract:
- If there are no pending tasks, output exactly: `<promise>COMPLETE</promise>`
- If one task was processed in this one-shot run, output exactly: `<promise>ONCE_DONE:Txx</promise>`

Important:
- Use the `tdd` skill for all development.
- Validate observable behavior, not internals.
- Never execute DB migrations or deployments.
```

### Prompt tdd.txt

Identico a once-tdd.txt excepto:
- Linea 2: "iterative TDD mode" en vez de "one-shot TDD mode"
- Regla 9: "Do not analyze or plan the next task in this response." en vez de "STOP immediately"
- Token: `ITERATION_DONE:Txx` en vez de `ONCE_DONE:Txx`

### Prompt legacy.txt

```
You are running Ralph legacy AFK mode.

Rules:
1. Read {{PRD_PATH}} and {{PROGRESS_PATH}}.
2. Find the highest-priority incomplete task and implement it.
3. Work on a single task only.
4. Run feedback loops: `{{QUALITY_GATE}}`.
5. Update PRD and progress log with what was done.
6. Commit your changes.

Output contract:
- If PRD is complete, output exactly: `<promise>COMPLETE</promise>`
- Otherwise output: `<promise>LEGACY_ITERATION_DONE</promise>`

Important:
- Load and use the `tdd` skill for all development.
```

## Contract validation

Se mantiene la misma logica de los scripts actuales:

| Mode | Token valido | Accion |
|---|---|---|
| once | `<promise>ONCE_DONE:Txx</promise>` | exit 0 |
| once | `<promise>COMPLETE</promise>` | exit 0 |
| tdd | `<promise>ITERATION_DONE:Txx</promise>` | continue loop |
| tdd | `<promise>COMPLETE</promise>` | exit 0 |
| legacy | `<promise>COMPLETE</promise>` | exit 0 |
| legacy | (cualquier otro) | continue (loose) |
| once/tdd | (sin token) | exit 1, contract violation |

## ralph.sh — Pseudocodigo

```
#!/bin/bash
set -euo pipefail

RALPH_DIR="$(dirname "$(readlink -f "$0")")"   # donde vive ralph.sh (el repo)

# Defaults
AGENT=opencode
MODEL=""
MODE=""
ITERATIONS=1
PRD=ralph/PRD.md
PROGRESS=ralph/progress.txt
QUALITY_GATE="bun run lint && bun run test:run"
COMMIT_PREFIX=TDD

# Load project config (CWD)
[ -f ./ralph.conf ] && source ./ralph.conf

# Parse subcommand
case "${1:-}" in
  run)   shift; parse_run_flags "$@"; do_run ;;
  init)  do_init ;;
  status) do_status ;;
  log)   do_log ;;
  *)     usage ;;
esac

# --- do_run ---
# 1. Determinar mode (flag > config > default por -n)
#    - Si -n > 1 y no se especifico mode: mode=tdd
#    - Si -n == 1 y no se especifico mode: mode=once
# 2. Leer prompt template de $RALPH_DIR/prompts/{mode}.txt
# 3. Renderizar placeholders con sed
# 4. Build command segun agent (case opencode/claude)
# 5. Si mode=once: ejecutar 1 vez, validar contract
# 6. Si mode=tdd/legacy: loop N iteraciones, validar contract por iteracion

# --- do_init ---
# 1. Copiar $RALPH_DIR/init/ralph.conf -> ./ralph.conf
# 2. mkdir -p ralph/
# 3. Copiar $RALPH_DIR/init/PRD.md -> ./ralph/PRD.md
# 4. Copiar $RALPH_DIR/init/progress.txt -> ./ralph/progress.txt

# --- do_status ---
# 1. Parsear $PRD con grep/awk
# 2. Mostrar tabla: ID | Status | Risk | Nombre

# --- do_log ---
# 1. cat $PROGRESS (formateado)
```

## Instalacion

```bash
# Clonar
git clone <repo> ~/Documents/ditherlabs/ralph

# Hacer ejecutable
chmod +x ~/Documents/ditherlabs/ralph/ralph.sh

# Symlink al PATH
ln -s ~/Documents/ditherlabs/ralph/ralph.sh /usr/local/bin/ralph
```

Despues, desde cualquier proyecto:

```bash
cd ~/Documents/ditherlabs/wpp_bot
ralph init                    # scaffold
vim ralph.conf                # ajustar quality gate, agent, etc
vim ralph/PRD.md              # agregar tareas
ralph run -n 3                # ejecuta EN wpp_bot
ralph run -a claude -n 5      # usa claude code
ralph status                  # ver estado de tareas
```

## Migracion desde promograph

### Archivos que se quedan en promograph/ralph/

```
promograph/ralph/
├── ralph.conf      # NUEVO: config del proyecto
├── PRD.md          # datos del proyecto (ya existe)
└── progress.txt    # datos del proyecto (ya existe)
```

### Archivos que se eliminan de promograph/ralph/

```
afk-ralph.sh                    -> reemplazado por ralph.sh
ralph-once-tdd.sh               -> reemplazado por ralph.sh
ralph-once.sh                   -> reemplazado por ralph.sh (wrapper redundante)
ralph-tdd.sh                    -> reemplazado por ralph.sh
ralph-once-tdd-prompt.txt       -> movido a ralph repo: prompts/once-tdd.txt
ralph-tdd-prompt.txt            -> movido a ralph repo: prompts/tdd.txt
ralph-legacy-afk-prompt.txt     -> movido a ralph repo: prompts/legacy.txt
README.md                       -> movido a ralph repo
```

## Tareas de implementacion

| # | Tarea | Prioridad |
|---|---|---|
| 1 | Crear estructura de dirs (`prompts/`, `init/`) | alta |
| 2 | Escribir prompts con placeholders (3 archivos) | alta |
| 3 | Escribir `ralph.sh` — arg parsing (subcommands + flags) | alta |
| 4 | Escribir `ralph.sh` — config loading (`source ralph.conf`) | alta |
| 5 | Escribir `ralph.sh` — prompt rendering (`sed` placeholders) | alta |
| 6 | Escribir `ralph.sh` — agent dispatch (`case` opencode/claude) | alta |
| 7 | Escribir `ralph.sh` — contract validation (regex tokens) | alta |
| 8 | Escribir `ralph.sh` — loop logic (once/tdd/legacy) | alta |
| 9 | Escribir `ralph.sh` — `init` subcommand | media |
| 10 | Escribir `ralph.sh` — `status` subcommand | media |
| 11 | Escribir `ralph.sh` — `log` subcommand | baja |
| 12 | Escribir templates de init (`ralph.conf`, `PRD.md`, `progress.txt`) | media |
| 13 | Escribir README.md del CLI | baja |
| 14 | Symlink + test manual desde otro proyecto | alta |
| 15 | Crear `ralph.conf` en promograph y limpiar archivos viejos | media |
