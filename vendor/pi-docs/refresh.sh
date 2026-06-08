#!/usr/bin/env bash
# Refresh the pinned pi docs snapshot from upstream.
# Run only when the user explicitly asks to update pi docs.
set -euo pipefail

# Self-locating: DEST is this script's own directory (vendor/pi-docs),
# so the script survives the tree being moved/renamed.
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="$DEST/.pi-clone"
REPO="https://github.com/earendil-works/pi.git"
SUB="packages/coding-agent"

rm -rf "$CLONE"
git clone --depth 1 --filter=blob:none --sparse "$REPO" "$CLONE"
git -C "$CLONE" sparse-checkout set "$SUB/docs" "$SUB/examples/extensions"

SHA="$(git -C "$CLONE" rev-parse HEAD)"
TODAY="$(date +%F)"

rm -rf "$DEST/docs" "$DEST/examples-extensions"
cp -r "$CLONE/$SUB/docs" "$DEST/docs"
cp -r "$CLONE/$SUB/examples/extensions" "$DEST/examples-extensions"
rm -rf "$CLONE"

# Recount the snapshot so the Paths line never goes stale.
MD="$(find "$DEST/docs" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
EX_DIRS="$(find "$DEST/examples-extensions" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')"
EX_TS="$(find "$DEST/examples-extensions" -maxdepth 1 -mindepth 1 -name '*.ts' | wc -l | tr -d ' ')"

# Update the stamp in FETCHED.md (Commit + Fetched + Paths)
sed -i -E \
  -e "s|^- \*\*Commit:\*\* .*|- **Commit:** \`$SHA\`|" \
  -e "s|^- \*\*Fetched:\*\* .*|- **Fetched:** $TODAY|" \
  -e "s|^- \*\*Paths:\*\* .*|- **Paths:** \`docs/\` ($MD md + \`docs.json\`), \`examples-extensions/\` ($EX_DIRS example projects + $EX_TS single-file extensions)|" \
  "$DEST/FETCHED.md"

echo "pi docs snapshot refreshed → commit $SHA ($TODAY)"
