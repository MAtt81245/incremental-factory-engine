# Current State

## Main objective

Find and test a realistic opportunity connected to Roblox, game development, AI, research, content, or services.

## Current best opportunity

Continue **Rogue Tamer** (user decision, 2026-10-16). Steal a Meme stays private: the user judges the Steal a Brainrot-style market over-exploited, with few games reaching that level. Not proven to make money. Low-poly model packs remain an optional side test.

## Games in development (summaries in `docs/games/`)

- **Steal a Meme** (Steal a Brainrot-style) — core loop is playable end to end; a new "forest mode" (99 Nights + tower defense) is built but switched off (`ForestMap.Active = false`). Before launch: real PassId/ProductId values (all 0, so no Robux comes in), remove or limit two fixed admin accounts, three failing sounds, test with real players and on mobile. **Private** (confirmed by the user, 2026-10-16); not being launched for now.
- **Rogue Tamer** (PokéRogue-style, "Critter Rogue" place) — far larger than a prototype: 100 creatures, 34 biomes, 372 moves, many modes and systems. Missing: 14 special-form sprites, 11 icons, English translation, remove `DEV_UNLOCK_ALL`, real Premium Pass IDs. Open risks: huge scope, turn-based play is less sticky on Roblox, resemblance to Pokémon.
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

## Setup audit (2026-10-16)

- Fact: `USER_PROFILE.md` was filled in on 2026-10-16 and the game summaries were added in `docs/games/`.
- Fact: the Claude project (cloud) already has GitHub (this repository only), Gmail, Google Calendar, Google Drive, Notion, Indeed and Claude Docs connected. `mcpmarket-me` failed to connect (proxy 403).
- Fact: Roblox Studio, Blender, Filesystem, Fetch, Playwright and Memory MCPs must be installed in local Claude Code on the user's PC; a cloud session cannot reach them.
- Fixed: Blender MCP docs now use `mcp-for-blender` (ahujasid), `docs/mcp.example.json` is valid JSON, `claude mcp add` commands use `--`, the blender-pixel-art skill header loads, and market-skills no longer lives in `/tmp`.
- Fact (PC check, 2026-10-16): the official Roblox Studio MCP is already installed and connected (desktop extension `Roblox_Studio`, 30 tools, includes skills). Not yet tested with Studio open; Studio was updating. Do not add a second Roblox MCP.
- Fact: the `mcpmarket-me` plugin's MCP fails with 401 (invalid token). Disabled on 2026-10-16 at the user's request (not deleted): `enabledPlugins` set to false in the user's `~/.claude/settings.json`, with a backup at `~/.claude/settings.json.bak-2026-10-16`. To re-enable, set it back to true or use Settings > Plugins.
- Fact: Blender MCP is postponed by the user. When wanted: `winget install --id astral-sh.uv -e`, `winget install --id BlenderFoundation.Blender -e`, `uvx mcp-for-blender setup`, then a one-cube test in a new scene.
- Fact: Fetch and Playwright are not installed (not needed now). The PC has winget, Node and Python 3.14; it lacks uv, gh and Blender.
- Installed on the PC (2026-10-16, new Claude sessions pick them up):
  - Skill `token-efficiency` from `denfry/claude-skills` pinned to commit `cc73299f5d9e5c1a800cf65015093bd527faf0e5`, in `~/.claude/skills/token-efficiency`, with its 4 hooks (session start, each message, after tools, stop) added by `hooks/install.py`. Backup: `settings.json.bak`. Remove hooks only: `python ~/.claude/skills/token-efficiency/hooks/install.py --uninstall`.
  - MCP `sequential-thinking` (official, `@modelcontextprotocol/server-sequential-thinking@2026.8.31`), scope user, connected. Remove: `claude mcp remove sequential-thinking -s user`.
- Pending: open Studio with a copy of the place and run a read-only connection check.
- Unknown: the GitHub repositories in `docs/INSTALL.md` (Roblox plugin and third-party skills) could not be opened from the cloud session; check each one before installing.

## Open questions

- When will Rogue Tamer get its first real players (closed test or limited release)?
- Will recurring income (Roblox, tutoring) require registering as self-employed (autónomo)? Decide before the first payout.
- Which kind of low-poly model is most used on the Creator Store (only if the side test continues)?
- Which customer group is easiest to reach?
- Which problem has evidence of willingness to pay?

## Next action

Choose the smallest Rogue Tamer release that real players can try (for example a closed test with friends), fix its launch blockers (remove `DEV_UNLOCK_ALL`, set real Premium Pass IDs, translate new text to English), and measure retention before adding more systems.
