#!/bin/bash
# SessionStart status scan — version echo + artifact detection + contextual guidance.
# Runs in the USER's project directory (not the plugin directory).
# Output is injected into the model's context for the first response.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ─── Version echo ─────────────────────────────────────────
VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "?")
TECH_V=$(cat "$PLUGIN_ROOT/dist/.tech-spec-format-version" 2>/dev/null | tr -d '[:space:]' || echo "?")
SPEC_V=$(cat "$PLUGIN_ROOT/dist/.spec-format-version" 2>/dev/null | tr -d '[:space:]' || echo "?")

echo "ido4specs v${VERSION} | tech-spec-format@${TECH_V} | spec-format@${SPEC_V}"

# ─── Artifact scan ────────────────────────────────────────
# Look for ido4specs outputs in the standard locations
CANVAS=$(ls specs/*-tech-canvas.md docs/specs/*-tech-canvas.md 2>/dev/null | head -1)
SPEC=$(ls specs/*-tech-spec.md docs/specs/*-tech-spec.md 2>/dev/null | head -1)
STRATEGIC=$(ls specs/*-strategic-spec.md specs/*-spec.md docs/specs/*-strategic-spec.md ./*-spec.md 2>/dev/null | head -1)

if [ -n "$SPEC" ]; then
  echo "Pipeline: technical spec ready at ${SPEC}."
  echo "  Next: /ido4specs:validate-spec ${SPEC}  or  /ido4specs:review-spec ${SPEC}  or  /ido4specs:refine-spec ${SPEC}"
elif [ -n "$CANVAS" ]; then
  echo "Pipeline: canvas from a previous session at ${CANVAS}. Technical spec not yet produced."
  echo "  Next: /ido4specs:synthesize-spec ${CANVAS}"
elif [ -n "$STRATEGIC" ]; then
  echo "Pipeline: strategic spec found at ${STRATEGIC}. No ido4specs artifacts yet."
  echo "  Next: /ido4specs:create-spec ${STRATEGIC}"
else
  echo "Pipeline: no spec artifacts found. Place a strategic spec in this project and run /ido4specs:create-spec <path>."
fi
