#!/bin/bash
# TestFlight utilities: build number tracking and release notes generation

TESTFLIGHT_STATE_DIR="${HOME}/.sdal_testflight_state"
TESTFLIGHT_BUILD_FILE="$TESTFLIGHT_STATE_DIR/last_build_number"

# Initialize state directory
init_testflight_state() {
  mkdir -p "$TESTFLIGHT_STATE_DIR"
}

# Get current build number from pubspec.yaml
get_current_build_number() {
  grep "^version:" "$1/pubspec.yaml" | sed 's/.*+//'
}

# Get last uploaded build number
get_last_testflight_build() {
  if [[ -f "$TESTFLIGHT_BUILD_FILE" ]]; then
    cat "$TESTFLIGHT_BUILD_FILE"
  else
    echo "0"
  fi
}

# Save current build number as last uploaded
save_testflight_build_number() {
  echo "$1" > "$TESTFLIGHT_BUILD_FILE"
}

# Generate user-friendly release notes from git commits
generate_release_notes() {
  local root_dir="$1"
  local start_ref="$2"
  local end_ref="${3:-HEAD}"

  local notes=""

  if [[ -z "$start_ref" || "$start_ref" == "0" ]]; then
    # First build or no previous build tracked
    notes="Initial TestFlight build"
  else
    # Get commits between builds, formatted nicely
    local commits
    commits=$(cd "$root_dir" && git log --oneline --no-decorate "$start_ref..$end_ref" 2>/dev/null || echo "")

    if [[ -z "$commits" ]]; then
      notes="Updated dependencies and improvements"
    else
      # Group commits by feature/fix
      notes=$(echo "$commits" | \
        sed 's/^[a-f0-9]* //' | \
        awk '
        /^Fix/ { fixes[++fix_count] = substr($0, 5); next }
        /^Add/ { features[++feat_count] = substr($0, 5); next }
        /^Update/ { updates[++upd_count] = substr($0, 8); next }
        { other[++oth_count] = $0; next }
        END {
          if (feat_count > 0) {
            print "✨ New Features:"
            for (i = 1; i <= feat_count; i++) print "  • " features[i]
          }
          if (fix_count > 0) {
            print "🐛 Bug Fixes:"
            for (i = 1; i <= fix_count; i++) print "  • " fixes[i]
          }
          if (upd_count > 0) {
            print "🔄 Updates:"
            for (i = 1; i <= upd_count; i++) print "  • " updates[i]
          }
          if (oth_count > 0) {
            print "📝 Other Changes:"
            for (i = 1; i <= oth_count; i++) print "  • " other[i]
          }
        }
        ')
    fi
  fi

  # Limit to 4000 characters (TestFlight limit is 4000)
  echo "$notes" | head -c 4000
}

# Format release notes with version info
format_release_notes() {
  local version="$1"
  local build_num="$2"
  local changelog="$3"

  local release_notes="Version: $version (Build $build_num)

$changelog

---
Test and provide feedback on TestFlight!"

  echo "$release_notes"
}

# Save release notes to a temporary file
save_release_notes() {
  local notes="$1"
  local output_file="$2"
  echo "$notes" > "$output_file"
  echo "Release notes saved to: $output_file"
}

# Display release notes in a formatted way
display_release_notes() {
  local notes="$1"
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║          TestFlight Release Notes                          ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "$notes"
  echo ""
}
