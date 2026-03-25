#!/bin/bash
# commit_workspace.sh - Stage and commit workspace changes with smart message
# Usage: ./commit_workspace.sh ["custom message"]
# Supports multi-agent workspace: auto-detects agent from WORKSPACE_DIR or path

# Detect workspace root (multi-agent or single)
DETECTED_WORKSPACE=""
AGENT_PREFIX=""

if [ -n "$WORKSPACE_DIR" ]; then
    # Use WORKSPACE_DIR if set
    DETECTED_WORKSPACE="$WORKSPACE_DIR"
elif [ -n "$1" ]; then
    DETECTED_WORKSPACE="$1"
else
    # Try to find git root from current dir
    DETECTED_WORKSPACE=$(git rev-parse --show-toplevel 2>/dev/null || echo "/home/claw/.openclaw/workspace")
fi

cd "$DETECTED_WORKSPACE" || exit 1

# Detect if multi-agent workspace and which agent we're in
AGENT_NAME=""
if [ -d "main" ] && [ -d "research" ] && [ -d "shared" ]; then
    # Multi-agent workspace detected
    CURRENT_DIR=$(pwd)
    case "$CURRENT_DIR" in
        */main) AGENT_NAME="main" ;;
        */research) AGENT_NAME="research" ;;
        */main-backup) AGENT_NAME="main-backup" ;;
        */dev) AGENT_NAME="dev" ;;
    esac
fi

# Check if git repo exists
if [ ! -d ".git" ]; then
    echo "Not a git repository. Please initialize first."
    exit 1
fi

# Stage relevant files - stage everything in multi-agent mode
echo "Staging workspace changes..."
if [ -n "$AGENT_NAME" ]; then
    # Multi-agent: stage all changes
    git add -A
else
    # Single agent: stage specific files
    git add MEMORY.md memory/*.md USER.md IDENTITY.md SOUL.md TOOLS.md AGENTS.md HEARTBEAT.md 2>/dev/null
fi

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

# Build commit message with agent prefix if applicable
if [ -n "$2" ]; then
    MESSAGE="$2"
else
    # Auto-generate from changed files
    CHANGED=$(git diff --cached --name-only | grep -E '\.(md|txt|json)$' | head -5 | tr '\n' ' ')
    TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")
    MESSAGE="Session checkpoint $TIMESTAMP - $CHANGED"
fi

# Add agent prefix for multi-agent commits
if [ -n "$AGENT_NAME" ]; then
    MESSAGE="[$AGENT_NAME] $MESSAGE"
fi

# Get OpenClaw version and model for footer
OPENCLAW_VERSION=""
MODEL=""

# Try to get version from openclaw command if available
if command -v openclaw &>/dev/null; then
    OPENCLAW_VERSION=$(openclaw version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
fi

# Fallback: try to extract from config
if [ -z "$OPENCLAW_VERSION" ] && [ -f "$HOME/.openclaw/openclaw.json" ]; then
    OPENCLAW_VERSION=$(grep -oE '"lastTouchedVersion":\s*"[^"]+"' "$HOME/.openclaw/openclaw.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
fi

# Default version if we couldn't detect
[ -z "$OPENCLAW_VERSION" ] && OPENCLAW_VERSION="2026.3.8"

# Try to get current model from session or config
if [ -n "$OPENCLAW_MODEL" ]; then
    MODEL="$OPENCLAW_MODEL"
elif [ -f "$HOME/.openclaw/openclaw.json" ]; then
    # Extract default model from config
    MODEL=$(grep -oE '"primary":\s*"[^"]+"' "$HOME/.openclaw/openclaw.json" | head -1 | grep -oE '[^"]+/[^"]+' | tail -1)
fi

# Default model if we couldn't detect
[ -z "$MODEL" ] && MODEL="openrouter/moonshotai/kimi-k2.5"

# Build full commit message with footer
FULL_MESSAGE="${MESSAGE}

OpenClaw: ${OPENCLAW_VERSION}
Model: ${MODEL}"

# Commit
git commit -m "$FULL_MESSAGE"
echo "Committed: $MESSAGE"

# Auto-push to remote if configured
if git remote get-url origin &>/dev/null; then
    echo "Pushing to origin..."
    git push origin HEAD
else
    echo "No remote configured. To push: git remote add origin <url> && git push -u origin main"
fi

# Show status
git status --short
