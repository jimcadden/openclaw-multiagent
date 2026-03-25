# OpenClaw Multiagent

A starter kit for running multiple OpenClaw agents with shared skills, git-based state management, and Telegram bot integration.

## What's Included

- **multiagent-bootstrap** — One-time setup script to configure your OpenClaw installation
- **multiagent-state-manager** — Git-based checkpointing for agent workspaces
- **multiagent-telegram-setup** — Create and configure Telegram bots for your agents
- **workspace-template** — Starter files for new agents (IDENTITY.md, SOUL.md, etc.)

## Quick Start

```bash
# 1. Create your agent workspace
mkdir -p ~/agent-workspace
cd ~/agent-workspace
git init

# 2. Add this repository as a submodule
git submodule add https://github.com/jimcadden/openclaw-multiagent.git kit

# 3. Run the bootstrap script
./kit/skills/multiagent-bootstrap/scripts/setup.sh

# 4. Restart OpenClaw gateway
openclaw gateway restart
```

## Directory Structure

After bootstrap, your workspace will look like:

```
~/agent-workspace/
├── kit/                          # This repository (submodule)
│   ├── skills/
│   │   ├── multiagent-bootstrap/
│   │   ├── multiagent-state-manager/
│   │   └── multiagent-telegram-setup/
│   └── workspace-template/
├── shared/
│   └── skills/                   # Symlinks to kit/skills/*
│       ├── multiagent-state-manager -> ../../kit/skills/multiagent-state-manager
│       └── multiagent-telegram-setup -> ../../kit/skills/multiagent-telegram-setup
├── main/                         # Your first agent (from template)
│   ├── AGENTS.md
│   ├── IDENTITY.md
│   ├── MEMORY.md
│   ├── SOUL.md
│   ├── TOOLS.md
│   ├── USER.md
│   └── ...
└── .git/
```

## Skills

### multiagent-bootstrap

Run once after cloning to set up your workspace:

```bash
./kit/skills/multiagent-bootstrap/scripts/setup.sh
```

Creates symlinks, sets up your first agent, and optionally configures Telegram.

### multiagent-state-manager

Checkpoint your agent's progress with git:

```bash
# From any agent directory
./shared/skills/multiagent-state-manager/scripts/commit_workspace.sh

# Check status
./shared/skills/multiagent-state-manager/scripts/status_summary.sh
```

Commits include:
- Agent prefix (e.g., `[main]`, `[research]`)
- OpenClaw version
- Model information

### multiagent-telegram-setup

Create additional Telegram bots for your agents:

```bash
python3 ./shared/skills/multiagent-telegram-setup/scripts/setup-telegram-agent.py
```

Or follow the manual setup guide in the [SKILL.md](skills/multiagent-telegram-setup/SKILL.md).

## Creating Additional Agents

After bootstrap, you can create more agents:

```bash
# Copy the template
cp -r kit/workspace-template my-new-agent

# Edit identity files
cd my-new-agent
vim IDENTITY.md USER.md MEMORY.md

# Add to OpenClaw config
# (See multiagent-telegram-setup/SKILL.md for manual config)

# Commit
git add my-new-agent/
git commit -m "[main] Add my-new-agent workspace"
```

## Updating the Kit

To get the latest version:

```bash
cd kit
git pull origin main
cd ..
git add kit
git commit -m "[main] Update openclaw-multiagent kit"
```

## Requirements

- OpenClaw installed and configured
- Git
- Python 3 (for Telegram setup script)
- SSH key added to GitHub (for private repos)

## License

MIT

## Contributing

This is a personal starter kit, but contributions are welcome. Open an issue or PR on GitHub.
