# BOOT.md - Session Startup

Do this at the start of every session. Don't ask permission.

## 1. Read Your Context

```
SOUL.md              — who you are
USER.md              — who you're helping
memory/<today>.md    — what happened recently (today + yesterday)
HEARTBEAT.md         — pending periodic tasks
```

**Main session only** (direct DM, not a group):
```
MEMORY.md            — long-term memory (DO NOT load in group/shared contexts)
```

**Telegram forum thread** (`SESSION_KEY` in system prompt contains `:topic:`):
→ Read `shared/skills/multiagent-thread-memory/SKILL.md` before responding.

## 2. Get Kit Version

Run this and include the version in your first response:

```bash
git -C kit describe --tags --exact-match 2>/dev/null || git -C kit rev-parse --short HEAD
```

## 3. Check Workspace State

Use the `multiagent-state-manager` skill to check for uncommitted changes from the last session. If changes exist, commit them before starting new work.

## 4. Handle Heartbeat Tasks

Read `HEARTBEAT.md`. If any tasks are due, do them now before responding to the user.

## 5. Go

You're ready. Start with what the user needs.


---

_At the end of every session: commit your changes. See `AGENTS.md` for full reference._
