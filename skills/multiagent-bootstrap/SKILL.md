---
name: multiagent-bootstrap
description: Set up or migrate an OpenClaw workspace to use the multiagent kit. Use when asked to install the multiagent kit, run workspace setup for the first time, or migrate existing agents to the multiagent structure.
disable-model-invocation: true
user-invocable: true
---

# multiagent-bootstrap

One-time bootstrap or migration for OpenClaw multi-agent workspace.

## Purpose

- **Bootstrap** — sets up a fresh workspace from scratch: creates the first agent, wires shared skills, and registers the agent in OpenClaw config.
- **Migrate** — adds the multiagent kit to an existing OpenClaw instance that already has agents running, without touching existing agent data.

---

## Bootstrap (Fresh Install)

### When to Use

Use bootstrap when OpenClaw is installed but no agents exist yet.

### Usage

```bash
cd ~/workspaces
./kit/skills/multiagent-bootstrap/scripts/setup.sh
```

Or with an agent name:

```bash
./setup.sh my-agent
```

### Dry Run

```bash
./setup.sh --dry-run
./setup.sh -n my-agent
```

### What It Does

1. Validates environment — checks OpenClaw config, git, python3
2. Creates `shared/skills/` with symlinks into `kit/skills/`
3. Creates first agent from `workspace-template/`
4. Prompts to customize `IDENTITY.md` and `USER.md`
5. Registers agent in `openclaw.json`
6. Optionally runs Telegram setup
7. Prompts to create initial git commit

### Prerequisites

- OpenClaw installed and initialized (`~/.openclaw/openclaw.json` must exist)
- This repo added as submodule at `<workspace>/kit/`
- Git initialized in the workspace directory

### Files Created

```
<workspace>/
├── kit/                       # this submodule (unchanged)
├── shared/
│   └── skills/                # registered via skills.load.extraDirs in openclaw.json
│       ├── multiagent-state-manager   -> ../../kit/skills/multiagent-state-manager
│       ├── multiagent-telegram-setup  -> ../../kit/skills/multiagent-telegram-setup
│       ├── multiagent-add-agent       -> ../../kit/skills/multiagent-add-agent
│       └── multiagent-memory-manager  -> ../../kit/skills/multiagent-memory-manager
└── <agent-name>/
    ├── AGENTS.md
    ├── HEARTBEAT.md
    ├── IDENTITY.md
    ├── MEMORY.md
    ├── SOUL.md
    ├── TOOLS.md
    └── USER.md
```

Skills are loaded from `shared/skills/` via `skills.load.extraDirs` in `openclaw.json` — no per-agent symlinks needed.

---

## Migration (Existing Agents)

### When to Use

Use migration when OpenClaw is already running with one or more agents that have `IDENTITY.md` and `SOUL.md`.

### Usage — by hand

```bash
cd <workspace>
./kit/skills/multiagent-bootstrap/scripts/migrate.sh
```

With options:

```bash
./migrate.sh --workspace ~/.openclaw/workspace --openclaw-dir ~/.openclaw
./migrate.sh --dry-run   # preview without making changes
```

### Usage — via agent

When asked to migrate, follow these steps:

1. **Confirm the workspace path** — ask the user if the default (`~/.openclaw/workspace`) is correct, or if they have a custom location
2. **Run dry-run first** to show what will change:
   ```bash
   <path-to-kit>/skills/multiagent-bootstrap/scripts/migrate.sh --dry-run
   ```
3. **Show the dry-run output** to the user and confirm before proceeding
4. **Run migration**:
   ```bash
   <path-to-kit>/skills/multiagent-bootstrap/scripts/migrate.sh
   ```
5. **Report what changed** — agents found, symlinks created, config updated
6. **Instruct the user to restart the gateway**:
   ```
   openclaw gateway restart
   ```

### What Migration Does

1. Validates prerequisites — git, python3, openclaw dir, openclaw.json
2. Scans workspace for existing agents (directories with `IDENTITY.md` + `SOUL.md`)
3. Shows confirmation summary before making any changes
4. Adds the kit as a git submodule (if not present), checks out latest release tag
5. Creates `shared/skills/` with symlinks to `kit/skills/`
6. Adds per-agent symlinks routing through `shared/skills/`
7. Prompts to create a git commit

### What Migration Does NOT Touch

- `IDENTITY.md`, `MEMORY.md`, `SOUL.md`, `USER.md`, `AGENTS.md` — all preserved
- `openclaw.json` — not modified during migration (agents are already registered)
- Any existing workspace content not related to skill symlinks

### Manual Migration Steps

If you prefer to do it step by step:

```bash
cd <workspace>

# 1. Add the kit as a submodule and pin to latest release
git submodule add https://github.com/jimcadden/openclaw-multiagent.git kit
cd kit
git checkout $(git describe --tags --abbrev=0)
cd ..

# 2. Create shared skills directory
mkdir -p shared/skills
ln -s ../../kit/skills/multiagent-state-manager  shared/skills/multiagent-state-manager
ln -s ../../kit/skills/multiagent-telegram-setup shared/skills/multiagent-telegram-setup
ln -s ../../kit/skills/multiagent-add-agent      shared/skills/multiagent-add-agent
ln -s ../../kit/skills/multiagent-memory-manager shared/skills/multiagent-memory-manager

# 3. Register shared skills in openclaw.json
# Add to ~/.openclaw/openclaw.json:
# "skills": { "load": { "extraDirs": ["<workspace>/shared/skills"] } }

# 4. Commit
git add -A
git commit -m "[kit] Add openclaw-multiagent kit"
```

---

## Post-Bootstrap / Post-Migration

1. Verify the workspace: `bash kit/skills/multiagent-kit-guide/scripts/check-setup.sh`
2. Restart OpenClaw: `openclaw gateway restart`
3. Verify agent loads: `openclaw status`
4. Set up Telegram (if not done): `python3 kit/skills/multiagent-telegram-setup/scripts/setup-telegram-agent.py`
