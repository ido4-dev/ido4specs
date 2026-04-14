#!/bin/bash
# Release script: bump version, update changelog, commit, push ido4specs.
# Marketplace sync happens automatically via sync-marketplace.yml CI workflow.
# Usage: bash scripts/release.sh [--yes] [--dry-run] [patch|minor|major] "Release message"
# Default: patch
#
# Flags:
#   --yes       Auto-confirm warnings (for agent/CI use). Errors still abort.
#   --dry-run   Run pre-flight only, do not bump / commit / push.

set -e

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"

YES_FLAG=false
DRY_RUN=false
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --yes) YES_FLAG=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

BUMP_TYPE="${1:-patch}"
MESSAGE="${2:-Release}"

# ─── Pre-flight: Claude CLI ────────────────────────────────

if ! command -v claude &>/dev/null; then
  echo "WARNING: 'claude' CLI not found — changelog will use deterministic generation"
elif ! echo "ok" | claude -p --no-session-persistence --max-turns 1 --output-format text &>/dev/null; then
  echo "WARNING: 'claude' CLI not logged in — changelog will use deterministic generation"
  echo "  Run 'claude /login' for LLM-powered changelog entries"
  echo ""
fi

# ─── Pre-flight: Bundle Validation (dual bundle) ───────────
#
# ido4specs ships TWO bundled validators, both committed to dist/:
#   - tech-spec-validator.js (@ido4/tech-spec-format) — Layer 1 for produced specs
#   - spec-validator.js      (@ido4/spec-format)      — parses upstream strategic specs
#
# Both must pass the version-marker check and (when npm is reachable) be at or
# near the latest npm version. We warn but don't fail on drift unless --yes is
# false and the user declines to proceed.

check_bundle() {
  local label="$1"
  local bundle_file="$2"
  local version_file="$3"
  local npm_package="$4"
  local header_match="$5"

  if [ ! -f "$bundle_file" ]; then
    echo "ERROR: $bundle_file not found."
    echo "Run: scripts/update-${label}-validator.sh <version>"
    exit 1
  fi

  if ! head -3 "$bundle_file" | grep -q "$header_match"; then
    echo "ERROR: $bundle_file missing version header — not a valid bundle"
    exit 1
  fi

  local bundled_version
  bundled_version=$(cat "$version_file" 2>/dev/null || echo "unknown")
  local latest_npm
  latest_npm=$(npm view "$npm_package" version 2>/dev/null || echo "unknown")

  if [ "$bundled_version" != "$latest_npm" ] && [ "$latest_npm" != "unknown" ]; then
    echo "WARNING: Bundled $label is v$bundled_version, latest on npm is v$latest_npm"
    echo "Consider running: scripts/update-${label}-validator.sh $latest_npm"
    if [ "$YES_FLAG" = "true" ]; then
      echo "  --yes flag: proceeding despite validator drift"
    else
      read -p "Continue anyway? [y/N] " -n 1 -r
      echo
      [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi
  fi

  echo "Pre-flight: $label v$bundled_version ✓"
}

check_bundle "tech-spec" \
  "$PLUGIN_DIR/dist/tech-spec-validator.js" \
  "$PLUGIN_DIR/dist/.tech-spec-format-version" \
  "@ido4/tech-spec-format" \
  "@ido4/tech-spec-format v"

check_bundle "spec" \
  "$PLUGIN_DIR/dist/spec-validator.js" \
  "$PLUGIN_DIR/dist/.spec-format-version" \
  "@ido4/spec-format" \
  "@ido4/spec-format v"

echo ""

# ─── Pre-flight: Local vs Remote Sync ──────────────────────

echo "Pre-flight: checking local vs origin/main..."
git fetch --quiet origin main 2>/dev/null || {
  echo "WARNING: Could not fetch origin/main (offline?). Skipping sync check."
  echo ""
}

if git rev-parse --verify origin/main >/dev/null 2>&1; then
  LOCAL_SHA=$(git rev-parse @)
  REMOTE_SHA=$(git rev-parse origin/main)
  BASE_SHA=$(git merge-base @ origin/main)

  if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
    echo "Pre-flight: local in sync with remote ✓"
    echo ""
  elif [ "$LOCAL_SHA" = "$BASE_SHA" ]; then
    AHEAD_COUNT=$(git rev-list --count @..origin/main)
    echo ""
    echo "ERROR: Your local main is behind origin/main by ${AHEAD_COUNT} commit(s)."
    echo ""
    echo "This usually means the cross-repo sync pipeline auto-merged a PR"
    echo "(e.g., a tech-spec-format validator update from ido4) into the remote"
    echo "since you last pulled. The pipeline runs without your involvement,"
    echo "so your local clone doesn't know about it until you fetch."
    echo ""
    echo "Commits on remote that you don't have locally:"
    git log --oneline @..origin/main | sed 's/^/  /'
    echo ""
    echo "To resolve, pull the missing commits and re-run the release:"
    echo "  git pull --ff-only origin main"
    echo "  bash scripts/release.sh ${BUMP_TYPE} \"${MESSAGE}\""
    exit 1
  elif [ "$REMOTE_SHA" = "$BASE_SHA" ]; then
    BEHIND_COUNT=$(git rev-list --count origin/main..@)
    echo "Pre-flight: local has ${BEHIND_COUNT} unpushed commit(s) ahead of remote — ok, continuing"
    echo ""
  else
    LOCAL_ONLY=$(git rev-list --count origin/main..@)
    REMOTE_ONLY=$(git rev-list --count @..origin/main)
    echo ""
    echo "ERROR: Local and remote main have diverged."
    echo ""
    echo "Your local has ${LOCAL_ONLY} commit(s) that aren't on remote AND"
    echo "remote has ${REMOTE_ONLY} commit(s) that aren't on local. This needs"
    echo "manual resolution — most likely you made a local commit while the"
    echo "auto-update pipeline merged a PR upstream."
    echo ""
    echo "Local-only commits:"
    git log --oneline origin/main..@ | sed 's/^/  /'
    echo ""
    echo "Remote-only commits:"
    git log --oneline @..origin/main | sed 's/^/  /'
    echo ""
    echo "To resolve:"
    echo "  1. Inspect the remote commits above to understand what landed"
    echo "  2. Rebase your local work on top of remote:"
    echo "       git pull --rebase origin main"
    echo "  3. Re-run the release once main is unified:"
    echo "       bash scripts/release.sh ${BUMP_TYPE} \"${MESSAGE}\""
    exit 1
  fi
fi

# ─── Pre-flight: Plugin Validation Suite ───────────────────

echo "Pre-flight: running plugin validation suite..."
VALIDATE_LOG=$(mktemp)
if ! bash "$PLUGIN_DIR/tests/validate-plugin.sh" > "$VALIDATE_LOG" 2>&1; then
  echo "ERROR: Plugin validation failed. Aborting release."
  echo ""
  echo "--- Last 40 lines of validation output ---"
  tail -40 "$VALIDATE_LOG"
  echo ""
  echo "Full log: $VALIDATE_LOG"
  exit 1
fi
PASS_COUNT=$(grep -c "PASS:" "$VALIDATE_LOG" 2>/dev/null || echo "0")
rm -f "$VALIDATE_LOG"
echo "Pre-flight: plugin validation ✓ ($PASS_COUNT checks passed)"
echo ""

if [ "$DRY_RUN" = "true" ]; then
  echo "=========================================="
  echo "DRY RUN: pre-flight passed. No changes made."
  echo "=========================================="
  exit 0
fi

# ─── Version Bump ──────────────────────────────────────────

CURRENT=$(python3 -c "
import json
d = json.load(open('$PLUGIN_DIR/.claude-plugin/plugin.json'))
print(d['version'])
")

NEW_VERSION=$(python3 -c "
parts = '$CURRENT'.split('.')
major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])
bump = '$BUMP_TYPE'
if bump == 'major':
    major += 1; minor = 0; patch = 0
elif bump == 'minor':
    minor += 1; patch = 0
else:
    patch += 1
print(f'{major}.{minor}.{patch}')
")

echo "Version: $CURRENT → $NEW_VERSION ($BUMP_TYPE)"
echo ""

python3 -c "
import json
path = '$PLUGIN_DIR/.claude-plugin/plugin.json'
d = json.load(open(path))
d['version'] = '$NEW_VERSION'
json.dump(d, open(path, 'w'), indent=2)
print('  Updated: plugin.json')
"

# ─── Update CHANGELOG ─────────────────────────────────────

CHANGELOG="$PLUGIN_DIR/CHANGELOG.md"
TODAY=$(date +%Y-%m-%d)

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_TAG" ]; then
  RANGE="${LAST_TAG}..HEAD"
else
  RANGE="HEAD"
fi

COMMITS=$(git log "$RANGE" --pretty=format:"%s" | grep -v "^v[0-9]" | grep -v "^Merge")
DIFF_STAT=$(git diff "$RANGE" --stat 2>/dev/null || echo "")

ENTRY=""
if command -v claude &>/dev/null; then
  echo "  Generating changelog with Claude (requires 'claude' CLI to be logged in)..."

  PROMPT="Write a CHANGELOG entry for a Claude Code plugin release.

Version: $NEW_VERSION ($BUMP_TYPE bump)
Release message: $MESSAGE

Commits since last release:
$COMMITS

Files changed:
$DIFF_STAT

Rules:
- Use ### Added, ### Changed, ### Fixed sections (only sections that apply)
- Group related commits into single coherent items — don't list every commit separately
- Write from the USER's perspective, not the developer's
- One line per item, starting with \"- \"
- Be concise — each item should be one sentence
- No preamble, no explanation — output ONLY the markdown sections"

  RAW_ENTRY=$(echo "$PROMPT" | claude -p --no-session-persistence --model haiku --output-format text --max-turns 1 2>/dev/null) || true
  ENTRY=$(echo "$RAW_ENTRY" | sed '/^```/d')
fi

if [ -z "$ENTRY" ]; then
  echo "  Generating changelog deterministically..."
  ENTRY=$(python3 -c "
import subprocess, re

range_arg = '$RANGE'
result = subprocess.run(
    ['git', 'log', range_arg, '--pretty=format:%s'],
    capture_output=True, text=True, cwd='$PLUGIN_DIR'
)
commits = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
commits = [c for c in commits if not c.startswith('v') and not c.startswith('Merge')]

changed, added, fixed = [], [], []
for c in commits:
    c = c.split('\n')[0].strip()
    if not c: continue
    m = re.match(r'^(feat|fix|docs|enhance|refactor|chore|test)[\(:]?\s*(.+)', c, re.IGNORECASE)
    if m:
        prefix = m.group(1).lower()
        desc = m.group(2).lstrip(': ').rstrip('.')
        desc = re.sub(r'^\([^)]+\)\s*:?\s*', '', desc)
        desc = desc[0].upper() + desc[1:] if desc else desc
    else:
        prefix, desc = '', c[0].upper() + c[1:] if c else c
    if prefix == 'fix': fixed.append(desc)
    elif prefix in ('feat','enhance'): added.append(desc)
    else: changed.append(desc)

lines = []
if added: lines += ['### Added'] + [f'- {x}' for x in added] + ['']
if changed: lines += ['### Changed'] + [f'- {x}' for x in changed] + ['']
if fixed: lines += ['### Fixed'] + [f'- {x}' for x in fixed] + ['']
print('\n'.join(lines) if lines else '- $MESSAGE')
")
fi

if [ -f "$CHANGELOG" ]; then
  python3 -c "
changelog = open('$CHANGELOG').read()
header = '# Changelog\n\n'
if changelog.startswith('# Changelog'):
    rest = changelog[len(header):]
else:
    rest = changelog

new_entry = '''## [$NEW_VERSION] — $TODAY

$MESSAGE

$ENTRY'''

open('$CHANGELOG', 'w').write(header + new_entry.rstrip() + '\n\n' + rest)
print('  Updated: CHANGELOG.md')
"
else
  echo "  WARNING: CHANGELOG.md not found — skipping"
fi

# Commit and push
echo ""
echo "=== Pushing ido4specs ==="
cd "$PLUGIN_DIR"
git add .claude-plugin/plugin.json CHANGELOG.md
git commit -m "v${NEW_VERSION}: ${MESSAGE}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push

echo ""
echo "==========================================="
echo "Released ido4specs v${NEW_VERSION}"
echo "==========================================="
echo ""
echo "CI will automatically:"
echo "  1. Run validation tests"
echo "  2. Sync to ido4-plugins marketplace"
echo "  3. Create GitHub release"
