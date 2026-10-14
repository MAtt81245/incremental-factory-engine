# Installation Guide

This guide lists the recommended tools discussed in the plan. Install only what you need; overlapping plugins can create duplicate tools.

## 1. Claude Code basics

Install Claude Code using Anthropic's current instructions:

- Documentation: https://docs.anthropic.com/en/docs/claude-code/overview
- Skills documentation: https://docs.anthropic.com/en/docs/claude-code/skills
- MCP documentation: https://docs.anthropic.com/en/docs/claude-code/mcp

Claude Code skill folders normally contain a `SKILL.md` file. User-level skills go in `~/.claude/skills/`; project-level skills go in `.claude/skills/` inside a repository.

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

The official plugin supports Claude Code and Cowork. Studio's MCP server runs locally; the Claude web app alone cannot connect to a local Studio process. Do not add a second Roblox Studio MCP server by hand if the official plugin is already installed.

## 3. Roblox development skills

### AshExplained Roblox skills

Repository: https://github.com/AshExplained/roblox-skills

```bash
git clone https://github.com/AshExplained/roblox-skills.git ~/.claude/skills/roblox-skills
```

### Roblox Claude skills by mvvthw

Repository: https://github.com/mvvthw/roblox-claude-skills

```bash
git clone https://github.com/mvvthw/roblox-claude-skills.git /tmp/roblox-claude-skills
cp -R /tmp/roblox-claude-skills/* ~/.claude/skills/
```

Review skill names before copying if you already have overlapping Roblox skills.

### Bloxlab

Repository: https://github.com/imhugiok/bloxlab

```text
/plugin marketplace add imhugiok/bloxlab
/plugin install bloxlab@bloxlab
/reload-plugins
```

Use it for Roblox game-mode ideation and build workflows. Install it only if you want its workflow in addition to the official Studio connection.

## 4. Game ideas and critique

### Claude Code Game Studios

Repository: https://github.com/AndrewYukon/claude-code-game-studios

```bash
git clone https://github.com/AndrewYukon/claude-code-game-studios.git /tmp/claude-code-game-studios
cp -R /tmp/claude-code-game-studios/.claude .
```

The repository includes `/brainstorm` for structured game ideation. Use:

```text
/brainstorm Roblox game for a solo developer
```

For any game idea, ask for a harsh review:

```text
Roast this game idea. Find generic parts, weak retention, scope problems,
boring loops, economy risks, and the cheapest prototype that could disprove it.
```

## 5. Money and opportunity research

### Build-DNA

Repository: https://github.com/Sudiddii/build-DNA

```bash
git clone https://github.com/Sudiddii/build-DNA.git ~/.claude/skills/build-dna
```

Use it to match your skills, resources, and unfair advantages to realistic opportunities:

```text
/build-dna Find realistic ways I could make money using my skills and resources.
```

### Market skills

Repository: https://github.com/trinity-ai-labs/market-skills

Recommended plugin installation:

```text
/plugin marketplace add trinity-ai-labs/claude-plugins
/plugin install market@trinity-ai-labs
```

Or install the two skills for development:

```bash
git clone https://github.com/trinity-ai-labs/market-skills.git /tmp/market-skills
mkdir -p ~/.claude/skills
ln -s /tmp/market-skills/skills/market-analysis ~/.claude/skills/market-analysis
ln -s /tmp/market-skills/skills/business-plan ~/.claude/skills/business-plan
```

Use:

```text
Run a market analysis on this opportunity. Separate facts, estimates,
inferences, and opinions. Include competitors, pricing, willingness to pay,
startup cost, distribution, risks, and the cheapest validation test.
```

## 6. Reduce Claude usage and overthinking

### Token-efficiency

Repository: https://github.com/denfry/claude-skills

The skill is here: https://github.com/denfry/claude-skills/tree/main/skills/token-efficiency

```bash
git clone https://github.com/denfry/claude-skills.git /tmp/denfry-claude-skills
mkdir -p ~/.claude/skills/token-efficiency
cp -R /tmp/denfry-claude-skills/skills/token-efficiency/* ~/.claude/skills/token-efficiency/
```

This reduces filler, repeated rereading, unnecessary verification loops, context bloat, and avoidable tool calls. It cannot increase Claude Pro's quota.

### Sonnet-lean routing skill

Repository: https://github.com/henriquetell/claude-skills

```bash
git clone https://github.com/henriquetell/claude-skills.git /tmp/henriquetell-claude-skills
cp -R /tmp/henriquetell-claude-skills/sonnet-lean ~/.claude/skills/
```

Use lower-cost models for mechanical work and stronger models for architecture or difficult debugging. Check the repository's current instructions before use because model names and Claude Code behavior can change.

### Simple direct mode

This repository also includes a local project skill at:

```text
.claude/skills/cheap-direct-mode/SKILL.md
```

It encourages short answers, low effort for easy tasks, fewer unnecessary questions, and a `caveman mode` trigger.

## 7. Shared memory between Claude, Gemini, and ChatGPT

There is no guaranteed single live memory shared automatically between all three services. Use this repository as the source of truth.

### Claude Pro

Create a Claude Project such as **Opportunity Lab** and upload or connect the key Markdown files. Add the contents of `AI_INSTRUCTIONS.md` to the Project instructions.

### Gemini Pro

Use a Gem or a dedicated chat with the key files uploaded. For research, ask Gemini to write findings that can be copied into `RESEARCH.md` with source links and access dates.

### ChatGPT Free

Create a Project if available on your account and add the key files. Use it for independent critique and comparison. If repository connections are unavailable, paste only `CURRENT_STATE.md`, the relevant idea, and the latest research—not the entire history.

### Handoff prompt

Use this at the end of any substantial session:

```text
Create a compact handoff for this repository.
Include: completed work, new facts with links, decisions, rejected ideas,
open questions, risks, and the exact next action. Do not invent anything.
Format it so I can paste it into CURRENT_STATE.md, RESEARCH.md, IDEAS.md,
or DECISIONS.md.
```

## 8. Recommended order

1. Complete `USER_PROFILE.md`.
2. Install the official Roblox Studio plugin.
3. Add one Roblox skill set, not several overlapping sets.
4. Add `token-efficiency` and the local `cheap-direct-mode` skill.
5. Use Gemini Pro to research questions, customers, competitors, and prices.
6. Use Claude Pro to synthesize, build, and test.
7. Use ChatGPT Free to roast the shortlist.
8. Record the result in this repository.

## Safety and quality

- Review third-party skills before installing them.
- Save or publish a Roblox place before allowing an agent to make large changes.
- Keep this repository private if it contains personal plans, customer information, credentials, or sensitive research.
- Never put API keys, passwords, tokens, or private customer data in this repository.
- Do not install multiple Roblox Studio MCP bridges until you understand which one is active.
