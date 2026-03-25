#!/bin/bash
#
# Multiagent Bootstrap Setup Script
# One-time setup for OpenClaw multiagent workspaces
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
WORKSPACE_DIR="$(pwd)"
KIT_DIR="$WORKSPACE_DIR/kit"
SKILLS_DIR="$WORKSPACE_DIR/shared/skills"
TEMPLATE_DIR="$KIT_DIR/workspace-template"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  OpenClaw Multiagent Bootstrap${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if [ ! -d "$KIT_DIR" ]; then
    echo -e "${RED}Error: kit/ directory not found.${NC}"
    echo "Make sure you've added the openclaw-multiagent submodule:"
    echo "  git submodule add https://github.com/jimcadden/openclaw-multiagent.git kit"
    exit 1
fi

if [ ! -f "$OPENCLAW_CONFIG" ]; then
    echo -e "${RED}Error: OpenClaw config not found at $OPENCLAW_CONFIG${NC}"
    echo "Please ensure OpenClaw is installed and configured."
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo

# Create shared/skills directory and symlinks
echo -e "${BLUE}Setting up shared skills...${NC}"

mkdir -p "$SKILLS_DIR"

# Create symlinks to kit skills
ln -sf "$KIT_DIR/skills/multiagent-state-manager" "$SKILLS_DIR/multiagent-state-manager"
ln -sf "$KIT_DIR/skills/multiagent-telegram-setup" "$SKILLS_DIR/multiagent-telegram-setup"

echo -e "${GREEN}✓ Skills linked:${NC}"
echo "  - multiagent-state-manager"
echo "  - multiagent-telegram-setup"
echo

# Ask for first agent name
echo -e "${BLUE}Creating your first agent...${NC}"
read -p "Agent name [main]: " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-main}

AGENT_DIR="$WORKSPACE_DIR/$AGENT_NAME"

if [ -d "$AGENT_DIR" ]; then
    echo -e "${YELLOW}Warning: $AGENT_NAME/ already exists. Skipping creation.${NC}"
else
    # Copy workspace template
    cp -r "$TEMPLATE_DIR" "$AGENT_DIR"
    
    # Remove symlinks that point to old locations (if any)
    rm -f "$AGENT_DIR/agent-state-manager" 2>/dev/null || true
    rm -f "$AGENT_DIR/telegram-agent-setup" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Created agent: $AGENT_NAME/${NC}"
fi
echo

# Ask about Telegram setup
echo -e "${BLUE}Telegram Configuration${NC}"
read -p "Configure Telegram bot for this agent? [y/N]: " SETUP_TELEGRAM

if [[ "$SETUP_TELEGRAM" =~ ^[Yy]$ ]]; then
    echo
    echo -e "${YELLOW}To configure Telegram, you'll need:${NC}"
    echo "  1. A bot token from @BotFather"
    echo "  2. Your Telegram user ID"
    echo
    read -p "Bot token: " BOT_TOKEN
    read -p "Your Telegram user ID: " USER_ID
    read -p "Account ID (e.g., ${AGENT_NAME}_bot): " ACCOUNT_ID
    ACCOUNT_ID=${ACCOUNT_ID:-${AGENT_NAME}_bot}
    
    # Update openclaw.json
    echo -e "${BLUE}Updating OpenClaw configuration...${NC}"
    
    # This is a simplified update - in practice, you might want to use a JSON tool
    echo -e "${YELLOW}Please manually add the following to $OPENCLAW_CONFIG:${NC}"
    echo
    echo "1. Add to agents.list:"
    echo "   { \"id\": \"$AGENT_NAME\", \"name\": \"$AGENT_NAME\", \"workspace\": \"$AGENT_DIR\" }"
    echo
    echo "2. Add to channels.telegram.accounts:"
    echo "   \"$ACCOUNT_ID\": {"
    echo "     \"enabled\": true,"
    echo "     \"dmPolicy\": \"allowlist\","
    echo "     \"botToken\": \"$BOT_TOKEN\","
    echo "     \"allowFrom\": [$USER_ID],"
    echo "     \"groupPolicy\": \"allowlist\","
    echo "     \"streaming\": \"partial\""
    echo "   }"
    echo
    echo "3. Add to bindings:"
    echo "   { \"agentId\": \"$AGENT_NAME\", \"match\": { \"channel\": \"telegram\", \"accountId\": \"$ACCOUNT_ID\" } }"
    echo
else
    echo -e "${YELLOW}Skipping Telegram setup. You can configure it later.${NC}"
    echo
fi

# Git commit
echo -e "${BLUE}Committing initial state...${NC}"

if [ -d "$WORKSPACE_DIR/.git" ]; then
    cd "$WORKSPACE_DIR"
    git add -A
    git commit -m "[init] Bootstrap agent workspace

OpenClaw: $(openclaw version 2>/dev/null || echo 'unknown')
Multiagent Kit: https://github.com/jimcadden/openclaw-multiagent" || echo -e "${YELLOW}Nothing to commit${NC}"
    echo -e "${GREEN}✓ Changes committed${NC}"
else
    echo -e "${YELLOW}Warning: Not a git repository. Skipping commit.${NC}"
fi
echo

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Bootstrap Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "Agent: ${BLUE}$AGENT_NAME${NC}"
echo -e "Location: ${BLUE}$AGENT_DIR${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review and customize your agent files:"
echo "     - $AGENT_NAME/IDENTITY.md"
echo "     - $AGENT_NAME/USER.md"
echo "     - $AGENT_NAME/MEMORY.md"
echo
echo "  2. Restart OpenClaw gateway:"
echo "     openclaw gateway restart"
echo
echo "  3. Start chatting with your agent!"
echo
