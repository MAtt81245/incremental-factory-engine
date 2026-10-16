# Current State

## Main objective

Find and test a realistic opportunity connected to Roblox, game development, AI, research, content, or services.

## Current best opportunity

Low-poly Blender models for the Roblox Creator Store (see `IDEAS.md` and `DECISIONS.md`, 2026-10-16). Status: testing demand with free models first. Not proven to make money.

## Strongest game ideas

- None recorded yet. A tiny Roblox game is kept as a learning and portfolio project, not as an income plan.

## Strongest money-making ideas

1. Low-poly model packs on the Roblox Creator Store (uses Blender skill, zero cost, built-in store traffic).
2. Later: faceless content showing the Blender-to-Roblox process, to drive traffic to the models.
3. Later: paid Roblox scripting help, only after real, tested Luau skill.

## Evidence collected

- Creator Store and DevEx rules checked on 2026-10-16 (see `RESEARCH.md`). No demand evidence yet.

## Decisions

- Use this repository as shared memory between Claude, Gemini, and ChatGPT.
- Use Claude Pro as the primary builder.
- Use Gemini Pro for broad/current research.
- Use ChatGPT Free for independent critique.

## Setup audit (2026-10-16)

- Fact: the profile and constraints in `USER_PROFILE.md` and `PROJECT_CONTEXT.md` are still all `TODO`; this blocks choosing an opportunity.
- Fact: the Claude project (cloud) already has GitHub (this repository only), Gmail, Google Calendar, Google Drive, Notion, Indeed and Claude Docs connected. `mcpmarket-me` failed to connect (proxy 403).
- Fact: Roblox Studio, Blender, Filesystem, Fetch, Playwright and Memory MCPs must be installed in local Claude Code on the user's PC; a cloud session cannot reach them.
- Fixed: Blender MCP docs now use `mcp-for-blender` (ahujasid), `docs/mcp.example.json` is valid JSON, `claude mcp add` commands use `--`, the blender-pixel-art skill header loads, and market-skills no longer lives in `/tmp`.
- Unknown: the GitHub repositories in `docs/INSTALL.md` (Roblox plugin and third-party skills) could not be opened from the cloud session; check each one before installing.

## Open questions

- Age and country: needed to know if USD selling (18+, or 13–17 with a parent) and Stripe payouts are possible.
- Which kind of low-poly model is most used on the Creator Store?
- Which customer group is easiest to reach?
- Which problem has evidence of willingness to pay?

## Next action

Make one simple low-poly prop in Blender, import it into Roblox Studio, and publish it free on the Creator Store. Then make two more and record installs and favourites after 14 days.
