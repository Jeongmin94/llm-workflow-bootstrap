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

- target path: parent directory of this bootstrap repository (resolved from script path)
- project name: basename of resolved target path
- models: `codex,claude,gemini`
- Notion MCP templates: enabled

## Options

- `--target <path>`: override target repository path
- `--project-name <name>`: override project display name
- `--issue-prefix <prefix>`: set issue ID prefix used in commit examples
- `--models codex,claude,gemini`: choose models to generate wrappers for
- `--absorb-existing`: when target file already exists, merge existing+template via LLM
- `--absorb-mode merge|hybrid`: absorb strategy (`merge` default, `hybrid` for sidecar legacy docs)
- `--llm-provider codex|claude|gemini`: select provider for absorb mode (default: `codex`)
- `--llm-command "<command>"`: custom merge command (reads prompt from stdin, writes merged file content to stdout)
- `--without-notion-mcp`: skip Notion MCP docs and sample server contract
- `--force`: overwrite existing generated files (when `--absorb-existing` is not used)
- `-h`, `--help`: show help

## Migrating Existing LLM Repositories

If the target project already contains `.agent`, `.claude`, `.codex`, or similar docs/templates, run absorb mode so existing conventions are analyzed and merged into the new templates:

```bash
bash scripts/bootstrap-workflow.sh --absorb-existing --llm-provider codex
```

Recommended hybrid mode for large pre-existing guides:

```bash
bash scripts/bootstrap-workflow.sh \
  --absorb-existing \
  --absorb-mode hybrid \
  --llm-provider codex
```

Hybrid behavior for existing `AGENTS.md` and `CLAUDE.md`:

- Standardized template is written to the original filename.
- Legacy content is preserved in sidecar files:
  - `docs/project/AGENTS.legacy.md`
  - `docs/project/CLAUDE.legacy.md`
- The standardized file includes a reference section pointing to the legacy sidecar.

With a custom LLM command:

```bash
bash scripts/bootstrap-workflow.sh \
  --absorb-existing \
  --llm-command 'codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -'
```

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
