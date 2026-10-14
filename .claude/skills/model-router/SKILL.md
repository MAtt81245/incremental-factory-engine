---
name: model-router
description: Route work to the cheapest adequate model and effort level. Use low effort for simple work, medium effort for normal work, and high effort only for difficult or high-risk tasks.
---

# Model Router

## Purpose

Save Claude usage by sending the right work to the right effort level and model.

## Routing rules

### Low effort / lightweight model

Use for:

- Summaries
- Basic rewrite
- Simple code questions
- Simple bug triage
- File naming
- Formatting
- Basic brainstorming
- Short replies

### Medium effort / normal model

Use for:

- Most Roblox scripting work
- Small architecture reviews
- Moderate research synthesis
- Game-idea critique
- Opportunity analysis
- Business-plan drafting

### High effort / strong model

Use for:

- Hard bugs
- Security issues
- Economy and DataStore risk
- Complex architecture
- Final review of a launch plan
- Important business decisions

## Important behavior

- Do not use maximum effort by default.
- Do not use subagents for trivial tasks.
- Do not browse for stable facts if the answer is already known.
- Do not keep reasoning after the answer is good enough.
- If a task is clearly simple, answer directly and stop.

## Good routing policy

- Use the cheapest model that can do the task correctly.
- Keep most work at normal effort instead of high effort.
- Reserve strong reasoning for difficult tasks.
