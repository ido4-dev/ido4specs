#!/bin/bash
# SessionStart status scan — polite by default, artifact-aware when relevant.
# Runs in the USER's project directory (not the plugin directory).
# Output is injected into the model's context for the first response.
#
# Behavior:
#   - If spec artifacts exist (strategic/canvas/tech spec): emit version + pipeline guidance.
#   - If no artifacts AND first session in this project: emit one-time greeting, mark project.
#   - If no artifacts AND already greeted: stay silent (zero context noise).

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ─── Version data ─────────────────────────────────────────
VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "?")
TECH_V=$(cat "$PLUGIN_ROOT/dist/.tech-spec-format-version" 2>/dev/null | tr -d '[:space:]' || echo "?")
SPEC_V=$(cat "$PLUGIN_ROOT/dist/.spec-format-version" 2>/dev/null | tr -d '[:space:]' || echo "?")

# ─── Artifact scan ────────────────────────────────────────
# Look for ido4specs outputs in the standard locations
CANVAS=$(ls specs/*-tech-canvas.md docs/specs/*-tech-canvas.md 2>/dev/null | head -1)
SPEC=$(ls specs/*-tech-spec.md docs/specs/*-tech-spec.md 2>/dev/null | head -1)
STRATEGIC=$(ls specs/*-strategic-spec.md specs/*-spec.md docs/specs/*-strategic-spec.md ./*-spec.md 2>/dev/null | head -1)

if [ -n "$SPEC" ]; then
  echo "ido4specs v${VERSION} | tech-spec-format@${TECH_V} | spec-format@${SPEC_V}"
  echo "Pipeline: technical spec ready at ${SPEC}."
  echo "  Next: /ido4specs:validate-spec ${SPEC}  or  /ido4specs:review-spec ${SPEC}  or  /ido4specs:refine-spec ${SPEC}"
elif [ -n "$CANVAS" ]; then
  echo "ido4specs v${VERSION} | tech-spec-format@${TECH_V} | spec-format@${SPEC_V}"
  echo "Pipeline: canvas from a previous session at ${CANVAS}. Technical spec not yet produced."
  echo "  Next: /ido4specs:synthesize-spec ${CANVAS}"
elif [ -n "$STRATEGIC" ]; then
  echo "ido4specs v${VERSION} | tech-spec-format@${TECH_V} | spec-format@${SPEC_V}"
  echo "Pipeline: strategic spec found at ${STRATEGIC}. No ido4specs artifacts yet."
  echo "  Next: /ido4specs:create-spec ${STRATEGIC}"
else
  # No artifacts — first-time greeting per project, then silent.
  if [ -n "$CLAUDE_PLUGIN_DATA" ]; then
    PROJECT_HASH=$(echo -n "$PWD" | shasum -a 256 2>/dev/null | cut -c1-16)
    [ -z "$PROJECT_HASH" ] && PROJECT_HASH=$(echo -n "$PWD" | md5 2>/dev/null | cut -c1-16)
    [ -z "$PROJECT_HASH" ] && PROJECT_HASH="default"
    WELCOME_MARKER="${CLAUDE_PLUGIN_DATA}/welcomed-${PROJECT_HASH}"
    if [ ! -f "$WELCOME_MARKER" ]; then
      echo "[ido4specs first-install greeting — please surface this introduction in your first reply to the user, then ask how you can help]"
      echo "ido4specs v${VERSION} is loaded in this project. No spec artifacts here yet — the plugin is staying out of the way until needed."
      echo "Tell the user, in your own words: to start, run /ido4specs:create-spec <strategic-spec-path>. To see the pipeline in action without writing a spec first, they can try /ido4specs:create-spec ${PLUGIN_ROOT}/references/example-strategic-spec.md (a bundled example). Mention this intro won't repeat in this project — they can ask 'how do I use ido4specs?' anytime to recall the help skill, or run /ido4specs:doctor for diagnostics."
      mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null
      touch "$WELCOME_MARKER" 2>/dev/null || true
    fi
  fi
  # Silent if welcomed already, or if CLAUDE_PLUGIN_DATA is unavailable.
fi
