#!/bin/bash
# ido4specs status line — project-state-aware indicator for the bottom of the Claude Code UI.
# Reads session JSON from stdin (Claude Code passes session data); prints one line.
# Silent when no spec artifacts are present, so the line stays clean in unrelated projects.
#
# Output examples:
#   ido4specs · spec ✓ ido4shape-enterprise-cloud
#   ido4specs · synth notification-system
#   ido4specs · plan billing-redesign
#   (silent — no artifacts, lets Claude Code default render)

# Pull cwd from session JSON if available; fall back to $PWD.
CWD=$(cat - 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('cwd', ''))" 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || exit 0

# Artifact scan — same locations the SessionStart hook checks.
CANVAS=$(ls specs/*-tech-canvas.md docs/specs/*-tech-canvas.md 2>/dev/null | head -1)
SPEC=$(ls specs/*-tech-spec.md docs/specs/*-tech-spec.md 2>/dev/null | head -1)
STRATEGIC=$(ls specs/*-strategic-spec.md specs/*-spec.md docs/specs/*-strategic-spec.md ./*-spec.md 2>/dev/null | head -1)

# Strip the canonical suffixes to get a short spec name for display.
spec_name() {
  basename "$1" \
    | sed -e 's/-tech-spec\.md$//' \
          -e 's/-tech-canvas\.md$//' \
          -e 's/-strategic-spec\.md$//' \
          -e 's/-spec\.md$//' \
          -e 's/\.md$//'
}

if [ -n "$SPEC" ]; then
  echo "ido4specs · spec ✓ $(spec_name "$SPEC")"
elif [ -n "$CANVAS" ]; then
  echo "ido4specs · synth $(spec_name "$CANVAS")"
elif [ -n "$STRATEGIC" ]; then
  echo "ido4specs · plan $(spec_name "$STRATEGIC")"
fi
# Silent if no artifacts — Claude Code falls back to its default status line.
