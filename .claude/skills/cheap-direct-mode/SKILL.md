---
name: cheap-direct-mode
description: Default working style for this repository. Use for routine questions, planning, summaries, Roblox tasks, and research. Also covers "caveman" / "be brief" requests, effort selection, when to use subagents, and research budget. Keep answers direct and scoped; avoid repeated context, unnecessary tools, and overthinking.
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

## Caveman mode

Triggers: `caveman`, `caveman mode`, `be brief`, `short answer`, `no explanation`, `quick answer`.

Respond with only:

1. The answer.
2. The next action.
3. One important warning, if needed.

Short sentences. No background, no options unless asked. Never infer business viability without evidence.

## Effort routing

A skill cannot switch models. Pick the effort level; the user picks the model.

Low effort, no subagents:

- Definitions, summaries, rewrites, formatting
- Simple comparisons and basic brainstorming
- Straightforward Roblox questions and small file edits

Normal effort:

- Roblox gameplay systems and most Luau work
- Game-design reviews and opportunity analysis
- Market research synthesis, pricing and validation plans
- Multi-file changes

High effort only for:

- Difficult bugs, architecture, and security
- DataStores and economy correctness
- High-stakes or complex current research
- Final review of an important launch decision

Stop reasoning once the answer is good enough.

## Subagents

Work directly by default. Use a subagent only when there are 2+ truly independent tasks, parallel exploration in separate areas, a hard bug needing isolated investigation, or a useful separate review. Never for a single question, small change, direct fix, summary, or formatting pass.

## Research budget

- Check `RESEARCH.md` before researching again.
- Do not browse unless the answer depends on current information.
- Use 3–5 strong sources; stop when the answer is supported.
- For money research: check demand evidence, existing paid alternatives, substitutes, startup cost, and time to first revenue. Never call an idea profitable without evidence.

## Tool discipline

- Inspect only relevant files.
- Do not reread unchanged files just to confirm a successful edit.
- Batch independent work.
- Stop when the requested result is complete.

## Accuracy guardrails

Never remove necessary safety, correctness, source, or uncertainty information just to be brief. Label facts, estimates, inferences, opinions, and unknowns when discussing business opportunities.

## Long sessions

Use the `session-handoff` skill when a session gets long or work is paused.
