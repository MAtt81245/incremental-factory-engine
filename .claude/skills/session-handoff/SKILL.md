---
name: session-handoff
description: Preserve context across long sessions by creating a short project handoff when work is paused or the conversation is getting long.
---

# Session Handoff

## Purpose

Keep context compact and reusable without repeating the whole session history.

## Handoff format

Write a brief Markdown summary including:

1. Objective
2. Completed work
3. Files changed
4. Decisions made
5. Important facts and links
6. Open questions
7. Risks or errors
8. Exact next action

## Save target

Prefer saving to:

- `CURRENT_STATE.md`
- `RESEARCH.md`
- `DECISIONS.md`
- `IDEAS.md`

## Use when

- The conversation is getting long.
- The task is paused.
- The user asks to continue later.
- The context is getting too large for the next message.

## Default rule

Do not repeat the whole conversation. Do a compact handoff.
