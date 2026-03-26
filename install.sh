#!/bin/bash
#
# Install OpenClaw Multi-Agent Kit
# 
# Quick install: curl -fsSL https://raw.githubusercontent.com/jimcadden/openclaw-multiagent/main/install.sh | bash
# With options: curl -fsSL ... | bash -s -- --workspace ~/my-workspace --agent main

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
KIT_REPO="https://github.com/jimcadden/openclaw-multiagent.git"
WORKSPACE_DIR=""
AGENT_NAME=""
DRY_RUN=false

# Logging helpers
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_dry() { echo -e "${CYAN}[DRY RUN]${NC} $1"; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --workspace|-w)
                WORKSPACE_DIR="$2"
                shift 2
                ;;
            --agent|-a)
                AGENT_NAME="$2"
                shift 2
                ;;
            --dry-run|-n)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
OpenClaw Multi-Agent Kit Installer

Usage: install.sh [OPTIONS]

Options:
  -w, --workspace DIR    Workspace directory (default: ~/workspaces)
  -a, --agent NAME       First agent name (default: main)
  -n, --dry-run          Show what would be done without doing it
  -h, --help             Show this help

Examples:
  # Default install
  curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash

  # Custom workspace and agent name
  curl -fsSL ... | bash -s -- --workspace ~/projects --agent assistant

  # Local install
  ./install.sh --workspace ~/my-workspace --agent bot
EOF
}

# Detect or prompt for workspace directory
get_workspace_dir() {
    if [ -z "$WORKSPACE_DIR" ]; then
        if $DRY_RUN; then
            WORKSPACE_DIR="$HOME/workspaces"
            log_dry "Would use default workspace: $WORKSPACE_DIR"
        else
            read -p "Workspace directory [$HOME/workspaces]: " WORKSPACE_DIR
            WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/workspaces}"
        fi
    fi
    
    # Expand tilde
    WORKSPACE_DIR="${WORKSPACE_DIR/#\~/$HOME}"
    
    # Check if exists and has content
    if [ -d "$WORKSPACE_DIR" ] && [ "$(ls -A "$WORKSPACE_DIR" 2>/dev/null)" ]; then
        log_warn "Directory $WORKSPACE_DIR already exists and is not empty"
        if ! $DRY_RUN; then
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Aborted"
                exit 0
            fi
        fi
    fi
}

# Check prerequisites
check_prereqs() {
    log_info "Checking prerequisites..."
    
    if $DRY_RUN; then
        log_dry "Would check: git is installed"
        log_dry "Would check: openclaw is installed"
        log_dry "Would check: ~/.openclaw/ exists"
        return 0
    fi
    
    if ! command -v git &> /dev/null; then
        log_error "Git is required but not installed"
        exit 1
    fi
    
    if ! command -v openclaw &> /dev/null; then
        log_error "OpenClaw is required but not installed"
        log_info "Install OpenClaw first: https://docs.openclaw.ai"
        exit 1
    fi
    
    if [ ! -d "$HOME/.openclaw" ]; then
        log_error "OpenClaw config not found at ~/.openclaw"
        log_info "Run OpenClaw at least once to initialize"
        exit 1
    fi
    
    log_success "Prerequisites OK"
}

# Clone/setup the kit
setup_kit() {
    log_info "Setting up multiagent kit..."
    
    # Create workspace if needed
    if $DRY_RUN; then
        log_dry "Would create: $WORKSPACE_DIR"
        log_dry "Would init git repo in: $WORKSPACE_DIR"
        log_dry "Would add kit submodule: $KIT_REPO -> kit/"
        log_dry "Would checkout latest stable tag in kit/"
        return 0
    fi
    
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
    
    # Init git if needed
    if [ ! -d ".git" ]; then
        git init
        log_success "Initialized git repository"
    fi
    
    # Add kit as submodule
    if [ ! -d "kit" ]; then
        log_info "Cloning kit repository..."
        git submodule add "$KIT_REPO" kit
        log_success "Added kit submodule"
    fi
    
    # Checkout latest stable tag
    cd kit
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$LATEST_TAG" ]; then
        git checkout "$LATEST_TAG"
        log_success "Checked out kit version: $LATEST_TAG"
    else
        log_warn "No tags found, using main branch"
    fi
    cd ..
    
    export WORKSPACE_DIR
    export KIT_DIR="$WORKSPACE_DIR/kit"
}

# Run bootstrap
run_bootstrap() {
    log_info "Running bootstrap..."
    
    if $DRY_RUN; then
        log_dry "Would run: ./kit/skills/multiagent-bootstrap/scripts/setup.sh"
        log_dry "  With WORKSPACE_DIR=$WORKSPACE_DIR"
        log_dry "  With AGENT_NAME=${AGENT_NAME:-main}"
        return 0
    fi
    
    if [ -f "$WORKSPACE_DIR/kit/skills/multiagent-bootstrap/scripts/setup.sh" ]; then
        if [ -n "$AGENT_NAME" ]; then
            "$WORKSPACE_DIR/kit/skills/multiagent-bootstrap/scripts/setup.sh" "$AGENT_NAME"
        else
            "$WORKSPACE_DIR/kit/skills/multiagent-bootstrap/scripts/setup.sh"
        fi
    else
        log_error "Bootstrap script not found"
        exit 1
    fi
}

# Main
main() {
    echo
    if $DRY_RUN; then
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║  OpenClaw Multi-Agent Kit Install (DRY RUN)            ║"
        echo "╚════════════════════════════════════════════════════════╝"
    else
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║  OpenClaw Multi-Agent Kit Install                      ║"
        echo "╚════════════════════════════════════════════════════════╝"
    fi
    echo
    
    parse_args "$@"
    get_workspace_dir
    check_prereqs
    setup_kit
    run_bootstrap
    
    echo
    if $DRY_RUN; then
        log_info "Dry run complete! To install for real, run without --dry-run"
    else
        log_success "Installation complete!"
    fi
    echo
}

main "$@"