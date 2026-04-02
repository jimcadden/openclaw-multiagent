#!/bin/bash
#
# sync-templates.sh: Sync workspace-template changes to existing agent workspaces
#
# When the kit is updated from version A to version B, this script detects which
# workspace-template files changed and merges those changes into each agent's
# workspace using three-way merge (git merge-file).
#
# Usage:
#   ./sync-templates.sh --old v0.2.2 --new v0.3.0 --workspace /path/to/workspace
#   ./sync-templates.sh --dry-run --old v0.2.2 --new v0.3.0 --workspace /path/to/workspace
#
# Options:
#   --old VERSION       Previous kit version (tag/commit). Falls back to .kit-version.
#   --new VERSION       New kit version (tag/commit). Required.
#   --workspace DIR     Workspace root. Defaults to git toplevel or ~/.openclaw/workspace.
#   --dry-run           Report what would change without modifying files.
#   --yes               Skip confirmation prompts.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
log_info()    { echo -e "  $1"; }
log_step()    { echo; echo -e "${CYAN}▶ $1${NC}"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }
log_dim()     { echo -e "${DIM}  $1${NC}"; }

# Files that are fully user-owned after creation — never sync these
EXCLUDE_FILES="IDENTITY.md USER.md MEMORY.md"

WORKSPACE_DIR=""
KIT_DIR=""
OLD_VERSION=""
NEW_VERSION=""
DRY_RUN=false
YES=false

# ─── Argument parsing ─────────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --old)
            [ -n "${2:-}" ] || { log_error "--old requires a value"; exit 1; }
            OLD_VERSION="$2"; shift 2 ;;
        --new)
            [ -n "${2:-}" ] || { log_error "--new requires a value"; exit 1; }
            NEW_VERSION="$2"; shift 2 ;;
        --workspace)
            [ -n "${2:-}" ] || { log_error "--workspace requires a value"; exit 1; }
            WORKSPACE_DIR="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --yes|-y)
            YES=true; shift ;;
        *)
            log_error "Unknown option: $1"; exit 1 ;;
    esac
done

WORKSPACE_DIR="${WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/.openclaw/workspace")}"
KIT_DIR="$WORKSPACE_DIR/kit"

# ─── Validation ───────────────────────────────────────────────────────────────

if [ -z "$NEW_VERSION" ]; then
    log_error "--new VERSION is required"
    exit 1
fi

if [ ! -d "$KIT_DIR/.git" ] && [ ! -f "$KIT_DIR/.git" ]; then
    log_error "Kit directory not found or not a git repo at $KIT_DIR"
    exit 1
fi

if [ -z "$OLD_VERSION" ]; then
    if [ -f "$WORKSPACE_DIR/.kit-version" ]; then
        OLD_VERSION="$(cat "$WORKSPACE_DIR/.kit-version")"
        log_info "Using .kit-version as old version: $OLD_VERSION"
    else
        log_error "No --old version specified and .kit-version not found."
        log_info "On first sync, specify the previous kit version explicitly with --old."
        exit 1
    fi
fi

if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    log_success "Old and new versions are the same ($OLD_VERSION) — nothing to sync"
    exit 0
fi

# Verify both versions exist in the kit repo
cd "$KIT_DIR"
if ! git rev-parse "$OLD_VERSION" &>/dev/null; then
    log_error "Old version '$OLD_VERSION' not found in kit repo"
    exit 1
fi
if ! git rev-parse "$NEW_VERSION" &>/dev/null; then
    log_error "New version '$NEW_VERSION' not found in kit repo"
    exit 1
fi

# ─── Discover changed template files ─────────────────────────────────────────

log_step "Checking Template Changes ($OLD_VERSION → $NEW_VERSION)"

cd "$KIT_DIR"
CHANGED_FILES=$(git diff --name-only "$OLD_VERSION" "$NEW_VERSION" -- workspace-template/ 2>/dev/null || true)

if [ -z "$CHANGED_FILES" ]; then
    log_success "No workspace-template files changed between versions"
    exit 0
fi

# Strip the workspace-template/ prefix and filter excludes
SYNC_FILES=()
SKIPPED_FILES=()
NEW_FILES=()
DELETED_FILES=()

for full_path in $CHANGED_FILES; do
    file="${full_path#workspace-template/}"

    # Check exclude list
    excluded=false
    for excl in $EXCLUDE_FILES; do
        if [ "$file" = "$excl" ]; then
            excluded=true
            break
        fi
    done
    if $excluded; then
        SKIPPED_FILES+=("$file")
        continue
    fi

    # Classify: new, deleted, or changed
    exists_in_old=$(git cat-file -t "$OLD_VERSION:workspace-template/$file" 2>/dev/null || true)
    exists_in_new=$(git cat-file -t "$NEW_VERSION:workspace-template/$file" 2>/dev/null || true)

    if [ -z "$exists_in_old" ] && [ -n "$exists_in_new" ]; then
        NEW_FILES+=("$file")
    elif [ -n "$exists_in_old" ] && [ -z "$exists_in_new" ]; then
        DELETED_FILES+=("$file")
    else
        SYNC_FILES+=("$file")
    fi
done

total_changes=$(( ${#SYNC_FILES[@]} + ${#NEW_FILES[@]} + ${#DELETED_FILES[@]} ))

echo
log_info "Changed template files: $total_changes syncable, ${#SKIPPED_FILES[@]} excluded"
for f in "${SYNC_FILES[@]+"${SYNC_FILES[@]}"}"; do
    log_info "  modified: $f"
done
for f in "${NEW_FILES[@]+"${NEW_FILES[@]}"}"; do
    log_info "  added:    $f"
done
for f in "${DELETED_FILES[@]+"${DELETED_FILES[@]}"}"; do
    log_info "  deleted:  $f"
done
for f in "${SKIPPED_FILES[@]+"${SKIPPED_FILES[@]}"}"; do
    log_dim "  excluded: $f"
done

if [ "$total_changes" -eq 0 ]; then
    log_success "All changed files are excluded — nothing to sync"
    exit 0
fi

# ─── Discover agent workspaces ───────────────────────────────────────────────

log_step "Discovering Agent Workspaces"

cd "$WORKSPACE_DIR"
AGENTS=()
for dir in */; do
    dir="${dir%/}"
    # Skip non-agent directories
    case "$dir" in
        kit|shared|.git|node_modules) continue ;;
    esac
    if [ -f "$dir/AGENTS.md" ]; then
        AGENTS+=("$dir")
    fi
done

if [ ${#AGENTS[@]} -eq 0 ]; then
    log_warn "No agent workspaces found (looking for dirs with AGENTS.md)"
    exit 0
fi

log_info "Found ${#AGENTS[@]} agent(s): ${AGENTS[*]}"

# ─── Dry-run banner ──────────────────────────────────────────────────────────

if $DRY_RUN; then
    echo
    echo -e "${YELLOW}═══ DRY RUN — no files will be modified ═══${NC}"
fi

# ─── Sync logic ──────────────────────────────────────────────────────────────

TMPDIR_SYNC="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_SYNC"' EXIT

auto_merged=0
conflicts=0
new_copied=0
delete_warned=0
skipped_identical=0
skipped_agent_only=0

merge_file_for_agent() {
    local agent="$1" file="$2"
    local agent_file="$WORKSPACE_DIR/$agent/$file"
    local base_tmp="$TMPDIR_SYNC/base"
    local theirs_tmp="$TMPDIR_SYNC/theirs"
    local ours_tmp="$TMPDIR_SYNC/ours"

    # Agent doesn't have this file — treat like a new file
    if [ ! -f "$agent_file" ]; then
        if $DRY_RUN; then
            log_info "  [$agent] $file — would copy (file missing in agent)"
        else
            mkdir -p "$(dirname "$agent_file")"
            git -C "$KIT_DIR" show "$NEW_VERSION:workspace-template/$file" > "$agent_file"
            log_success "  [$agent] $file — copied (was missing)"
        fi
        new_copied=$((new_copied + 1))
        return
    fi

    # Extract base (old template) and theirs (new template)
    git -C "$KIT_DIR" show "$OLD_VERSION:workspace-template/$file" > "$base_tmp"
    git -C "$KIT_DIR" show "$NEW_VERSION:workspace-template/$file" > "$theirs_tmp"
    cp "$agent_file" "$ours_tmp"

    # If agent file is identical to the new template, skip
    if diff -q "$ours_tmp" "$theirs_tmp" &>/dev/null; then
        log_dim "  [$agent] $file — already matches new template"
        skipped_identical=$((skipped_identical + 1))
        return
    fi

    # If agent file is identical to old template, fast-forward
    if diff -q "$ours_tmp" "$base_tmp" &>/dev/null; then
        if $DRY_RUN; then
            log_info "  [$agent] $file — would fast-forward (agent unchanged)"
        else
            cp "$theirs_tmp" "$agent_file"
            log_success "  [$agent] $file — fast-forwarded"
        fi
        auto_merged=$((auto_merged + 1))
        return
    fi

    # Agent has customizations — three-way merge
    local merge_tmp="$TMPDIR_SYNC/merge"
    cp "$ours_tmp" "$merge_tmp"

    set +e
    git merge-file -L "agent/$agent/$file" -L "template@$OLD_VERSION" -L "template@$NEW_VERSION" \
        "$merge_tmp" "$base_tmp" "$theirs_tmp"
    local merge_rc=$?
    set -e

    if [ "$merge_rc" -eq 0 ]; then
        # Clean merge
        if diff -q "$merge_tmp" "$ours_tmp" &>/dev/null; then
            log_dim "  [$agent] $file — agent changes already incorporate template update"
            skipped_agent_only=$((skipped_agent_only + 1))
            return
        fi
        if $DRY_RUN; then
            log_info "  [$agent] $file — would auto-merge (clean)"
        else
            cp "$merge_tmp" "$agent_file"
            log_success "  [$agent] $file — auto-merged (clean)"
        fi
        auto_merged=$((auto_merged + 1))
    else
        # Conflicts
        if $DRY_RUN; then
            log_warn "  [$agent] $file — would have CONFLICTS (manual resolution needed)"
        else
            cp "$merge_tmp" "$agent_file"
            log_warn "  [$agent] $file — merged with CONFLICTS (look for <<<<<<< markers)"
        fi
        conflicts=$((conflicts + 1))
    fi
}

handle_new_file() {
    local agent="$1" file="$2"
    local agent_file="$WORKSPACE_DIR/$agent/$file"

    if [ -f "$agent_file" ]; then
        log_dim "  [$agent] $file — already exists, skipping"
        skipped_identical=$((skipped_identical + 1))
        return
    fi

    if $DRY_RUN; then
        log_info "  [$agent] $file — would create (new template file)"
    else
        mkdir -p "$(dirname "$agent_file")"
        git -C "$KIT_DIR" show "$NEW_VERSION:workspace-template/$file" > "$agent_file"
        log_success "  [$agent] $file — created (new template file)"
    fi
    new_copied=$((new_copied + 1))
}

handle_deleted_file() {
    local agent="$1" file="$2"
    local agent_file="$WORKSPACE_DIR/$agent/$file"

    if [ ! -f "$agent_file" ]; then
        return
    fi

    log_warn "  [$agent] $file — removed from template (kept in agent, review manually)"
    delete_warned=$((delete_warned + 1))
}

# ─── Process each agent ──────────────────────────────────────────────────────

for agent in "${AGENTS[@]}"; do
    log_step "Syncing: $agent"

    # Determine per-agent base version
    local_old="$OLD_VERSION"
    if [ -f "$WORKSPACE_DIR/$agent/.template-version" ]; then
        local_old="$(cat "$WORKSPACE_DIR/$agent/.template-version")"
        if [ "$local_old" != "$OLD_VERSION" ]; then
            log_info "Using per-agent template version: $local_old (from .template-version)"
        fi
    fi

    for file in "${SYNC_FILES[@]+"${SYNC_FILES[@]}"}"; do
        merge_file_for_agent "$agent" "$file"
    done

    for file in "${NEW_FILES[@]+"${NEW_FILES[@]}"}"; do
        handle_new_file "$agent" "$file"
    done

    for file in "${DELETED_FILES[@]+"${DELETED_FILES[@]}"}"; do
        handle_deleted_file "$agent" "$file"
    done

    # Stamp the new template version
    if ! $DRY_RUN; then
        echo "$NEW_VERSION" > "$WORKSPACE_DIR/$agent/.template-version"
    fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────

log_step "Sync Summary"

action="Applied"
$DRY_RUN && action="Would apply"

log_info "$action to ${#AGENTS[@]} agent(s):"
[ "$auto_merged" -gt 0 ]      && log_success "  $auto_merged file(s) merged cleanly"
[ "$new_copied" -gt 0 ]       && log_success "  $new_copied new file(s) copied"
[ "$skipped_identical" -gt 0 ] && log_dim "  $skipped_identical file(s) already up to date"
[ "$skipped_agent_only" -gt 0 ] && log_dim "  $skipped_agent_only file(s) — agent changes already cover template update"
[ "$delete_warned" -gt 0 ]    && log_warn "  $delete_warned file(s) removed from template (kept, review manually)"
[ "$conflicts" -gt 0 ]        && log_warn "  $conflicts file(s) with CONFLICTS — search for <<<<<<< markers"

if [ "$conflicts" -gt 0 ]; then
    echo
    log_warn "Resolve conflicts before committing. Search with:"
    log_info "  grep -rn '<<<<<<' ${AGENTS[*]}"
    exit 1
fi
