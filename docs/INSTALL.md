# Installation Guide

This guide lists the recommended tools discussed in the plan. Install only what you need; overlapping plugins can create duplicate tools.

## 1. Claude Code basics

Install Claude Code using Anthropic's current instructions:

- Documentation: https://docs.anthropic.com/en/docs/claude-code/overview
- Skills documentation: https://docs.anthropic.com/en/docs/claude-code/skills
- MCP documentation: https://docs.anthropic.com/en/docs/claude-code/mcp

These links were written for docs.anthropic.com; Claude Code docs may now redirect to https://code.claude.com/docs. Follow the redirect if a link moves.

Project skills are stored in `.claude/skills/`. User-level skills normally go in `~/.claude/skills/`.

## 2. Official Roblox Studio connection — install first

Repository: https://github.com/Roblox/roblox-studio-agent-plugin

In Claude Code:

```text
/plugin
```

Search for **Roblox Studio** and install it. Then ask Claude Code:

```text
Get me set up with Roblox Studio.
```

Verify the connection:

```text
/mcp
```

Do not add a second Roblox Studio MCP server until you understand which one is active.

## 3. Roblox and game-design skills

### AshExplained Roblox skills

Repository: https://github.com/AshExplained/roblox-skills

```bash
git clone https://github.com/AshExplained/roblox-skills.git ~/.claude/skills/roblox-skills
```

### Bloxlab

Repository: https://github.com/imhugiok/bloxlab

```text
/plugin marketplace add imhugiok/bloxlab
/plugin install bloxlab@bloxlab
/reload-plugins
```

### Game ideas

Review the current repository instructions before installing third-party idea packs. The local `cheap-direct-mode` and idea-review guidance are already included in this repository.

## 4. Money and opportunity research

### Build-DNA

Repository: https://github.com/Sudiddii/build-DNA

```bash
git clone https://github.com/Sudiddii/build-DNA.git ~/.claude/skills/build-dna
```

### Market skills

Repository: https://github.com/trinity-ai-labs/market-skills

```bash
git clone https://github.com/trinity-ai-labs/market-skills.git ~/.claude/vendor/market-skills
mkdir -p ~/.claude/skills
ln -s ~/.claude/vendor/market-skills/skills/market-analysis ~/.claude/skills/market-analysis
ln -s ~/.claude/vendor/market-skills/skills/business-plan ~/.claude/skills/business-plan
```

## 5. Reduce Claude usage

The repository already contains:

```text
.claude/skills/cheap-direct-mode/   (also covers caveman mode, effort, subagents, research budget)
.claude/skills/session-handoff/
```

Third-party `token-efficiency` skill: **already installed on the PC** (2026-10-16), pinned to commit `cc73299f5d9e5c1a800cf65015093bd527faf0e5`, with hooks. Details and uninstall command in `docs/SETUP_LOG.md`. To reinstall on another machine, clone to a permanent folder (not `/tmp`), check out that commit, and review `hooks/install.py` before running it.

These instructions can reduce wasted output and context, but cannot increase a plan's quota.

## 5b. Roblox code toolchain — planned (phase 2, not installed)

Goal: keep Luau code in git instead of only inside Studio places, so it can be backed up, reviewed, and reused across games.

- Rokit (toolchain manager): https://github.com/rojo-rbx/rokit
- Rojo (sync files ↔ Studio, plus its Studio plugin): https://rojo.space/docs
- StyLua (formatter): https://github.com/JohnnyMorganz/StyLua
- selene (linter): https://github.com/Kampfkarren/selene
- Git for Windows if missing: https://git-scm.com/download/win

Install only after reading each project's current README. Start with Rogue Tamer or the incremental kit, one place at a time, and keep a published copy of the place before the first sync.

## 6. Blender

Download Blender from the official site:

```text
https://www.blender.org/download/
```

Use the current stable release for normal work. Save a copy of important `.blend` files before connecting an AI.

## 7. Blender MCP for Claude Code

Project: https://github.com/ahujasid/blender-mcp

Its PyPI package was renamed from `blender-mcp` to `mcp-for-blender` (checked on PyPI on 2026-10-16, version 2.1.9). The old name still works but new installs should use the new one. Note: the `blender-mcp` PyPI package is **not** `josuemontano/blender-mcp`; do not mix the two projects' instructions.

### Install `uv`

The setup command needs `uv`: https://docs.astral.sh/uv/getting-started/installation/

### Set up

Read the project's README first. Then, with `uv` installed:

```bash
uvx mcp-for-blender setup
```

It detects Claude Code and other MCP clients, lets you choose which to configure, adds a `blender` entry (keeping a `.bak` of each changed config file), and installs and enables the Blender add-on. Prefer this over the project's `curl … | sh` one-liner, which runs a remote script without letting you inspect it first.

Fully quit and reopen Claude Code afterwards.

If the add-on is not already running, in Blender:

```text
Edit → Preferences → Add-ons → enable Interface: Blender MCP
3D Viewport → N → BlenderMCP → Start MCP Server
```

Verify in Claude Code:

```text
/mcp
```

Test safely:

```text
Check the Blender connection. In a new scene, create one cube, one camera,
and one light. Do not modify any other files.
```

Only run one Blender MCP server at once. The server is community software; inspect the repository and install scripts before using them.

## 8. Blender asset sources

### Blendkit / BlenderKit

Official add-on repository: https://github.com/BlenderKit/Blendkit

It integrates an asset library into Blender. Install the add-on through Blender's Preferences → Add-ons → Install, then enable it. Some assets are free and the service also has paid content; check each asset's license.

### Poly Haven

Website: https://polyhaven.com/

License: https://polyhaven.com/license

Poly Haven states that its HDRIs, textures, and models are CC0 and usable commercially. Still keep a record of the source for your own asset log.

### Kenney

Website: https://kenney.nl/assets

License/support: https://kenney.nl/support

Kenney states that its game assets are CC0, including commercial use. Check the asset page and included license file.

### Roblox Creator Store

Documentation: https://create.roblox.com/docs/production/creator-store

Use it for Roblox models, plugins, meshes, decals, UI, and audio. Review third-party models carefully, especially scripts, and check permissions before redistributing anything.

## 9. Pixel-art editors

### LibreSprite

Repository: https://github.com/LibreSprite/LibreSprite

Free/open-source option for pixel cleanup and animation.

### Aseprite

Website: https://www.aseprite.org/

Paid option designed for pixel art, animation, palettes, and sprite sheets.

## 10. Recommended order

Done (2026-10-16): `USER_PROFILE.md`, project skills, official Roblox Studio plugin (verified), `token-efficiency`.

Next, only when the phase needs it (see `docs/AUDIT_2026-10-16.md` §11):

1. Phase 2 — Git + Rokit/Rojo/StyLua/selene (§5b).
2. Phase 3 — Pillow (`pip install pillow`) for sprite post-processing; LibreSprite for occasional cleanup.
3. Phase 7 — Blender, test it by hand, then uv + `mcp-for-blender` and the one-cube test.

Not planned: third-party Roblox skill sets (§3) — the official Roblox MCP already bundles skills; add one only after reviewing it and if a gap appears.

Record each install in `docs/SETUP_LOG.md` and update `docs/MCP_PLAN.md`.

## Safety

- Review third-party skills and scripts before installing them.
- Save or publish a Roblox place before allowing an agent to make large changes.
- Keep this repository private if it contains personal plans, customer information, credentials, or sensitive research.
- Never put API keys, passwords, tokens, or private customer data in this repository.
- Do not install multiple Blender or Roblox MCP bridges at the same time.
