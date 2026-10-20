# Current State

## Main objective

Find and test a realistic opportunity connected to Roblox, game development, AI, research, content, or services.

## Current best opportunity

Continue **Rogue Tamer** (user decision, 2026-10-16). Steal a Meme stays private: the user judges the Steal a Brainrot-style market over-exploited, with few games reaching that level. Not proven to make money. Low-poly model packs remain an optional side test.

## Games in development (summaries in `docs/games/`)

- **Steal a Meme** (Steal a Brainrot-style) — core loop is playable end to end; a new "forest mode" (99 Nights + tower defense) is built but switched off (`ForestMap.Active = false`). Before launch: real PassId/ProductId values (all 0, so no Robux comes in), remove or limit two fixed admin accounts, three failing sounds, test with real players and on mobile. **Private** (confirmed by the user, 2026-10-16); not being launched for now.
- **Rogue Tamer** (PokéRogue-style, "Critter Rogue" place) — far larger than a prototype: 100 creatures, 34 biomes, 372 moves, many modes and systems. Missing: 14 special-form sprites, 11 icons, English translation, remove `DEV_UNLOCK_ALL`, real Premium Pass IDs. Open risks: huge scope, turn-based play is less sticky on Roblox, resemblance to Pokémon.
- **Pure Incremental Factory Engine** (`games/incremental-factory/`, built 2026-10-20). This is a reusable, config-driven incremental engine (Argon) with a greybox test zone. It passes the type-check and a mocked simulation, but has not been tested in Studio. Missing: real product and gamepass IDs (all 0), and balancing with players.
- A third idea (zombie survival, Project Zomboid-style) was only mentioned on 2026-10-13. Not started.

## Strongest money-making ideas

1. Rogue Tamer: get a limited release in front of real players to measure retention (long-term, uncertain).
2. Already earning a little: online English tutoring (Mon/Thu, monthly invoicing). Possible extra: maths/physics/chemistry on Superprof.
3. Optional side test: low-poly Blender model packs on the Creator Store (zero cost; no demand evidence yet).
4. AI trading is a 5–10 € experiment only, not an income plan.

## Evidence collected

- Creator Store and DevEx rules checked on 2026-10-16 (see `RESEARCH.md`). No demand evidence yet.

## Decisions

- Use this repository as shared memory between Claude, Gemini, and ChatGPT.
- Use Claude Pro as the primary builder.
- Use Gemini Pro for broad/current research.
- Use ChatGPT Free for independent critique.

## Setup (summary — details in `docs/SETUP_LOG.md`, status in `docs/MCP_PLAN.md`)

- Active: official Roblox Studio MCP on the PC (verified 2026-10-16); GitHub, Google Drive and Claude Docs in the cloud.
- Skills: repository = `cheap-direct-mode`, `session-handoff`, `blender-pixel-art`; PC = `token-efficiency` (with hooks) plus those bundled with the Roblox MCP.
- Postponed: Blender MCP, Playwright. Not recommended: Filesystem, Fetch, Git, Memory, Sequential Thinking.
- Pending for the user: disable `mcpmarket-me` in claude.ai too; turn off Gmail, Notion, Indeed and Calendar connectors for Roblox sessions.

## Key risks (audit 2026-10-16, `docs/AUDIT_2026-10-16.md`)

- Game code is not version-controlled; it lives only in Studio. Save/publish before any MCP edit.
- Gemini/Vertex AI credits expire 2027-01-03; Rogue Tamer still needs ~44 sprites.
- Rogue Tamer reuses near-literal Pokémon names (Mega, Gigamax, Tera, item names). Rename before any public release.

## Open questions

- When will Rogue Tamer get its first real players (closed test or limited release)? The incremental factory waits for this (`DECISIONS.md`).
- Will recurring income (Roblox, tutoring) require registering as self-employed (autónomo)? Decide before the first payout.
- Which kind of low-poly model is most used on the Creator Store (only if the side test continues)?
- Which customer group is easiest to reach?
- Which problem has evidence of willingness to pay?

## Next action

Choose the smallest Rogue Tamer release that real players can try (for example a closed test with friends), fix its launch blockers (remove `DEV_UNLOCK_ALL`, set real Premium Pass IDs, translate new text to English), and measure retention before adding more systems.
