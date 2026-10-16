# MCP Connections Plan

MCP servers give Claude controlled access to tools. They are not shared memory: this repository is. Enable only what the current task needs. History of changes: `docs/SETUP_LOG.md`.

## Current status (2026-10-16)

### Active

| MCP / connector | Where | Use | Main risk |
|---|---|---|---|
| Roblox Studio (official) | PC, local Claude Code | Inspect, edit, playtest, debug places | Directly changes the place — save/publish first |
| GitHub | Cloud | This repository only | Writes and pushes — ask first |
| Google Drive | Cloud | Optional storage for large PNG/renders kept out of git | Reads private files |
| Claude Docs | Cloud | Shareable documents | — |

Only one Roblox MCP at a time. Do not add a second one.

### Postponed (install when a real task needs it)

| MCP | Trigger to install | Notes |
|---|---|---|
| Blender (`mcp-for-blender`, ahujasid) | First real 3D asset request | Needs uv + Blender. Steps in `docs/INSTALL.md` §7. Test Blender by hand first, then the one-cube test |
| Playwright | A web task that needs clicking or logging in | Separate browser profile; never expose passwords |

### Not recommended (redundant in Claude Code)

| MCP | Why not |
|---|---|
| Filesystem | Claude Code already reads and writes local files |
| Fetch | Built-in web fetch/search already covers it |
| Git | Claude Code already runs git |
| Memory | This repository is the memory; a second store goes stale |
| Sequential Thinking | Installed and removed 2026-10-16; adds tokens, no clear gain |

### Disabled / to clean up

- `mcpmarket-me` plugin: disabled on the PC (401). In the cloud it still fails (403) and its skills still load. **Pending for the user:** disable it in claude.ai > Settings too.
- Gmail, Notion, Indeed, Google Calendar connectors: not needed for Roblox work. **Pending for the user:** turn them off for Roblox sessions (Claude app: + > Connectors, or claude.ai > Settings > Connectors).

## Commands (only when a trigger above is met)

```bash
# Inspect configured servers
/mcp

# Playwright (postponed)
claude mcp add playwright -- npx -y @playwright/mcp@latest

# Blender (postponed): see docs/INSTALL.md §7
uvx mcp-for-blender setup
```

The `--` separates Claude Code options from the server command. Syntax can change between versions; check current docs if a command fails.

`docs/mcp.example.json` is a JSON template. Copy it outside this repository before replacing placeholders and never commit the real file.

## Sources

- Roblox Studio Agent Plugin: https://github.com/Roblox/roblox-studio-agent-plugin
- Blender MCP: https://github.com/ahujasid/blender-mcp
- Playwright MCP: https://github.com/microsoft/playwright-mcp
- MCP reference servers: https://github.com/modelcontextprotocol/servers

## Safety rules

- Never enable all MCPs by default; one task-specific group at a time.
- Start read-only.
- Ask before writes, uploads, purchases, messages, commits, pushes, Roblox edits, or Blender edits.
- Never put API keys, tokens, cookies, passwords, or private data in this repository.
- Review community MCP source and install scripts before running them; avoid `curl … | sh`.
- Update this file (and `docs/SETUP_LOG.md`) when a server is added, removed, renamed, or replaced.
