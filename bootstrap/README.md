# Multi-LLM Workflow Bootstrap Kit

Project-agnostic bootstrap kit for:

- beads issue workflow
- OpenSpec artifact workflow
- multi-agent git worktree setup
- multi-model skill wrappers (`codex`, `claude`, `gemini`)
- optional Notion MCP contract templates

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
scripts/bootstrap-workflow.sh \
  --target /path/to/your-repo \
  --project-name "Your Project" \
  --issue-prefix YP \
  --models codex,claude,gemini \
  --with-notion-mcp
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
.agent/skills/        # Gemini (Antigravity)
```

## Notes

- Existing files are not overwritten unless `--force` is provided.
- The Notion MCP template is client-agnostic; fill in command/env based on your runtime.
- Model wrappers intentionally stay minimal and point to shared contracts.
- `antigravity` is accepted as a model alias and mapped to `gemini` (`.agent/skills`).
