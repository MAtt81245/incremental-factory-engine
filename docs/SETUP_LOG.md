# Setup Log

History of tool, MCP, skill and plugin changes. Current status lives in `docs/MCP_PLAN.md`; this file is the record of how it got there.

## 2026-10-16

- `USER_PROFILE.md` filled in; game summaries added in `docs/games/`.
- Cloud Claude project: GitHub (this repository only), Gmail, Google Calendar, Google Drive, Notion, Indeed and Claude Docs connected. `mcpmarket-me` failed to connect (proxy 403).
- Roblox Studio, Blender, Filesystem, Fetch, Playwright and Memory MCPs can only run in local Claude Code on the user's PC; a cloud session cannot reach them.
- Docs fixed: Blender MCP uses `mcp-for-blender` (ahujasid), `docs/mcp.example.json` is valid JSON, `claude mcp add` commands use `--`, the blender-pixel-art skill header loads, market-skills no longer lives in `/tmp`.
- Official Roblox Studio MCP installed and connected on the PC (desktop extension `Roblox_Studio`, 30 tools, includes skills).
- Verified: the Roblox Studio MCP detects the open place and answers a read-only state check (Studio in Play mode).
- `mcpmarket-me` plugin: MCP fails with 401 (invalid token). Disabled at the user's request (not deleted): `enabledPlugins` set to false in `~/.claude/settings.json`; backup at `~/.claude/settings.json.bak-2026-10-16`. Re-enable by setting it back to true or via Settings > Plugins.
- Skill `token-efficiency` from `denfry/claude-skills`, pinned to commit `cc73299f5d9e5c1a800cf65015093bd527faf0e5`, installed in `~/.claude/skills/token-efficiency` with 4 hooks (session start, each message, after tools, stop) via `hooks/install.py`. Backup: `settings.json.bak`. Remove hooks only: `python ~/.claude/skills/token-efficiency/hooks/install.py --uninstall`.
- MCP `sequential-thinking` installed and removed the same day (`claude mcp remove sequential-thinking -s user`) to save tokens.
- PC inventory: winget, Node and Python 3.14 present; uv, gh and Blender missing; git not checked.
- Blender MCP postponed by the user.
- Cloud audit (this session): only GitHub, Google Drive and Claude Docs were visible as active connectors; `mcpmarket-me` still failed (403) and its skills (`roblox-engineer`, `pixel-art-generation`) were still loaded in the cloud.
- Repository skills merged: `caveman-mode`, `model-router`, `subagent-gate`, `research-budget` → `cheap-direct-mode`.
