---
name: subagent-gate
description: Prevent unnecessary delegation. Use subagents only when a task truly benefits from parallel work or separate analysis; otherwise handle it directly to save tokens and context.
---

# Subagent Gate

## Default rule

Do the work directly unless the task clearly benefits from a separate subagent.

## Use a subagent only when:

- There are 2 or more truly independent tasks.
- The task requires parallel exploration in separate areas.
- There is a difficult bug needing isolated investigation.
- A separate review or one-off analysis is useful.

## Do not use a subagent for:

- A single simple question
- A small change
- A direct error fix
- A summary
- A formatting pass
- A short research comparison
- Normal brainstorming

## Goal

Keep the workflow efficient. Shorter, direct execution saves tokens and avoids unneeded context duplication.
