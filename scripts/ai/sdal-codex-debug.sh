#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  printf 'Usage: %s "<debug task or symptom>"\n' "$(basename "$0")" >&2
  exit 64
fi

task="$*"
CODEX_BIN="${CODEX_BIN:-codex}"

if ! command -v "$CODEX_BIN" >/dev/null 2>&1; then
  printf 'Error: codex command not found. Set CODEX_BIN=/path/to/codex if needed.\n' >&2
  exit 127
fi

prompt="Use the sdal-debug skill.
Read docs/ai/ARCHITECTURE_INDEX.md and docs/ai/TASK_PROTOCOL.md first.
Task: ${task}

Rules:
- Do not scan the whole repo.
- Search first with rg.
- Read only relevant files.
- Separate confirmed facts from hypotheses.
- Avoid speculative fixes.
- Plan before editing.
- Make the smallest safe change only after cause is grounded.
- Run targeted validation.
- Summarize facts, changed files, checks, and risks.
- Do not commit."

exec "$CODEX_BIN" "$prompt"
