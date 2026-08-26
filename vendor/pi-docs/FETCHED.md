# pi docs snapshot — freshness stamp

Pinned, manual-refresh snapshot (NOT a live mirror). Treat as source of truth for pi questions/customization. If a topic or API is absent here, don't conclude pi lacks it — it may be newer than this snapshot; say so and suggest a refresh.

- **Source:** https://github.com/earendil-works/pi (`packages/coding-agent`)
- **Commit:** `8fa7eebd235355522c8104166b4f1f959b4e2f10`
- **Fetched:** 2026-08-26
- **Paths:** `docs/` (30 md + `docs.json`), `examples-extensions/` (9 example projects + 69 single-file extensions)

## Refresh (only when the user explicitly asks)

Run `vendor/pi-docs/refresh.sh` — it re-clones upstream, overwrites the snapshot, and auto-updates **Commit** + **Fetched** above.
