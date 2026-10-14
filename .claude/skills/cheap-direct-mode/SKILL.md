---
name: cheap-direct-mode
description: Use for routine questions, simple planning, summaries, basic Roblox tasks, and ordinary research. Keep answers direct, short, and appropriately scoped. Use low effort when possible and avoid repeated context, unnecessary tools, and overthinking.
---

# Cheap Direct Mode

## Default

- Answer the actual question first.
- Use plain language and short bullets.
- Do not repeat the user's question or project history.
- Do not add motivational filler.
- Do not give multiple versions unless requested.
- Usually keep routine answers under 300 words.
- Ask at most one clarification question when a reasonable assumption is possible.
- If the request is clear, proceed.

## Effort routing

Use low effort and no subagents for:

- Definitions
- Summaries
- Rewrites
- Formatting
- Simple comparisons
- Basic brainstorming
- Straightforward Roblox questions
- Small file edits

Use normal effort for:

- Roblox gameplay systems
- Game-design reviews
- Opportunity analysis
- Market research synthesis
- Pricing and validation plans
- Multi-file changes

Use high effort only for:

- Difficult bugs
- Architecture and security
- DataStores and economy correctness
- High-stakes or complex current research
- Final review of an important launch decision

## Tool and research discipline

- Do not browse unless the answer depends on current information.
- Use a few strong sources instead of many weak sources.
- Do not research the same question twice without a reason.
- Inspect only relevant files.
- Do not reread unchanged files just to confirm a successful edit.
- Batch independent work.
- Stop when the requested result is complete.

## Accuracy guardrails

Never remove necessary safety, correctness, source, or uncertainty information just to be brief. Label facts, estimates, inferences, opinions, and unknowns when discussing business opportunities.

## Caveman mode

If the user says `caveman mode`, respond with only:

1. The answer.
2. The next action.
3. One important warning, if needed.

Use short sentences. No background explanation.

## Long-session handoff

When a session becomes large or work is paused, create a compact handoff with the objective, completed work, files changed, decisions, open questions, risks, and exact next action. Save it to the appropriate repository file when possible.
