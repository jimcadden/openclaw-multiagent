---
name: multiagent-bootstrap
description: One-time bootstrap setup for OpenClaw multiagent workspaces. Run after cloning the openclaw-multiagent repository to configure the local OpenClaw installation with shared skills and create the first agent.
---

# Multiagent Bootstrap

One-time setup script for OpenClaw multiagent workspaces.

## When to Use

Run this **once** after adding the `openclaw-multiagent` repository as a git submodule:

```bash
cd ~/agent-workspace
./kit/skills/multiagent-bootstrap/scripts/setup.sh
```

## What It Does

1. **Creates `shared/skills/` directory structure**
   - Symlinks `multiagent-state-manager` → `shared/skills/`
   - Symlinks `multiagent-telegram-setup` → `shared/skills/`

2. **Creates first agent from workspace-template**
   - Copies `workspace-template/` to `main/` (or user-specified name)
   - Customizes IDENTITY.md, USER.md, etc.

3. **Updates `~/.openclaw/openclaw.json`**
   - Adds the new agent to `agents.list`
   - Optionally adds Telegram account + binding

4. **Commits initial state to git**
   - `git add -A && git commit -m "[init] Bootstrap agent workspace"`

5. **Prompts to restart OpenClaw gateway**

## Prerequisites

- Git repo initialized at `~/agent-workspace/`
- `openclaw-multiagent` added as submodule at `~/agent-workspace/kit/`
- OpenClaw installed and configured

## After Bootstrap

Restart the OpenClaw gateway to activate:

```bash
openclaw gateway restart
```

Or use the gateway tool in your session.
