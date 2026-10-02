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
# The docs are now guides that defer to source for exact API shapes (events, ctx,
# RPC, session format) and link ../examples + ../src relative to docs/. Mirroring
# that layout under $DEST keeps those links resolving locally.
SRC_FILES=(
  "$SUB/src/core/extensions/types.ts"
  "$SUB/src/modes/rpc/rpc-types.ts"
  "$SUB/src/core/session-manager.ts"
  "$SUB/src/core/messages.ts"
  "$SUB/src/core/compaction/compaction.ts"
  "$SUB/src/core/compaction/branch-summarization.ts"
  "$SUB/src/core/compaction/utils.ts"
  "$SUB/src/modes/interactive/theme/theme-schema.json"
)
OTHER_TYPES=(packages/ai/src/types.ts packages/agent/src/types.ts)
git -C "$CLONE" sparse-checkout set --no-cone \
  "/$SUB/docs/" "/$SUB/examples/extensions/" "/$SUB/examples/sdk/" \
  "/$SUB/examples/rpc-client.ts" "/$SUB/examples/rpc-extension-ui.ts" \
  "${SRC_FILES[@]/#//}" "${OTHER_TYPES[@]/#//}"

SHA="$(git -C "$CLONE" rev-parse HEAD)"
TODAY="$(date +%F)"

rm -rf "$DEST/docs" "$DEST/examples" "$DEST/src" "$DEST/packages"
cp -r "$CLONE/$SUB/docs" "$DEST/docs"
mkdir -p "$DEST/examples"
cp -r "$CLONE/$SUB/examples/extensions" "$CLONE/$SUB/examples/sdk" "$CLONE/$SUB/examples/rpc-client.ts" "$CLONE/$SUB/examples/rpc-extension-ui.ts" "$DEST/examples/"
for f in "${SRC_FILES[@]}"; do
  rel="${f#"$SUB/"}"
  mkdir -p "$DEST/$(dirname "$rel")"
  cp "$CLONE/$f" "$DEST/$rel"
done
for f in "${OTHER_TYPES[@]}"; do
  mkdir -p "$DEST/$(dirname "$f")"
  cp "$CLONE/$f" "$DEST/$f"
done
rm -rf "$CLONE"

# Recount the snapshot so the Paths line never goes stale.
MD="$(find "$DEST/docs" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
EX_DIRS="$(find "$DEST/examples/extensions" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')"
EX_TS="$(find "$DEST/examples/extensions" -maxdepth 1 -mindepth 1 -name '*.ts' | wc -l | tr -d ' ')"

# Update the stamp in FETCHED.md (Commit + Fetched + Paths)
sed -i -E \
  -e "s|^- \*\*Commit:\*\* .*|- **Commit:** \`$SHA\`|" \
  -e "s|^- \*\*Fetched:\*\* .*|- **Fetched:** $TODAY|" \
  -e "s|^- \*\*Paths:\*\* .*|- **Paths:** \`docs/\` ($MD md + \`docs.json\`), \`examples/extensions/\` ($EX_DIRS example projects + $EX_TS single-file extensions), \`examples/sdk/\` + RPC clients, \`src/\` + \`packages/\` (upstream type sources the docs link to)|" \
  "$DEST/FETCHED.md"

echo "pi docs snapshot refreshed → commit $SHA ($TODAY)"
