# LLM Workflow Bootstrap

Reusable bootstrap kit for setting up a multi-LLM agent workflow in any repository.

## What It Sets Up

- OpenSpec + beads workflow docs and contracts
- Common skill contracts in `.agent-stack/skills/`
- Thin model wrappers for:
  - Codex (`.codex/skills`)
  - Claude (`.claude/skills`)
  - Gemini (`.agent/skills`)
- Notion MCP contract templates (default enabled)

## Required Stack (Not Installed By This Script)

The target repository must already use:

- OpenSpec for proposal/design/specs/tasks artifacts
- beads for issue ownership and execution state

This repository does not install or initialize OpenSpec/beads. It only bootstraps workflow docs/templates that enforce that stack.

## Quick Start

```bash
bash scripts/bootstrap-workflow.sh
```

Default behavior:

- target path: `../../` from current working directory
- project name: basename of target path
- models: `codex,claude,gemini`
- Notion MCP templates: enabled

## Options

- `--target <path>`: override target repository path
- `--project-name <name>`: override project display name
- `--issue-prefix <prefix>`: set issue ID prefix used in commit examples
- `--models codex,claude,gemini`: choose models to generate wrappers for
- `--without-notion-mcp`: skip Notion MCP docs and sample server contract
- `--force`: overwrite existing generated files
- `-h`, `--help`: show help

## Repository Layout

```text
bootstrap/
  README.md
  templates/
scripts/
  bootstrap-workflow.sh
```

## Smoke Test

```bash
bash scripts/bootstrap-workflow.sh --target "$(mktemp -d)" --project-name "Smoke" --models codex,claude,gemini
```
