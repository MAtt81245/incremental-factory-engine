# Installation Guide

This guide lists the recommended tools discussed in the plan. Install only what you need; overlapping plugins can create duplicate tools.

## 1. Claude Code basics

Install Claude Code using Anthropic's current instructions:

- Documentation: https://docs.anthropic.com/en/docs/claude-code/overview
- Skills documentation: https://docs.anthropic.com/en/docs/claude-code/skills
- MCP documentation: https://docs.anthropic.com/en/docs/claude-code/mcp

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
git clone https://github.com/trinity-ai-labs/market-skills.git /tmp/market-skills
mkdir -p ~/.claude/skills
ln -s /tmp/market-skills/skills/market-analysis ~/.claude/skills/market-analysis
ln -s /tmp/market-skills/skills/business-plan ~/.claude/skills/business-plan
```

## 5. Reduce Claude usage

The repository already contains:

```text
.claude/skills/cheap-direct-mode/
.claude/skills/caveman-mode/
.claude/skills/model-router/
.claude/skills/subagent-gate/
.claude/skills/research-budget/
.claude/skills/session-handoff/
```

Optional third-party token-efficiency repository:

```bash
git clone https://github.com/denfry/claude-skills.git /tmp/denfry-claude-skills
mkdir -p ~/.claude/skills/token-efficiency
cp -R /tmp/denfry-claude-skills/skills/token-efficiency/* ~/.claude/skills/token-efficiency/
```

These instructions can reduce wasted output and context, but cannot increase a plan's quota.

## 6. Blender

Download Blender from the official site:

```text
https://www.blender.org/download/
```

Use the current stable release for normal work. Save a copy of important `.blend` files before connecting an AI.

## 7. Blender MCP for Claude Code

A community option currently documented for Claude Code is:

Repository: https://github.com/josuemontano/blender-mcp

Its documented setup uses `pipx`, a Blender add-on, and an MCP registration:

### Install `pipx`

Windows PowerShell:

```powershell
py -m pip install --user pipx
py -m pipx ensurepath
```

macOS:

```bash
brew install pipx
pipx ensurepath
```

Linux:

```bash
python3 -m pip install --user pipx
python3 -m pipx ensurepath
```

Open a new terminal, then:

```bash
pipx install blender-mcp
blender-mcp install-addon
claude mcp add blender blender-mcp
```

In Blender:

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

1. Complete `USER_PROFILE.md`.
2. Install Blender.
3. Install the local project skills by opening this repository in Claude Code.
4. Install the official Roblox Studio plugin.
5. Install one Roblox skill set.
6. Install Blender MCP only after testing Blender manually.
7. Run the one-cube Blender MCP test.
8. Test one 64x64 sprite before building a full pipeline.
9. Use Poly Haven, Kenney, or Blendkit assets while checking licenses.
10. Record successful commands and decisions in `CURRENT_STATE.md`.

## Safety

- Review third-party skills and scripts before installing them.
- Save or publish a Roblox place before allowing an agent to make large changes.
- Keep this repository private if it contains personal plans, customer information, credentials, or sensitive research.
- Never put API keys, passwords, tokens, or private customer data in this repository.
- Do not install multiple Blender or Roblox MCP bridges at the same time.
