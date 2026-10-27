# pi extension lifecycle: cleanup & session-replacement safety

LLM reference. Failure modes + required patterns for any long-lived pi extension
(esp. hub/spoke ones that spawn background processes or stash `ctx` for timers).
Event list is upstream in `vendor/pi-docs/docs/extensions.md`; this file is only the
gotchas that doc omits. Patterns are inline and self-contained.

## Rule 1 — stale ctx AND stale `pi` throw; never touch them bare from out-of-turn code

`session_start` hands a `ctx`; extensions stash it for timers/async handlers:
`let lastCtx = null; pi.on("session_start", (_e, ctx) => { lastCtx = ctx; })`.

After a session replacement (`/new` `/resume` `/fork` `/clone`) or `await ctx.reload()`
the captured ctx is dead. Reading `ctx.hasUI` — or calling ANY ctx method
(`getContextUsage()`, `model`, `ui.*`) — on a dead ctx **THROWS** (`assertActive`).
It is not falsy. `lastCtx?.hasUI` does NOT protect: `?.` guards null, not stale.

The captured `pi` (factory arg) goes stale at the same moment: nearly every `pi.*`
method — `sendMessage`, `sendUserMessage`, `appendEntry`, `exec`, `setActiveTools`,
`getFlag`, `events.emit/on`, … — calls `assertActive()` and throws the same error
(installed `dist/core/extensions/loader.js` `createExtensionAPI`). `uiActive()` below
does not cover it. Gate every out-of-turn `pi.*` call on the `disposed` latch
(Rule 2) and wrap it in try/catch. `pi.events.on` subscriptions are removed for you
on invalidation (`runtime.trackEventBusSubscription`); timers and child processes are not.

A throw from a `setInterval` / transport handler / watchdog runs outside any turn →
uncaught → crash.

Required guard, used at every out-of-turn ctx access:

```typescript
function uiActive(): boolean {
  try { return !!lastCtx?.hasUI; } catch { return false; }
}
if (uiActive()) lastCtx!.ui.notify("…");
```

Also: wrap `rerender(ctx)` bodies in try/catch; read `getContextUsage()`/`model` in a
heartbeat builder inside try/catch (fall back to undefined — they throw, not null).

Applies to: `setInterval` heartbeats/reapers, transport message handlers, watchdog
`setTimeout`, and any work a `session_shutdown` handler starts WITHOUT awaiting.
pi awaits every `session_shutdown` handler in sequence and only then invalidates the
runtime (`agent-session-runtime.js` `teardownCurrent`/`dispose` →
`session.dispose()`; `agent-session.js` `reload()`), so ctx/`pi` are live for the
awaited part of the handler; a fire-and-forget promise from it is not.

NOT needed inside a live turn (tool/command handlers) EXCEPT after the handler
itself replaces the session or reloads — the ctx and `pi` in that same handler are
then dead and throw (`runner.js` `invalidate()` message; `docs/extensions.md`
"Context and session changes"):

- `ctx.newSession()` / `ctx.fork()` / `ctx.switchSession()`: do follow-up work in the
  `withSession: async (newCtx) => …` option using `newCtx` (`ReplacedSessionContext`,
  `types.ts`). Capture only plain data before the call.
- `await ctx.reload()`: touch neither ctx nor `pi` afterwards; the reloaded
  extension instance gets its own `session_start`.

## Rule 2 — session_shutdown fires on replacement too; latch detached bring-up

`session_shutdown` fires on exit (Ctrl+C/Ctrl+D/SIGHUP/SIGTERM; in `--mode rpc` also
stdin close and `ctx.shutdown()`, which waits for the current command or the active
run's `agent_settled` — `docs/rpc.md` "Shutdown") AND on every reload/replacement.
On `new`/`resume`/`fork` pi first aborts and settles the active run
(`teardownCurrent` → `session.abort()`); quit and reload do not abort first.

Branch on `event.reason` (`types.ts`):
- `SessionShutdownEvent.reason`: `"quit" | "reload" | "new" | "resume" | "fork"`;
  `targetSessionFile` = destination on replacement.
- `SessionStartEvent.reason`: `"startup" | "reload" | "new" | "resume" | "fork"`;
  `previousSessionFile` on `new`/`resume`/`fork`.

To keep a shared helper (server, device link) across reload/replacement, skip its
teardown unless `reason === "quit"`, and on `session_start` re-discover it via the
idempotent reuse in Rule 3 (pidfile/port probe). The factory re-runs per runtime and
reload re-imports the module, so an in-memory handle won't survive.

If `session_start` launches bring-up detached
(`void autoBringUp()`), a replacement fires `session_shutdown` mid-bring-up → it
keeps spawning servers/driving devices AFTER teardown (orphans) + touches the stale
ctx (Rule 1).

Required: a latch, set FIRST in shutdown, reset in start, re-checked between every
async step; reap on late flip.

```typescript
let disposed = false;
pi.on("session_start",   (_e, ctx) => { lastCtx = ctx; disposed = false; void autoBringUp(); });
pi.on("session_shutdown", async () => { disposed = true; /* teardown… */ });

async function autoBringUp() {
  if (disposed) return;
  await usbAttach();           if (disposed) return;
  const dev = await devUp();
  if (disposed) { await devDown(); return; } // shutdown's teardown ran before these existed → reap
  spawnSpoke();
}
```

- Latch BEFORE the teardown cascade so an in-flight step observes it.
- If teardown already ran (before a spawn existed), the spawn step must reap what it
  just started.
- One flag only. If a `shuttingDown` re-entrancy guard already exists for graceful
  shutdown, also SET it in the `session_shutdown` handler and READ it between
  bring-up steps — do not add a second flag.

## Rule 3 — reap background children on shutdown; kill the group, not the name

`spawn(…, { detached: true })` + `unref()` outlives the turn AND the whole extension.
Nothing reaps it unless `session_shutdown` does.

Killing by command name (`pkill -f "just X"`) kills only the wrapper; the child that
binds the port (e.g. expo/bun on a port) survives, orphans, holds the port, wedges
the next launch. `detached:true` makes the child a process-group leader → signal the
NEGATIVE pid to hit the whole tree. Graceful first (SIGINT = a real Ctrl+C: servers
release ports/flush), grace window, then SIGKILL survivors; backstop a re-sessioned
child by killing whatever holds the port (`ss`/`lsof`).

```typescript
process.kill(-pgid, "SIGINT");   // whole group, graceful
// poll until gone or grace window, then process.kill(-pgid, "SIGKILL")
// then kill any pid still listening on the known port
```

Prefer the upstream (unreleased, after 1.4.0) bash-abort fix for the SIGKILL step:
`process.kill(-pgid, "SIGSTOP")` then `"SIGKILL"`, so a shell list `a; b` can't
advance to `b` between signals.

pi does NOT do this for you:
- `pi.exec` on abort/timeout sends SIGTERM to the direct child only (`shell:false`,
  no group), never the process group (`dist/core/exec.js`). Its 5 s SIGKILL fallback
  is guarded by `!proc.killed`, which Node sets once SIGTERM is delivered, so in
  practice it never fires. Not a substitute for detached spawn + negative-pid kill.
- pi's own SIGTERM/SIGHUP handler (`killTrackedDetachedChildren`, `utils/shell.js`)
  reaps only children of its built-in bash tool; there is no public API to register
  an extension's children. Rule 3 stays required.

Unkillable/privileged helpers (e.g. a root monitor a user-owned extension can't
signal): do NOT attempt teardown. Make bring-up IDEMPOTENT — detect an existing
instance and reuse it, never spawn a second — and leave the one instance running
across sessions.

## Rule 4 — logfile-based readiness must not match a prior run

If bring-up backgrounds a process to a logfile and detects ready by regex over that
file: open the log with `"w"` (truncate per run), not `"a"`, and/or scan only bytes
written after spawn. Append + whole-file scan → a previous run's ready line matches
instantly → reports ready before this run's process is up. A port/PID probe likewise
can't distinguish your fresh server from a leftover orphan on the same port — reap
orphans first (Rule 3).

## Checklist

- Out-of-turn ctx access → `uiActive()` / try-catch. Never bare `lastCtx?.hasUI`.
- Out-of-turn `pi.*` call → gated on `disposed` + try-catch.
- After own `newSession/fork/switchSession` → work in `withSession(newCtx)`; after
  `await ctx.reload()` → no ctx/`pi`.
- `rerender` + heartbeat/status builder swallow stale-ctx throws.
- `disposed`/`shuttingDown` latch: set first in shutdown, reset in start, checked
  between bring-up steps, reap on late flip.
- `session_shutdown` reaps every `detached`+`unref`'d child (shared helpers: only on
  `reason === "quit"`, then reuse idempotently).
- Kill by process group (SIGINT → grace → SIGKILL), backstop by port. Not by name.
- Privileged/unkillable helper → idempotent reuse, leave one running.
- Logfile readiness → truncate per run; don't trust a port a stranger could answer.
