#!/usr/bin/env bash
# Repro: `mr sync` updates devenv.lock/flake.lock but NOT nested megarepo.lock files
#
# Prerequisites: `mr` (megarepo CLI) in PATH
#
# This script:
# 1. Creates a temporary parent megarepo referencing effect-ts/effect + this repo
# 2. Runs `mr sync` to populate members
# 3. Shows that the nested megarepo.lock (in this repo) is NOT updated
#    even though the parent has a newer effect commit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The "old" effect commit baked into this repo's megarepo.lock
OLD_EFFECT_COMMIT="12b1f1eadf649e30dec581b7351ba3abb12f8004"
# A newer effect commit (the parent will track this)
NEW_EFFECT_COMMIT="ab3b64c20a039eb4d573fe757c41278925b22687"

echo "=== Setup ==="
echo "This repo's megarepo.lock has effect @ ${OLD_EFFECT_COMMIT:0:12} (old)"
echo "Parent megarepo will track effect @ ${NEW_EFFECT_COMMIT:0:12} (new)"
echo ""

# Create a temporary parent megarepo
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

cd "$TMPDIR"

cat > megarepo.json << MJSON
{
  "members": {
    "effect": "effect-ts/effect",
    "nested-megarepo": "schickling-repros/2026-02-mr-nested-megarepo-lock"
  }
}
MJSON

echo "=== Step 1: mr sync (initial — populates store + lock) ==="
mr sync 2>&1 | tail -1 | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'  Synced {len(d[\"results\"])} members')" || true
echo ""

echo "=== Step 2: Verify parent megarepo.lock has latest effect commit ==="
PARENT_EFFECT=$(python3 -c "import json; print(json.load(open('megarepo.lock'))['members']['effect']['commit'])")
echo "  Parent effect commit: ${PARENT_EFFECT:0:12}"
echo ""

echo "=== Step 3: Check nested megarepo.lock ==="
NESTED_LOCK="repos/nested-megarepo/megarepo.lock"
if [ ! -f "$NESTED_LOCK" ]; then
  echo "  ERROR: nested megarepo.lock not found at $NESTED_LOCK"
  exit 1
fi

NESTED_EFFECT=$(python3 -c "import json; print(json.load(open('$NESTED_LOCK'))['members']['effect']['commit'])")
echo "  Nested effect commit: ${NESTED_EFFECT:0:12}"
echo ""

echo "=== Result ==="
if [ "$PARENT_EFFECT" != "$NESTED_EFFECT" ]; then
  echo "  BUG CONFIRMED: nested megarepo.lock was NOT updated by mr sync"
  echo "  Parent:  ${PARENT_EFFECT:0:12}"
  echo "  Nested:  ${NESTED_EFFECT:0:12}"
  echo ""
  echo "  Expected: mr sync should update nested megarepo.lock entries"
  echo "  Actual:   only devenv.lock/flake.lock are updated, megarepo.lock is ignored"
  exit 1
else
  echo "  No drift — nested megarepo.lock is in sync (bug may be fixed)"
  exit 0
fi
