# MCP Connections Plan

MCP servers give Claude controlled access to tools. They are not shared memory by themselves. Keep GitHub as the source of truth and enable only the servers needed for the current task.

## Recommended order

### Tier 1 — install first

1. **Official Roblox Studio MCP/plugin** — live Roblox inspection, Luau editing, playtesting, asset search, and debugging. Use only with a saved/published place.
2. **Filesystem MCP** — lets Claude read/write selected local folders. Allow only the Plans repository and specific project folders.
3. **GitHub MCP** — useful for repository issues, pull requests, branches, files, and project work. Use a fine-scoped token and keep write actions disabled or approval-gated where possible.

### Tier 2 — useful for research and work

4. **Fetch MCP** — fetches public web pages as Markdown. Good for official documentation and focused research.
5. **Playwright MCP** — controls a browser for web workflows and sites that need interaction. Use a separate browser profile and never expose passwords.
6. **Blender MCP** — automates Blender scenes, renders, exports, and sprite pipelines. Use one Blender MCP only and test with a disposable scene.

### Tier 3 — optional

7. **Memory MCP** — local knowledge graph. Use only for durable preferences or relationships not already stored in this repository. Do not create conflicting memories.
8. **Git MCP** — local Git status, diff, history, and controlled repository actions. Prefer read-only inspection first.
9. **Sequential Thinking MCP** — reserve for difficult architecture or debugging. It may increase effort, so it is not a token-saving server.

## Official/reference sources

- MCP reference servers: https://github.com/modelcontextprotocol/servers
- GitHub MCP Server: https://github.com/github/github-mcp-server
- Microsoft Playwright MCP: https://github.com/microsoft/playwright-mcp
- Roblox Studio Agent Plugin: https://github.com/Roblox/roblox-studio-agent-plugin
- Blender MCP (`mcp-for-blender`, formerly `blender-mcp`): https://github.com/ahujasid/blender-mcp — see `docs/INSTALL.md`.

## Claude Code commands

Run these only after reviewing the current README/instructions for each server and confirming paths:

```bash
# Official Roblox plugin: install from Claude Code
/plugin
# Search for Roblox Studio

# Playwright browser automation
claude mcp add playwright -- npx -y @playwright/mcp@latest

# Official/reference fetch server with uvx
claude mcp add fetch -- uvx mcp-server-fetch

# Official/reference memory server
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory

# Official/reference sequential thinking; optional
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# Inspect configured servers
/mcp
```

The `--` separates Claude Code options from the server command, so flags such as `-y` reach `npx` instead of `claude`. The exact command syntax can vary by Claude Code version. If a command fails, ask Claude to read the current official documentation rather than guessing.

## Config file example

`docs/mcp.example.json` is a valid JSON template. Copy it outside this repository before replacing the placeholders, and never commit the real file.

## Filesystem example

Do not allow the whole home directory. Replace the placeholder with the actual local path to the cloned repository:

```bash
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem /ABSOLUTE/PATH/TO/Plans.
```

Allow additional folders only when needed, for example the Roblox project or Blender asset folder.

## GitHub example

GitHub's official server requires authentication. Do not place tokens in this repository, `CLAUDE.md`, skills, screenshots, or chat. Create a fine-scoped token locally and follow the GitHub MCP Server installation guide:

```text
https://github.com/github/github-mcp-server
```

Use GitHub MCP only after confirming whether Claude needs read-only access or write access. Read-only is the default recommendation.

## What each connection is for

| MCP | Best use | Main risk |
|---|---|---|
| Roblox Studio | Build, inspect, playtest, debug Roblox | Directly changes the place |
| Filesystem | Read/write local project files | Exposes allowed folders |
| GitHub | Issues, PRs, repo context, GitHub actions | Token permissions and writes |
| Fetch | Read public documentation | External web requests |
| Playwright | Search and interact with websites | Browser data and logged-in sessions |
| Blender | Create/render/export 3D assets | Scene/file changes and scripts |
| Memory | Durable local graph memory | Duplicate or stale context |
| Git | Local diff/history/actions | Repository modifications |
| Sequential Thinking | Complex analysis | More effort and tokens |

## Safety rules

- Never enable all MCPs by default.
- Use one task-specific group at a time.
- Start with read-only capabilities.
- Ask before writes, uploads, purchases, messages, commits, pushes, Roblox edits, or Blender edits.
- Use separate browser profiles for Playwright.
- Never paste API keys, GitHub tokens, cookies, passwords, or private customer data into the repository.
- Review community MCP source and install scripts before running them.
- Update this file when a server is abandoned, renamed, or replaced.
