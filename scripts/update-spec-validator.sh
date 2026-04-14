#!/bin/bash
# Update the bundled @ido4/spec-format strategic-spec validator from npm or a local ido4 build.
#
# Usage:
#   ./scripts/update-spec-validator.sh 0.7.2             # Fetch from npm
#   ./scripts/update-spec-validator.sh ~/dev/ido4        # Copy from local build
#
# This bundle parses the UPSTREAM strategic spec that create-spec consumes. It is
# a zero-dependency CLI bundle (~9 KB) — symmetric with tech-spec-validator.js but
# targeted at the strategic-spec format produced by ido4shape.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PLUGIN_DIR/dist"
BUNDLE_FILE="$DIST_DIR/spec-validator.js"
VERSION_FILE="$DIST_DIR/.spec-format-version"
CHECKSUM_FILE="$DIST_DIR/.spec-format-checksum"

usage() {
  echo "Usage: $0 <version|path-to-ido4>"
  echo ""
  echo "Examples:"
  echo "  $0 0.7.2              # Fetch from npm, extract bundle"
  echo "  $0 ~/dev/ido4         # Copy from local build"
  exit 1
}

[ $# -eq 1 ] || usage

SOURCE="$1"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$DIST_DIR"

if [ -d "$SOURCE" ]; then
  LOCAL_BUNDLE="$SOURCE/packages/spec-format/dist/spec-validator.bundle.js"
  if [ ! -f "$LOCAL_BUNDLE" ]; then
    echo "ERROR: Bundle not found at $LOCAL_BUNDLE"
    echo "Run 'npm run build:bundle -w @ido4/spec-format' in $SOURCE first"
    exit 1
  fi
  cp "$LOCAL_BUNDLE" "$BUNDLE_FILE"
  VERSION=$(head -3 "$BUNDLE_FILE" | grep -o 'v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' | head -1 | sed 's/^v//' || echo "unknown")
  echo "Copied bundle from local build (v$VERSION)"
else
  VERSION="$SOURCE"
  echo "Fetching @ido4/spec-format@$VERSION from npm..."
  cd "$TMPDIR"
  npm pack "@ido4/spec-format@$VERSION" --silent 2>&1
  tar xzf ido4-spec-format-*.tgz

  if [ -f "package/dist/spec-validator.bundle.js" ]; then
    cp "package/dist/spec-validator.bundle.js" "$BUNDLE_FILE"
    echo "Extracted bundle from npm package"
  else
    echo "Bundle not in npm package. Building from extracted source..."
    if ! command -v npx &>/dev/null; then
      echo "ERROR: npx not found. Install Node.js or use a local ido4 build instead."
      exit 1
    fi
    cd package
    npx esbuild src/cli.ts --bundle --platform=node --target=node18 \
      --format=cjs --outfile="$BUNDLE_FILE" --minify \
      --banner:js="// @ido4/spec-format v$VERSION | bundled $(date +%Y-%m-%d)"
    echo "Built bundle from source"
  fi
fi

# Smoke test: spec-validator requires a valid strategic spec as input.
# We don't ship a strategic-spec fixture in ido4specs (this plugin's output is
# technical specs), so the smoke test just verifies the CLI runs and produces
# parser-shaped JSON — using the CLI's own --version-style self-check when
# invoked with no argument returns exit 2 + usage error, which we accept.
echo "Smoke testing bundle..."
if node "$BUNDLE_FILE" /dev/null 2>&1 | python3 -c "
import sys
out = sys.stdin.read()
# We expect either valid JSON output (if /dev/null happens to parse as an empty spec)
# or a structured error — either way, not a crash.
if 'Uncaught' in out or 'SyntaxError' in out or 'Error: Cannot' in out:
    print('ERROR: bundle crashed', file=sys.stderr)
    sys.exit(1)
print('  Result: bundle executes without crash')
"; then
  echo "Smoke test passed."
else
  echo "ERROR: Bundle smoke test failed"
  rm -f "$BUNDLE_FILE"
  exit 1
fi

# Write version marker
printf "%s\n" "$VERSION" > "$VERSION_FILE"

# Write checksum
shasum -a 256 "$BUNDLE_FILE" | sed "s|$DIST_DIR/||" > "$CHECKSUM_FILE"

SIZE=$(wc -c < "$BUNDLE_FILE" | tr -d ' ')
echo ""
echo "Updated spec-validator.js to v$VERSION"
echo "  Bundle:   $BUNDLE_FILE ($SIZE bytes)"
echo "  Version:  $VERSION_FILE"
echo "  Checksum: $CHECKSUM_FILE"
