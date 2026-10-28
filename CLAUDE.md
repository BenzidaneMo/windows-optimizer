# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Windows optimizer with a WPF window for everyday users and a Batch menu for power users. Both run the same steps, implemented once in Batch with small PowerShell and VBScript helpers. It can clean temp files, close apps and stop them starting with Windows, pause Windows Update, switch power plans, and clear standby RAM with Sysinternals RAMMap. There is no build system, package manager, linter, or test suite. `RAMMap64.exe` is a third-party Sysinternals binary (license in `RAMMap-Eula.txt`); don't modify it.

## How the pieces connect

- `setup.ps1` unblocks the downloaded files and starts `run_invisible.vbs`. It uses relative paths, so it must be run from the repo folder.
- `run_invisible.vbs` relaunches itself elevated (marked with the `/elevated` arg) and starts `optimizer-gui.ps1` with PowerShell's console hidden.
- `optimizer-gui.ps1` is the WPF window, with its XAML inline. It contains no optimization logic. Each ticked option runs `cmd /c optimizer.bat <step>` with output redirected, one step at a time from a queue, and shows the output. A `DispatcherTimer` polls `ReadLineAsync()` so the UI thread never blocks. The script relaunches itself elevated if needed, and must stay ASCII-only, because PowerShell 5.1 reads BOM-less files as ANSI.
- `optimizer.bat` with no arguments shows the text menu. With `quick|ram|pause|startup|power|revert` it runs that one step, with no prompts, and exits; this is what the window uses. Each step is a `call :label` subroutine, and every action is logged through `:log` to `optimizer.log`. Lines that start with `[*] ` are shown as bullet points in the window. Steps must never prompt in CLI mode, because the window has no stdin to answer them.
- To add a step, write the subroutine in `optimizer.bat`, then add it to the menu, to `:cli`, and to the `$steps` list plus a checkbox in `optimizer-gui.ps1`.
- `apps.txt` is the single list of apps. Option 1 closes them (`for /f eol=#`), and `startup.ps1 -Disable` matches it against the `Run` registry keys.
- `state\` holds whatever undo needs: `power_scheme.txt` (the plan in use before the first switch), `ultimate_scheme.txt` (the Ultimate Performance copy that was created), and `startup_disabled.txt` (`LOCATION|valueName` lines). The files are created when first needed.
- `revert.bat` reads `state\` to undo things. It also still undoes the permanent Windows Update disabling done by the old `clear_ram_loop.bat`, which earlier versions shipped.

**Invariant:** every change `optimizer.bat` or `startup.ps1` makes needs a matching undo in `revert.bat`, or in `startup.ps1 -Restore`.

## Gotchas

- The `.bat` files must keep CRLF line endings. With LF only, `goto` and `call :label` can fail.
- PowerShell one-liners inside `for /f ('...')` avoid pipes, which would need `^|` escaping there. Keep it that way, or move longer logic into a `.ps1` file like `startup.ps1`.
- Batch has no delayed expansion here, so a variable set inside a `( )` block can't be read in that same block. The subroutines use `goto` labels instead (see `:power_plan`).
- `startup.ps1` disables entries by writing the `StartupApproved` flag (`02`=on, `03`=off; an odd first byte means disabled). It never deletes `Run` values, and it skips entries the user had already disabled.
- RAMMap flags: `-Et` clears the standby list and `-Ew` empties working sets. `-Es` is the *system* working set, not standby.
- Everything needs Administrator rights. Both `.bat` files check with `net session` and stop if they don't have them.

## Testing changes

There are no automated tests. The scripts change system settings, so ask the user before running any menu option, `revert.bat`, or `startup.ps1 -Disable`/`-Restore`. Safe read-only checks are below; `optimizer.bat` without admin rights just prints a message and exits.

```bash
powershell -NoProfile -File startup.ps1
```

That should print usage and exit with code 1, without changing anything.
