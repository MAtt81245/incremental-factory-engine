# Current State

## Main objective

Find and test a realistic opportunity connected to Roblox, game development, AI, research, content, or services.

## Current best opportunity

Publish **Steal a Meme** first, to learn publishing and read analytics, before going deeper on the second game (see `DECISIONS.md`, 2026-10-16). Not proven to make money. Low-poly model packs for the Creator Store are an optional side test, not the main plan.

## Games in development (summaries in `docs/games/`)

- **Steal a Meme** (Steal a Brainrot-style) — core loop is playable end to end; a new "forest mode" (99 Nights + tower defense) is built but switched off (`ForestMap.Active = false`). Before launch: real PassId/ProductId values (all 0, so no Robux comes in), remove or limit two fixed admin accounts, three failing sounds, test with real players and on mobile. Unclear if it is private or published with a few hundred players (notes conflict).
- **Rogue Tamer** (PokéRogue-style, "Critter Rogue" place) — far larger than a prototype: 100 creatures, 34 biomes, 372 moves, many modes and systems. Missing: 14 special-form sprites, 11 icons, English translation, remove `DEV_UNLOCK_ALL`, real Premium Pass IDs. Open risks: huge scope, turn-based play is less sticky on Roblox, resemblance to Pokémon.
- A third idea (zombie survival, Project Zomboid-style) was only mentioned on 2026-10-13. Not started.

## Strongest money-making ideas

1. Launch Steal a Meme and learn from real analytics (long-term, uncertain).
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

## Setup audit (2026-10-16)

- Fact: `USER_PROFILE.md` was filled in on 2026-10-16 and the game summaries were added in `docs/games/`.
- Fact: the Claude project (cloud) already has GitHub (this repository only), Gmail, Google Calendar, Google Drive, Notion, Indeed and Claude Docs connected. `mcpmarket-me` failed to connect (proxy 403).
- Fact: Roblox Studio, Blender, Filesystem, Fetch, Playwright and Memory MCPs must be installed in local Claude Code on the user's PC; a cloud session cannot reach them.
- Fixed: Blender MCP docs now use `mcp-for-blender` (ahujasid), `docs/mcp.example.json` is valid JSON, `claude mcp add` commands use `--`, the blender-pixel-art skill header loads, and market-skills no longer lives in `/tmp`.
- Unknown: the GitHub repositories in `docs/INSTALL.md` (Roblox plugin and third-party skills) could not be opened from the cloud session; check each one before installing.

## Open questions

- Is Steal a Meme published or private, and how many unique players does it have?
- Will recurring income (Roblox, tutoring) require registering as self-employed (autónomo)? Decide before the first payout.
- Which kind of low-poly model is most used on the Creator Store (only if the side test continues)?
- Which customer group is easiest to reach?
- Which problem has evidence of willingness to pay?

## Next action

Finish the launch blockers for Steal a Meme (real product IDs, admin accounts, sounds), test with real players and on mobile, and publish with minimal visuals. Keep Rogue Tamer scope frozen until Steal a Meme has analytics.
