# Decisions

Record decisions so every AI can continue from the same place.

## Decision template

### YYYY-MM-DD — Decision title

- Decision:
- Why:
- Evidence:
- Alternatives considered:
- Revisit when:

## Decisions

### 2026-10-14 — Shared AI project memory

- Decision: Use this private GitHub repository as the shared source of truth.
- Why: Claude, Gemini, and ChatGPT do not share one automatic live memory.
- Revisit when: A better synchronized workspace is deliberately chosen.

### 2026-10-14 — Tool roles

- Decision: Claude Pro builds and codes; Gemini Pro researches; ChatGPT Free critiques and compares.
- Why: This matches the subscriptions currently available.
- Revisit when: Usage limits, quality, or workflow needs change.

### 2026-10-16 — MCP install order

- Decision: Install the official Roblox Studio MCP first, then one reviewed Roblox skill set, then Blender with `mcp-for-blender`. Add Fetch and Playwright only when a task needs them.
- Why: Roblox is the core work, and the official plugin is first-party. GitHub is already connected in the Claude project. Each extra MCP adds access and risk.
- Evidence: Setup audit in `CURRENT_STATE.md` (2026-10-16).
- Alternatives considered: Filesystem or Memory first. They are not needed while the repository is the memory.
- Revisit when: The Roblox plugin is working, or a task needs a different tool.

### 2026-10-16 — First opportunity to test (superseded by the next entry)

- Decision: Test low-poly model packs on the Roblox Creator Store first. Pause paid scripting help and beginner education.
- Why: Uses the Blender skill, costs nothing, and the store brings buyers without an audience. Paid scripting needs stronger Luau skill than AI-assisted coding.
- Evidence: Roblox Creator Store and DevEx docs (2026-10-16, `RESEARCH.md`). No demand evidence yet.
- Alternatives considered: scripting services, education, a money-focused Roblox game (DevEx needs 30,000 earned Robux).
- Revisit when: the 14-day free-model test ends, or when the state of Steal a Meme and Rogue Tamer is recorded (a game near a playable test may deserve priority).
- Update 2026-10-16: user is 18 and lives in Spain, so USD selling on the Creator Store is allowed.

### 2026-10-16 — Publish Steal a Meme first (superseded by the next entry)

- Decision: Finish and publish Steal a Meme before more work on Rogue Tamer or a third game. Model packs become an optional side test.
- Why: The user's own project summaries show Steal a Meme has a complete core loop, while Rogue Tamer is very large for one person. The user also said he does not want to sell beginner-level work, so scarce hours go to the game that is closest to real data. Spreading across three games, trading, tutoring, studies and a channel is the main risk.
- Evidence: `docs/games/steal-a-meme-summary.txt`, `docs/games/rogue-tamer-summary.txt`, summary of past chats provided by the user (2026-10-16). No player or revenue data yet.
- Alternatives considered: Rogue Tamer first (more exciting to the user but much larger), model packs first (see previous entry).
- Revisit when: Steal a Meme has two weeks of analytics, or the user decides otherwise.

### 2026-10-16 — Continue Rogue Tamer, keep Steal a Meme private

- Decision: The user keeps Steal a Meme private and continues Rogue Tamer.
- Why: The user judges the Steal a Brainrot-style market over-exploited, with few games reaching that level. This matches the user's own earlier research (many short-lived clones, at least 4 lawsuits from the original's creators).
- Evidence: User's statement (2026-10-16); `docs/games/steal-a-meme-summary.txt`.
- Alternatives considered: Launching Steal a Meme first (earlier recommendation by Claude).
- Risks to watch: Rogue Tamer's scope is very large for one person, turn-based play is less sticky on Roblox, and it resembles Pokémon. No player data exists for it yet.
- Revisit when: Rogue Tamer has real-player retention data, or if scope keeps growing without testers.

### 2026-10-16 — Incremental game factory waits for Rogue Tamer

- Decision: Until Rogue Tamer's closed test, the reusable incremental-game factory stays in `IDEAS.md`. No factory code is built before then.
- Why: Building a factory before the first incremental game ships is over-engineering, and splitting time between two large projects is the main risk already noted.
- Evidence: Audit in `docs/AUDIT_2026-10-16.md`. No player data for Rogue Tamer or any incremental game yet.
- Alternatives considered: Pause Rogue Tamer and build incremental game 1 first.
- Revisit when: Rogue Tamer's closed test has retention data.

### 2026-10-16 — Merge overlapping skills

- Decision: Merge `caveman-mode`, `model-router`, `subagent-gate`, and `research-budget` into `cheap-direct-mode`. Keep `session-handoff` and `blender-pixel-art`.
- Why: The five skills repeated each other and `CLAUDE.md`; each skill description costs tokens every session. A skill cannot switch models, so `model-router` was misleading.
- Revisit when: A missing behaviour shows up in practice.
