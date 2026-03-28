# BOOT.md - Session Startup

Do this at the start of every session. Don't ask permission.

## 1. Detect Session Type

Check your system prompt for `SESSION_KEY`. This determines what memory to load.

- **No `SESSION_KEY`**, or key does NOT contain `:topic:` → **Main session.** Load `MEMORY.md`.
- **`SESSION_KEY` contains `:topic:`** → **Forum thread session.** Read `shared/skills/multiagent-thread-memory/SKILL.md` NOW and follow its protocol. Do NOT load `MEMORY.md`.

This is not optional. Check every session.

## 2. Read Your Context

```
SOUL.md              — who you are
USER.md              — who you're helping
memory/<today>.md    — what happened recently (today + yesterday)
HEARTBEAT.md         — pending periodic tasks
```

**Main session only** (from step 1):
```
MEMORY.md            — long-term memory (DO NOT load in group/shared contexts)
```

## 3. Kit Version

Read `.kit-version` in your workspace root and include it in your first response.

## 4. Check Workspace State

Use the `multiagent-state-manager` skill to check for uncommitted changes from the last session. If changes exist, commit them before starting new work.

## 5. Handle Heartbeat Tasks

Read `HEARTBEAT.md`. If any tasks are due, do them now before responding to the user.

## 6. Go

You're ready. Start with what the user needs.


---

_At the end of every session: commit your changes. See `AGENTS.md` for full reference._
