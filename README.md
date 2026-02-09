# LLM Workflow Bootstrap

Reusable bootstrap kit for setting up a multi-LLM agent workflow in any repository.

## What It Sets Up

- OpenSpec + beads workflow docs and contracts
- Common skill contracts in `.agent-stack/skills/`
- Thin model wrappers for:
  - Codex (`.codex/skills`)
  - Claude (`.claude/skills`)
  - Gemini / Antigravity (`.agent/skills`)
- Optional Notion MCP contract templates

## Required Stack (Not Installed By This Script)

The target repository must already use:

- OpenSpec for proposal/design/specs/tasks artifacts
- beads for issue ownership and execution state

This repository does not install or initialize OpenSpec/beads. It only bootstraps workflow docs/templates that enforce that stack.

## Quick Start

```bash
bash scripts/bootstrap-workflow.sh \
  --target /absolute/path/to/target-repo \
  --project-name "Target Project" \
  --issue-prefix TP \
  --models codex,claude,gemini \
  --with-notion-mcp
```

## Model Notes

- Default models: `codex,claude,gemini`
- `antigravity` is accepted as an alias of `gemini`
- Wrappers stay thin and delegate to shared contracts to reduce drift

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
