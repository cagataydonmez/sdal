#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${FLUTTER_BUILD_DIR:-}" ]]; then
  exit 0
fi

SCRIPT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROJECT_ROOT="${FLUTTER_APPLICATION_PATH:-$SCRIPT_ROOT}"
PROJECT_DART_TOOL_DIR="${PROJECT_ROOT}/.dart_tool"
PROJECT_FLUTTER_BUILD_LINK="${PROJECT_DART_TOOL_DIR}/flutter_build"

case "${FLUTTER_BUILD_DIR}" in
  /*)
    RESOLVED_FLUTTER_BUILD_DIR="${FLUTTER_BUILD_DIR}"
    ;;
  *)
    RESOLVED_FLUTTER_BUILD_DIR="$(
      /usr/bin/python3 - "${PROJECT_ROOT}" "${FLUTTER_BUILD_DIR}" <<'PY'
import os
import sys

project_root = sys.argv[1]
build_dir = sys.argv[2]
print(os.path.realpath(os.path.join(project_root, build_dir)))
PY
    )"
    ;;
esac

mkdir -p "${PROJECT_DART_TOOL_DIR}" "${RESOLVED_FLUTTER_BUILD_DIR}"
ln -sfn "${RESOLVED_FLUTTER_BUILD_DIR}" "${PROJECT_FLUTTER_BUILD_LINK}"
