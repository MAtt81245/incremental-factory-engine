# Decisions

Record decisions so every AI can continue from the same place.

## Decision template

### YYYY-MM-DD — Decision title

- Decision:
- Why:
- Evidence:
- Alternatives considered:
- Revisit when:

## Decisions

### 2026-10-14 — Shared AI project memory

- Decision: Use this private GitHub repository as the shared source of truth.
- Why: Claude, Gemini, and ChatGPT do not share one automatic live memory.
- Revisit when: A better synchronized workspace is deliberately chosen.

### 2026-10-14 — Tool roles

- Decision: Claude Pro builds and codes; Gemini Pro researches; ChatGPT Free critiques and compares.
- Why: This matches the subscriptions currently available.
- Revisit when: Usage limits, quality, or workflow needs change.

### 2026-10-16 — MCP install order

- Decision: Install the official Roblox Studio MCP first, then one reviewed Roblox skill set, then Blender with `mcp-for-blender`. Add Fetch and Playwright only when a task needs them.
- Why: Roblox is the core work, and the official plugin is first-party. GitHub is already connected in the Claude project. Each extra MCP adds access and risk.
- Evidence: Setup audit in `CURRENT_STATE.md` (2026-10-16).
- Alternatives considered: Filesystem or Memory first. They are not needed while the repository is the memory.
- Revisit when: The Roblox plugin is working, or a task needs a different tool.
