# Multi-LLM Workflow Bootstrap Kit

Project-agnostic bootstrap kit for:

- beads issue workflow
- OpenSpec artifact workflow
- multi-agent git worktree setup
- multi-model skill wrappers (`codex`, `claude`, `gemini`)
- Notion MCP contract templates (default enabled)

## Why

Keep one shared process definition and expose thin wrappers per model runtime to reduce drift.

## Required Stack (Not Installed By Script)

The target repository must already have:

- OpenSpec (for proposal/design/specs/tasks artifacts)
- beads (for issue ownership and execution state)

This script does not install or initialize OpenSpec/beads. It bootstraps docs, contracts, and wrappers that enforce this stack.

## Files

- `templates/` - reusable docs and skill contract templates
- `../scripts/bootstrap-workflow.sh` - installer script

## Quick Start

```bash
# from this repository
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
- `--llm-provider codex|claude|gemini`: select provider for absorb mode (default: `codex`)
- `--llm-command "<command>"`: custom merge command (reads prompt from stdin, writes merged file content to stdout)
- `--without-notion-mcp`: skip Notion MCP docs and sample server contract
- `--force`: overwrite existing generated files (when `--absorb-existing` is not used)
- `-h`, `--help`: show help

## Migrating Existing LLM Repositories

If the target project already has agent docs/skills, use absorb mode to merge current conventions with generated templates:

```bash
bash scripts/bootstrap-workflow.sh --absorb-existing --llm-provider codex
```

## Generated Layout (High Level)

```text
AGENTS.md
CLAUDE.md
docs/workflows/apply-common.md
docs/multi-agent-setup.md
docs/llm-stack.md
.agent-stack/
  stack.json
  skills/
  profiles/
.codex/skills/
.claude/skills/
.agent/skills/        # Gemini
```

## Notes

- Existing files are skipped by default unless `--force` is provided.
- With `--absorb-existing`, existing files are merged with generated templates via LLM.
- The Notion MCP template is client-agnostic; fill in command/env based on your runtime.
- Model wrappers intentionally stay minimal and point to shared contracts.
