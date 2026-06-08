# Spawning a pi window from inside WSL2

How to reliably launch a new **visible Windows terminal window** running a command
(e.g. `pi`, or a spoke shell) from *inside* a WSL2 distro. Three launchers were
tested; only one is recommended.

## TL;DR

Use **PowerShell `Start-Process wsl.exe`**. Set the working directory with
`wsl --cd` (launcher-independent). Avoid `wt.exe` for passing a command from WSL —
it silently exits 0 while mangling the command.

```bash
# Recommended
powershell.exe -NoProfile -Command "Start-Process wsl.exe -ArgumentList '-d Debian --cd ~ -- bash -lic \"echo HELLO; sleep 30\"'"
```

```bash
# Solid fallback (cmd) — note the mandatory empty "" title
cmd.exe /c start "" wsl.exe -d Debian --cd ~ -- bash -lic 'echo HELLO; sleep 30'
```

## Results

Each candidate was launched from WSL2, running a `bash -lc` payload that writes a
proof-marker file (capturing hostname/pwd) and then runs `echo HELLO; sleep N`.
"Spawned?" means the marker file was actually written **and** a live process /
visible window appeared.

| # | Candidate | Exit 0? | Process actually spawned? | Verdict |
|---|-----------|---------|---------------------------|---------|
| 1 | `wt.exe -w 0 nt -p Debian wsl.exe …` | ✅ yes | ❌ no — marker never written | Unreliable / broken |
| 2 | `cmd.exe /c start "" wsl.exe …` | ✅ yes | ✅ yes (visible console window, marker written) | Works, with sharp edges |
| 3 | `powershell.exe -c Start-Process wsl.exe …` | ✅ yes | ✅ yes (visible window, marker written, correct pwd) | ✅ Best / recommended |

## Why candidate 1 (`wt.exe`) fails

Exit code is always 0, so it *looks* fine, but nothing useful runs. `wt.exe` splits
the single command into separate junk tabs (`echo HELLO`, `sleep 30`, `sleep 120`)
and throws `0x80070002` — "system cannot find the file specified." Two compounding
causes:

- `wt.exe` treats `;` on its own command line as a tab/pane delimiter, so
  `echo HELLO; sleep 30` becomes multiple commands.
- Invoked from a WSL shell, the inner `'…'` quoting is stripped by the launching WSL
  process before `wt.exe` sees it, so `wt` re-tokenizes the bash script on
  whitespace. Even a semicolon-free `&&` variant fails (marker still missing).

It is fundamentally fragile for passing an arbitrary command from inside WSL.

## Why candidate 2 (`cmd start`) works but is finicky

- **Empty title is mandatory:** `start "" wsl.exe …`. `start "pi-window" wsl.exe …`
  fails with "Windows cannot find 'pi-window'" — `start` consumes the first quoted
  token as the program name. The `""` placeholder is required.
- Prints `UNC paths are not supported. Defaulting to Windows directory.` because
  `cmd` can't sit in a `\\wsl.localhost\…` cwd — the shell starts in
  `/mnt/c/Windows` unless you set the directory explicitly.

## Why candidate 3 (PowerShell) wins

No title gotcha, no UNC warning. Launches a visible window, marker written with the
correct working directory, live `sleep 120` confirmed in `ps`.

## Setting the working directory

Use `wsl.exe --cd <path>` — it is launcher-independent and sidesteps the `cmd` UNC
problem entirely. It accepts a Linux path (`--cd ~/project`) or a Windows
path, and `--cd ~` works for home. This is more reliable than `start /D` or
PowerShell `-WorkingDirectory` (which want Windows paths). Verified: candidate 3
reported `pwd=<project-dir>` correctly.

## Launching pi

Swap the payload for `pi`. Use an **interactive login shell** (`-lic`) so your PATH /
nvm / shell init load and `pi` gets a proper TTY:

```bash
# Recommended
powershell.exe -NoProfile -Command "Start-Process wsl.exe -ArgumentList '-d Debian --cd <project-dir> -- bash -lic pi'"
```

- If `pi` isn't on PATH via your rc files, call it by full path
  (e.g. `bash -lic '~/.bun/bin/pi'`).
- To keep the window open after `pi` exits (for inspecting output), append
  `exec bash`: `… -- bash -lic 'pi; exec bash'`.

## Bottom line

Use `powershell.exe -c Start-Process wsl.exe …` (candidate 3); fall back to
`cmd /c start "" wsl.exe …` to avoid PowerShell. Avoid `wt.exe` for command-passing
from WSL. Always set the directory with `wsl --cd`.

---

*Validated on WSL2 Debian (trixie), launching into a Windows terminal host.*
