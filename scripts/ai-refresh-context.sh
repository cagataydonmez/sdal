#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "# SDAL lightweight AI context"
echo
echo "## Top-level directories"
find . -maxdepth 2 -type d \
  \( -name node_modules -o -name .git -o -name build -o -name dist -o -name coverage -o -name .dart_tool -o -path './mobile/flutter_sdal/ios/Pods' \) -prune \
  -o -maxdepth 2 -type d -print | sort

echo
echo "## Key manifests and workflows"
find . -maxdepth 4 -type f \
  \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/build/*' -o -path '*/dist/*' -o -path '*/coverage/*' -o -path '*/.dart_tool/*' -o -path './mobile/flutter_sdal/ios/Pods/*' \) -prune \
  -o -type f \( -name 'package.json' -o -name 'pubspec.yaml' -o -name 'analysis_options.yaml' -o -name 'l10n.yaml' -o -path './.github/workflows/*' -o -name 'README.md' \) -print | sort

echo
echo "## Backend routes/src/config"
git ls-files 'server/*.js' 'server/config/*' 'server/middleware/*' 'server/routes/*' 'server/src/*/*' 'server/media/*' 'server/scripts/*.mjs' 'server/migrations/*.sql' \
  | rg -v '(^|/)(node_modules|build|dist|coverage)/'

echo
echo "## Flutter app map"
git ls-files 'mobile/flutter_sdal/lib/**' 'mobile/flutter_sdal/test/**' 'mobile/flutter_sdal/tool/**' 'mobile/flutter_sdal/ios/Runner/**' 'mobile/flutter_sdal/ios/SdalWatch/**' 'mobile/flutter_sdal/ios/SdalNotificationExtension/**' \
  | rg -v '(\.g\.dart$|\.freezed\.dart$|/l10n/generated/|/build/|/Pods/|\.png$|\.jpg$|\.jpeg$|\.pdf$|\.sqlite)'

echo
echo "## AI docs/skills"
git ls-files 'AGENTS.md' 'CLAUDE.md' 'docs/ai/**' '.agents/skills/**/SKILL.md' '.claude/skills/**/SKILL.md' '.claude/rules/**'
