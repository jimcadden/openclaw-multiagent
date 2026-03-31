#!/bin/bash
#
# set-agent-sandbox.sh: Change the sandbox mode for an existing agent
#
# Usage: ./set-agent-sandbox.sh --agent <agent-id> --mode <off|inherit>
#
#   off     — agent is never sandboxed (sets sandbox.mode = "off" on the entry)
#   inherit — agent follows agents.defaults.sandbox.mode (removes per-agent override)

set -e

# ─── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

# ─── Defaults ─────────────────────────────────────────────────────────────────

OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}"
AGENT_ID=""
MODE=""

# ─── Args ─────────────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 --agent <agent-id> --mode <off|inherit>"
    echo
    echo "  --agent    ID of the agent to update (must exist in openclaw.json)"
    echo "  --mode     off      — disable sandboxing for this agent"
    echo "             inherit  — remove override; agent follows global default"
    echo
    echo "Environment:"
    echo "  OPENCLAW_DIR  path to OpenClaw config dir (default: ~/.openclaw)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent) AGENT_ID="$2"; shift 2 ;;
        --mode)  MODE="$2";     shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown argument: $1"; usage ;;
    esac
done

# ─── Validate ─────────────────────────────────────────────────────────────────

if [ -z "$AGENT_ID" ]; then
    log_error "--agent is required"
    usage
fi

if [ -z "$MODE" ]; then
    log_error "--mode is required"
    usage
fi

if [[ "$MODE" != "off" && "$MODE" != "inherit" ]]; then
    log_error "--mode must be 'off' or 'inherit', got: $MODE"
    usage
fi

CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "openclaw.json not found at $CONFIG_FILE"
    log_info "Set OPENCLAW_DIR if your config lives elsewhere."
    exit 1
fi

# ─── Update ───────────────────────────────────────────────────────────────────

python3 << EOF
import json, sys

config_file = "$CONFIG_FILE"
agent_id = "$AGENT_ID"
mode = "$MODE"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)

    agents_list = config.get('agents', {}).get('list', [])
    matches = [a for a in agents_list if a.get('id') == agent_id]

    if not matches:
        print(f"Agent '{agent_id}' not found in openclaw.json", file=sys.stderr)
        known = [a.get('id') for a in agents_list]
        print(f"Known agents: {', '.join(known) if known else '(none)'}", file=sys.stderr)
        sys.exit(1)

    entry = matches[0]
    prev = entry.get('sandbox', {}).get('mode', 'inherit')

    if mode == "off":
        entry['sandbox'] = {'mode': 'off'}
        print(f"Set sandbox mode for '{agent_id}': {prev} -> off")
    else:
        if 'sandbox' in entry:
            del entry['sandbox']
        print(f"Removed sandbox override for '{agent_id}' (was: {prev}); now inherits global default")

    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
EOF

log_success "openclaw.json updated"
log_warn "Restart the gateway to apply: openclaw gateway restart"
