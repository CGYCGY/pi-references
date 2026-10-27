# pi docs snapshot — freshness stamp

Pinned, manual-refresh snapshot (NOT a live mirror). Treat as source of truth for pi questions/customization. If a topic or API is absent here, don't conclude pi lacks it — it may be newer than this snapshot; say so and suggest a refresh.

- **Source:** https://github.com/earendil-works/pi (`packages/coding-agent`)
- **Commit:** `6c384aa30f619d7b28963f2bab24d8dacbe73cb6`
- **Fetched:** 2026-10-27
- **Paths:** `docs/` (42 md + `docs.json`), `examples/extensions/` (9 example projects + 70 single-file extensions), `examples/sdk/` + RPC clients, `src/` + `packages/` (upstream type sources the docs link to), `schemas/` (generated config schemas)

## Refresh (only when the user explicitly asks)

Run `vendor/pi-docs/refresh.sh` — it re-clones upstream, overwrites the snapshot, and auto-updates **Commit**, **Fetched** and **Paths** above.
