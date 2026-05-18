#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  printf 'Usage: %s "<review task>"\n' "$(basename "$0")" >&2
  exit 64
fi

task="$*"
CODEX_BIN="${CODEX_BIN:-codex}"

if ! command -v "$CODEX_BIN" >/dev/null 2>&1; then
  printf 'Error: codex command not found. Set CODEX_BIN=/path/to/codex if needed.\n' >&2
  exit 127
fi

prompt="Use the sdal-review skill.
Read docs/ai/ARCHITECTURE_INDEX.md and docs/ai/TASK_PROTOCOL.md first.
Task: ${task}

Rules:
- Review only; do not edit unless explicitly requested.
- Do not scan the whole repo.
- Inspect git status, diff stat, changed files, and direct call sites.
- Search first with rg.
- Read only relevant diffs and call sites.
- Report blocking issues first, then non-blocking issues and test gaps.
- Summarize reviewed files, checks, risk level, and residual risks.
- Do not commit."

exec "$CODEX_BIN" "$prompt"
