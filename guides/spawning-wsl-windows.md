# Spawning a pi window from inside WSL2

LLM reference. Launch a visible Windows terminal window running a command (`pi`, a
spoke shell) from inside a WSL2 distro. Tested on WSL2 Debian.

## Use

PowerShell `Start-Process wsl.exe`. Set cwd with `wsl --cd`. Never `wt.exe`.

```bash
# recommended
powershell.exe -NoProfile -Command "Start-Process wsl.exe -ArgumentList '-d Debian --cd ~ -- bash -lic \"echo HELLO; sleep 30\"'"

# fallback (avoids PowerShell) — the empty "" title is MANDATORY
cmd.exe /c start "" wsl.exe -d Debian --cd ~ -- bash -lic 'echo HELLO; sleep 30'
```

Launch pi — use `bash -lic` (login+interactive: loads PATH/nvm, gives a real TTY):

```bash
powershell.exe -NoProfile -Command "Start-Process wsl.exe -ArgumentList '-d Debian --cd <project-dir> -- bash -lic pi'"
```

- `pi` not on PATH → call by full path: `bash -lic '~/.bun/bin/pi'`.
- Keep window open after exit (to read output): `bash -lic 'pi; exec bash'`.

## Working directory

Use `wsl.exe --cd <path>` — launcher-independent, accepts a Linux OR Windows path,
`--cd ~` works. More reliable than `start /D` or PowerShell `-WorkingDirectory`
(both want Windows paths). Without it, `cmd` can't sit in a `\\wsl.localhost\…` cwd
and defaults to `/mnt/c/Windows` (the UNC warning).

## Gotchas (verdicts: all three exit 0; only the spawn matters)

- **`wt.exe` — broken for command-passing from WSL.** Exits 0 but nothing useful
  runs. It treats `;` as a tab/pane delimiter (splits `echo HELLO; sleep 30` into
  junk tabs) and the launching WSL shell strips the inner quotes before `wt` sees
  them, so it re-tokenizes the script on whitespace and throws `0x80070002`. Even a
  `;`-free `&&` variant fails. Do not use.
- **`cmd /c start` — works, finicky.** First quoted token is consumed as the program
  name, so the empty `""` title placeholder is required (`start "pi-window" wsl…`
  fails with "cannot find 'pi-window'"). Emits a UNC warning unless cwd is set.
- **PowerShell `Start-Process` — best.** No title gotcha, no UNC warning, correct
  cwd, visible window.
