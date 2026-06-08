# pi-references

Personal reference for **pi** — the minimal open-source terminal coding agent
([`earendil-works/pi`](https://github.com/earendil-works/pi)).

Two layers:

- **`vendor/pi-docs/`** — a pinned snapshot of pi's upstream docs + example
  extensions. Read/grep it to answer pi questions or customize pi. It's a manual
  mirror, not live — see [`vendor/pi-docs/FETCHED.md`](vendor/pi-docs/FETCHED.md)
  for the pinned commit and fetch date.
- **`guides/`** — our own hand-written runbooks for operating pi (not from
  upstream), e.g. [spawning a pi window from WSL2](guides/spawning-wsl-windows.md).

[`CLAUDE.md`](CLAUDE.md) is the index an agent reads first.

## Refreshing the docs snapshot

Run `vendor/pi-docs/refresh.sh` — it re-clones upstream, overwrites the snapshot,
and restamps the commit / date / path counts in `FETCHED.md`. Run only when you
want to update.
