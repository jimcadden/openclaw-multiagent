# BOOT.md - Session Startup

Do this at the start of every session. Don't ask permission.

## 1. Read Your Context

```
SOUL.md          — who you are
USER.md          — who you're helping
memory/<today>.md    — what happened recently (today + yesterday)
MEMORY.md        — long-term memory (main session only, not group chats)
HEARTBEAT.md     — pending periodic tasks
```

## 2. Check Workspace State

Use the `multiagent-state-manager` skill to check for uncommitted changes from the last session. If changes exist, commit them before starting new work.

## 3. Handle Heartbeat Tasks

Read `HEARTBEAT.md`. If any tasks are due, do them now before responding to the user.

## 4. Go

You're ready. Start with what the user needs.

---

_At the end of every session: commit your changes. See `AGENTS.md` for full reference._
