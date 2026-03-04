# Ralph CLI

CLI standalone para orquestar loops AFK TDD sobre un PRD estructurado.

## Instalacion

```bash
git clone <repo> ~/Documents/ditherlabs/ralph
chmod +x ~/Documents/ditherlabs/ralph/ralph.sh
ln -s ~/Documents/ditherlabs/ralph/ralph.sh /usr/local/bin/ralph
```

## Uso

```bash
ralph run                           # 1 task (once mode)
ralph run -n 5                      # 5 iteraciones (tdd loop)
ralph run -a claude                 # override agent
ralph run -a opencode -m prov/model # override agent + model
ralph run --mode legacy -n 10       # legacy mode, 10 iteraciones
ralph run --migration-cmd "bunx drizzle-kit generate"  # inline migration cmd
ralph init                          # scaffold ralph.conf + ralph/PRD.md + ralph/progress.txt
ralph status                        # tabla de tasks parseada del PRD
ralph log                           # progress.txt formateado
```

Precedencia: `CLI flags > ralph.conf > defaults internos`.

## Config por proyecto

Crear `ralph.conf` en el root del proyecto target:

```bash
# ralph.conf
RALPH_AGENT=opencode
RALPH_MODEL=""
RALPH_PRD=ralph/PRD.md
RALPH_PROGRESS=ralph/progress.txt
RALPH_QUALITY_GATE="bun run lint && bun run test:run"
RALPH_COMMIT_PREFIX=TDD
RALPH_MODE=tdd
# Migration generation cmd — if set, prompts instruct agent to use it instead of writing SQL by hand
RALPH_MIGRATION_CMD="bunx drizzle-kit generate"
```

## Migrations

Si el proyecto usa un ORM con migraciones (Drizzle, Prisma, etc), seteá `RALPH_MIGRATION_CMD` para que Ralph instruya al agente a generar artifacts via el ORM en vez de escribir SQL a mano.

**Con ralph.conf:**

```bash
RALPH_MIGRATION_CMD="bunx drizzle-kit generate"
```

**Inline sin ralph.conf:**

```bash
ralph run --migration-cmd "bunx drizzle-kit generate"
ralph run -n 5 --migration-cmd "npx prisma migrate dev"
```

Si `MIGRATION_CMD` está vacío (default), el prompt no menciona migraciones.

## Estructura

```
~/Documents/ditherlabs/ralph/
├── ralph.sh
├── prompts/
│   ├── once-tdd.txt
│   ├── tdd.txt
│   └── legacy.txt
├── init/
│   ├── ralph.conf
│   ├── PRD.md
│   └── progress.txt
├── IMPLEMENTATION.md
└── README.md
```
