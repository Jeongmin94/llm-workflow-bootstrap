#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Bootstrap reusable OpenSpec + beads + multi-model agent workflow into a target repository.

Usage:
  scripts/bootstrap-workflow.sh \
    [--target <path>] \
    [--project-name <name>] \
    [--issue-prefix <prefix>] \
    [--models codex,claude,gemini] \
    [--absorb-existing] \
    [--llm-provider codex|claude|gemini] \
    [--llm-command <command>] \
    [--without-notion-mcp] \
    [--force]

Options:
  --target            Target repository path (default: parent directory of this bootstrap repository)
  --project-name      Human-readable project name (default: basename of resolved target path)
  --issue-prefix      Issue prefix used in commit examples (default: Lt)
  --models            Comma-separated model list (default: codex,claude,gemini)
  --absorb-existing   Use LLM to merge existing files with generated templates (instead of skip)
  --llm-provider      LLM provider for absorb mode (default: codex)
  --llm-command       Custom shell command for absorb mode (reads prompt from stdin, writes merged content to stdout)
  --without-notion-mcp Skip Notion MCP docs and example contract (enabled by default)
  --force             Overwrite existing files when --absorb-existing is not used
  -h, --help          Show this help

Note:
  Default target resolution uses this script's location (not the current working directory).
  These are equivalent:
    cd scripts && bash bootstrap-workflow.sh
    bash scripts/bootstrap-workflow.sh
USAGE
}

TARGET=""
PROJECT_NAME=""
ISSUE_PREFIX="Lt"
MODELS_RAW="codex,claude,gemini"
ABSORB_EXISTING=0
LLM_PROVIDER="codex"
LLM_COMMAND=""
LLM_PROVIDER_SET=0
LLM_COMMAND_SET=0
WITH_NOTION_MCP=1
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --issue-prefix)
      ISSUE_PREFIX="${2:-}"
      shift 2
      ;;
    --models)
      MODELS_RAW="${2:-}"
      shift 2
      ;;
    --absorb-existing)
      ABSORB_EXISTING=1
      shift
      ;;
    --llm-provider)
      LLM_PROVIDER="${2:-}"
      LLM_PROVIDER_SET=1
      shift 2
      ;;
    --llm-command)
      LLM_COMMAND="${2:-}"
      LLM_COMMAND_SET=1
      shift 2
      ;;
    --with-notion-mcp)
      WITH_NOTION_MCP=1
      shift
      ;;
    --without-notion-mcp)
      WITH_NOTION_MCP=0
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ -z "$TARGET" ]]; then
  if ! TARGET="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"; then
    echo "Error: failed to resolve default target path from $SCRIPT_DIR/../.." >&2
    exit 1
  fi
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target directory does not exist: $TARGET" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

if [[ -z "$PROJECT_NAME" ]]; then
  PROJECT_NAME="$(basename "$TARGET")"
fi

if [[ $ABSORB_EXISTING -eq 0 ]]; then
  if [[ $LLM_PROVIDER_SET -eq 1 ]]; then
    echo "Error: --llm-provider is only valid with --absorb-existing" >&2
    exit 1
  fi
  if [[ $LLM_COMMAND_SET -eq 1 ]]; then
    echo "Error: --llm-command is only valid with --absorb-existing" >&2
    exit 1
  fi
fi

if [[ $ABSORB_EXISTING -eq 1 ]]; then
  if [[ -z "$LLM_COMMAND" ]]; then
    case "$LLM_PROVIDER" in
      codex|claude|gemini)
        ;;
      *)
        echo "Error: unsupported --llm-provider '$LLM_PROVIDER'. Supported: codex, claude, gemini" >&2
        exit 1
        ;;
    esac
  fi
fi

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

slugify() {
  local input="$1"
  input="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  input="$(printf '%s' "$input" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$input" ]]; then
    input="project"
  fi
  printf '%s' "$input"
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[|&/]/\\&/g'
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

tmp_file() {
  mktemp "$TMP_DIR/bootstrap.XXXXXX"
}

PROJECT_SLUG="$(slugify "$PROJECT_NAME")"

declare -a MODELS=()
IFS=',' read -r -a MODEL_ITEMS <<< "$MODELS_RAW"
for raw in "${MODEL_ITEMS[@]}"; do
  model="$(trim "$raw")"
  model="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"
  case "$model" in
    codex|claude|gemini)
      if [[ " ${MODELS[*]-} " != *" $model "* ]]; then
        MODELS+=("$model")
      fi
      ;;
    "")
      ;;
    *)
      echo "Error: unsupported model '$model'. Supported: codex, claude, gemini" >&2
      exit 1
      ;;
  esac
done

if [[ ${#MODELS[@]} -eq 0 ]]; then
  echo "Error: at least one valid model must be selected." >&2
  exit 1
fi

TEMPLATE_ROOT="$SCRIPT_DIR/../bootstrap/templates"

if [[ ! -d "$TEMPLATE_ROOT" ]]; then
  echo "Error: template root not found: $TEMPLATE_ROOT" >&2
  exit 1
fi

PROJECT_NAME_ESC="$(escape_sed "$PROJECT_NAME")"
PROJECT_SLUG_ESC="$(escape_sed "$PROJECT_SLUG")"
ISSUE_PREFIX_ESC="$(escape_sed "$ISSUE_PREFIX")"
PROJECT_NAME_JSON="$(json_escape "$PROJECT_NAME")"
PROJECT_SLUG_JSON="$(json_escape "$PROJECT_SLUG")"
ISSUE_PREFIX_JSON="$(json_escape "$ISSUE_PREFIX")"

build_merge_prompt() {
  local dest_rel="$1"
  local existing_file="$2"
  local candidate_file="$3"

  cat <<EOF
You are merging an existing repository file with a new bootstrap template.

Output requirements:
- Return only the final merged file content.
- Do not include markdown fences.
- Preserve the expected format for this file path: $dest_rel
- Keep mandatory workflow constraints from the new template.
- Keep project-specific conventions from the existing file when they do not conflict.
- If there is a conflict, prefer the new template for required workflow/stack rules.

File path: $dest_rel

<<<EXISTING_FILE_START>>>
EOF
  cat "$existing_file"
  cat <<'EOF'
<<<EXISTING_FILE_END>>>
<<<NEW_TEMPLATE_START>>>
EOF
  cat "$candidate_file"
  cat <<'EOF'
<<<NEW_TEMPLATE_END>>>
EOF
}

run_llm_merge() {
  local prompt_file="$1"
  local output_file="$2"

  if [[ -n "$LLM_COMMAND" ]]; then
    if ! bash -lc "$LLM_COMMAND" < "$prompt_file" > "$output_file"; then
      echo "Error: custom LLM command failed: $LLM_COMMAND" >&2
      exit 1
    fi
    return
  fi

  case "$LLM_PROVIDER" in
    codex)
      if ! codex exec \
        --cd "$TARGET" \
        --skip-git-repo-check \
        --dangerously-bypass-approvals-and-sandbox \
        --output-last-message "$output_file" \
        - < "$prompt_file" > /dev/null; then
        echo "Error: codex exec failed while merging existing file." >&2
        exit 1
      fi
      ;;
    claude)
      if ! claude \
        --dangerously-skip-permissions \
        --print \
        --output-format text \
        "Use stdin as the full prompt. Return only final merged file content." \
        < "$prompt_file" > "$output_file"; then
        echo "Error: claude command failed while merging existing file." >&2
        exit 1
      fi
      ;;
    gemini)
      if ! gemini \
        --approval-mode yolo \
        --output-format text \
        -p "Use stdin as the full prompt. Return only final merged file content." \
        < "$prompt_file" > "$output_file"; then
        echo "Error: gemini command failed while merging existing file." >&2
        exit 1
      fi
      ;;
    *)
      echo "Error: unsupported --llm-provider '$LLM_PROVIDER'" >&2
      exit 1
      ;;
  esac
}

normalize_llm_output() {
  local input_file="$1"
  local output_file="$2"
  local first_line last_line

  first_line="$(head -n 1 "$input_file" 2>/dev/null || true)"
  last_line="$(tail -n 1 "$input_file" 2>/dev/null || true)"

  if [[ "$first_line" =~ ^\`\`\` ]] && [[ "$last_line" =~ ^\`\`\`[[:space:]]*$ ]]; then
    sed '1d;$d' "$input_file" > "$output_file"
  else
    cp "$input_file" "$output_file"
  fi
}

write_or_merge_file() {
  local dest_rel="$1"
  local candidate_file="$2"
  local dest="$TARGET/$dest_rel"

  if [[ -f "$dest" ]]; then
    if [[ $ABSORB_EXISTING -eq 1 ]]; then
      local prompt_file raw_output_file normalized_output_file
      prompt_file="$(tmp_file)"
      raw_output_file="$(tmp_file)"
      normalized_output_file="$(tmp_file)"

      build_merge_prompt "$dest_rel" "$dest" "$candidate_file" > "$prompt_file"
      run_llm_merge "$prompt_file" "$raw_output_file"
      normalize_llm_output "$raw_output_file" "$normalized_output_file"

      if [[ ! -s "$normalized_output_file" ]]; then
        echo "Error: LLM returned empty merged content for $dest_rel" >&2
        exit 1
      fi

      mkdir -p "$(dirname "$dest")"
      cp "$normalized_output_file" "$dest"
      echo "merge $dest_rel (existing + template via LLM)"
      return
    fi

    if [[ $FORCE -eq 0 ]]; then
      echo "skip  $dest_rel (exists)"
      return
    fi
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$candidate_file" "$dest"
  echo "write $dest_rel"
}

render_template() {
  local template_rel="$1"
  local dest_rel="$2"

  local src="$TEMPLATE_ROOT/$template_rel"
  local rendered_file
  rendered_file="$(tmp_file)"

  if [[ ! -f "$src" ]]; then
    echo "Error: template missing: $src" >&2
    exit 1
  fi

  sed \
    -e "s|{{PROJECT_NAME}}|$PROJECT_NAME_ESC|g" \
    -e "s|{{PROJECT_SLUG}}|$PROJECT_SLUG_ESC|g" \
    -e "s|{{ISSUE_PREFIX}}|$ISSUE_PREFIX_ESC|g" \
    "$src" > "$rendered_file"

  write_or_merge_file "$dest_rel" "$rendered_file"
}

write_text_file() {
  local dest_rel="$1"
  local content="$2"
  local rendered_file
  rendered_file="$(tmp_file)"

  printf '%s\n' "$content" > "$rendered_file"
  write_or_merge_file "$dest_rel" "$rendered_file"
}

runtime_note_for_model() {
  local model="$1"
  case "$model" in
    codex)
      printf '%s' '- sandbox: danger-full-access
- approval-policy: never'
      ;;
    claude)
      printf '%s' '- run with: claude --dangerously-skip-permissions'
      ;;
    gemini)
      printf '%s' '- run with Gemini-compatible unrestricted filesystem/command/network permissions'
      ;;
    *)
      printf '%s' '- runtime requirements are project-defined'
      ;;
  esac
}

title_for_model() {
  local model="$1"
  case "$model" in
    codex) printf '%s' 'Codex' ;;
    claude) printf '%s' 'Claude' ;;
    gemini) printf '%s' 'Gemini' ;;
    *) printf '%s' "$model" ;;
  esac
}

model_skill_root() {
  local model="$1"
  case "$model" in
    codex) printf '%s' '.codex/skills' ;;
    claude) printf '%s' '.claude/skills' ;;
    gemini) printf '%s' '.agent/skills' ;;
    *) printf '%s' '.agent/skills' ;;
  esac
}

render_template "AGENTS.md.tmpl" "AGENTS.md"
render_template "CLAUDE.md.tmpl" "CLAUDE.md"
render_template "docs/workflows/apply-common.md.tmpl" "docs/workflows/apply-common.md"
render_template "docs/multi-agent-setup.md.tmpl" "docs/multi-agent-setup.md"
render_template "docs/llm-stack.md.tmpl" "docs/llm-stack.md"
render_template "agent-stack/skills/apply-common.md.tmpl" ".agent-stack/skills/apply-common.md"
render_template "agent-stack/skills/pr-review.md.tmpl" ".agent-stack/skills/pr-review.md"

if [[ $WITH_NOTION_MCP -eq 1 ]]; then
  render_template "docs/mcp/notion.md.tmpl" "docs/mcp/notion.md"
fi

models_json=""
for model in "${MODELS[@]}"; do
  if [[ -n "$models_json" ]]; then
    models_json+=" ,"
  fi
  models_json+="\"$model\""
done

created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
stack_json_content="{
  \"projectName\": \"$PROJECT_NAME_JSON\",
  \"projectSlug\": \"$PROJECT_SLUG_JSON\",
  \"issuePrefix\": \"$ISSUE_PREFIX_JSON\",
  \"frameworks\": [\"beads\", \"openspec\"],
  \"models\": [ $models_json ],
  \"mcp\": {
    \"notion\": $([[ $WITH_NOTION_MCP -eq 1 ]] && printf 'true' || printf 'false')
  },
  \"generatedAt\": \"$created_at\"
}"
write_text_file ".agent-stack/stack.json" "$stack_json_content"

if [[ $WITH_NOTION_MCP -eq 1 ]]; then
  notion_json_content='{
  "servers": {
    "notion": {
      "command": "<notion-mcp-server-command>",
      "args": [],
      "env": {
        "NOTION_API_KEY": "${NOTION_API_KEY}",
        "NOTION_API_VERSION": "${NOTION_API_VERSION}",
        "NOTION_DEFAULT_DATABASE_ID": "${NOTION_DEFAULT_DATABASE_ID}"
      }
    }
  }
}'
  write_text_file ".agent-stack/mcp/notion.server.example.json" "$notion_json_content"
fi

for model in "${MODELS[@]}"; do
  model_title="$(title_for_model "$model")"
  runtime_note="$(runtime_note_for_model "$model")"
  skill_root="$(model_skill_root "$model")"

  apply_skill_path="$skill_root/$model-apply/SKILL.md"
  apply_skill_content="---
name: $model-apply
description: Execute the shared apply workflow for $model_title.
---

# $model_title Apply

Follow these canonical sources:

- docs/workflows/apply-common.md
- .agent-stack/skills/apply-common.md

Runtime requirement:
$runtime_note

Use this skill when the user asks for end-to-end implementation on an issue or OpenSpec change.

Stack requirements:
- OpenSpec artifacts (proposal/design/specs/tasks) are the implementation source-of-truth.
- beads tracks execution state (bd update/close/sync --json) for every task.
"
  write_text_file "$apply_skill_path" "$apply_skill_content"

  review_skill_path="$skill_root/pr-review/SKILL.md"
  review_skill_content="---
name: pr-review
description: Run the shared PR review workflow with $model_title.
---

# PR Review ($model_title)

Follow these canonical sources:

- .agent-stack/skills/pr-review.md
- docs/workflows/apply-common.md

This wrapper is intentionally thin to keep behavior aligned across models.
Findings must be recorded in beads issues.
"
  write_text_file "$review_skill_path" "$review_skill_content"

  profile_path=".agent-stack/profiles/$model.md"
  profile_content="# $model_title Profile

Apply skill:
- $skill_root/$model-apply/SKILL.md

Review skill:
- $skill_root/pr-review/SKILL.md

Runtime requirements:
$runtime_note
"
  write_text_file "$profile_path" "$profile_content"
done

echo
printf 'Bootstrap complete for %s at %s\n' "$PROJECT_NAME" "$TARGET"
printf 'Models installed: %s\n' "${MODELS[*]}"
if [[ $ABSORB_EXISTING -eq 1 ]]; then
  if [[ -n "$LLM_COMMAND" ]]; then
    echo "Existing file absorb mode: enabled (custom command)"
  else
    printf 'Existing file absorb mode: enabled (%s)\n' "$LLM_PROVIDER"
  fi
fi
if [[ $WITH_NOTION_MCP -eq 1 ]]; then
  echo "Notion MCP templates installed."
fi

echo
cat <<'NEXT'
Recommended next steps:
1. Review generated docs and adjust team-specific conventions.
2. Configure MCP secrets in your local environment.
3. Run `bd doctor --json` and `bd ready --json` in the target repository.
NEXT
