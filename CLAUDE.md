## What pi is

**pi** = the minimal open-source terminal coding agent by Earendil Inc. / Mario Zechner. Repo `earendil-works/pi`, agent package `packages/coding-agent`. Philosophy: "primitives, not features" — tiny core, extended via TypeScript extensions, skills, prompt templates, themes, custom models/providers, and pi packages.

## Where the docs are

A local pinned snapshot of pi's docs + example extensions lives in **`vendor/pi-docs/`**. Read/grep it to answer pi questions or customize pi.

- `vendor/pi-docs/docs/` — all doc markdown (+ `docs.json` manifest)
- `vendor/pi-docs/examples-extensions/` — example extensions, best reference for customization
- `vendor/pi-docs/FETCHED.md` — snapshot date/commit + how to refresh (refresh only when the user asks)

## Operational guides (ours)

Hand-written runbooks for operating pi (authored by us, **not** from upstream) live
in **`guides/`**. Keep these out of `vendor/` — that subtree is the regenerated
upstream mirror.

- `guides/spawning-wsl-windows.md` — reliably launch `pi` in a new Windows terminal
  window from inside WSL2 (`Start-Process wsl.exe`).
