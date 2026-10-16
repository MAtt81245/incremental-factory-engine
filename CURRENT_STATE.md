# Current State

## Main objective

Find and test a realistic opportunity connected to Roblox, game development, AI, research, content, or services.

## Current best opportunity

Not decided yet.

## Strongest game ideas

- None recorded yet.

## Strongest money-making ideas

- None recorded yet.

## Evidence collected

- None recorded yet.

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

- What skills and time are available?
- Which customer group is easiest to reach?
- Which problem has evidence of willingness to pay?

## Next action

Complete `USER_PROFILE.md`. Then, on the PC: save a copy of the Roblox place, install the official Roblox Studio plugin, and check it with `/mcp`. After that, ask Gemini to research customer questions and existing paid solutions related to Roblox development or another chosen interest.
