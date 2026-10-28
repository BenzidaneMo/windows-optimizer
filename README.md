# Windows Optimizer

A simple tool that makes a Windows PC feel faster. It cleans up junk files, closes and stops background apps, switches to a high-performance power plan, can pause Windows Update, and can free up memory before you start a game.

It comes with a friendly window for everyday users and a text menu for power users. **Every change can be undone.**

> **Use at your own risk.** This tool changes system settings. Use it only on a PC you own or have permission to modify, and not on school, office, or government devices.

---

## Getting started

1. [Download the ZIP](https://github.com/BenzidaneMo/windows-optimizer/archive/refs/heads/main.zip) of this repository.
2. Extract it to a folder, for example `Windows-Optimizer`.
3. Right-click `setup.ps1` and choose **Run with PowerShell**.
4. If PowerShell asks about changing the execution policy, choose **Yes to All (A)**.
5. When Windows asks for Administrator permission, click **Yes**. The optimizer window opens.

Setup also puts a **Windows Optimizer** shortcut, with the lightning-bolt icon, on your Desktop. After the first time, double-click that shortcut (or `run_invisible.vbs`) to open the window.

If PowerShell scripts are blocked on your PC, run this once in PowerShell, then try again:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## Using the window

Tick what you want and press **Optimize my PC**. The window shows how much memory is in use, and shows progress while it works.

| Option | What it does | Ticked by default |
|---|---|---|
| Clean up junk and close background apps | Deletes temporary files and closes apps like OneDrive and Teams | Yes |
| Make Windows start faster | Stops those apps from opening every time Windows starts | Yes |
| Turn on maximum performance | Switches to the fastest power plan. On a laptop, the battery may drain faster | Yes |
| Pause Windows updates for 5 weeks | No surprise updates or restarts. Updates come back on by themselves | No |
| Free up memory now | Clears cached memory once. Best just before starting a game | No |

The other buttons:

- **Undo all changes** puts everything back the way it was.
- **Choose which apps to close** opens the app list (`apps.txt`) in Notepad.
- **See the full log** opens `optimizer.log`, a record of everything the tool has done.

---

## Choosing which apps to close

The app list is `apps.txt`: one program name per line. Lines starting with `#` are ignored. By default it contains:

- OneDrive.exe
- Teams.exe
- AdobeIPCBroker.exe, AdobeCollabSync.exe
- ArmouryCrate.UserSessionHelper.exe, GameSDK.exe, AuraService.exe, NahimicService.exe (ASUS)

Suggestions for HP, Dell, Lenovo, Xbox Game Bar and Phone Link are already in the file as comments. Remove the `#` in front of a line to use it.

"Make Windows start faster" only covers apps that start through the usual Windows startup list. It leaves alone apps that run as Windows services (such as ASUS components that control fans and lighting) and Microsoft Store apps such as the new Teams. You can turn those off in **Settings > Apps > Startup**.

---

## Undoing changes

Press **Undo all changes** in the window, or run `revert.bat` as Administrator. It:

- Removes the Windows Update pause.
- Turns Windows Update back on if an older version of this tool switched it off permanently.
- Lets the apps you stopped start with Windows again.
- Switches back to your original power plan and removes the extra plan the tool created.

Deleted temporary files can't be brought back. Closed apps simply need to be opened again. The Desktop shortcut isn't touched by Undo; delete it yourself if you remove the tool.

---

## For power users

### Text menu

Right-click `optimizer.bat` and choose **Run as administrator** to use the text menu:

| # | Option |
|---|---|
| 1 | Quick clean: temp files, close the apps in `apps.txt` |
| 2 | Free RAM now, using RAMMap |
| 3 | Pause Windows Update for 5 weeks |
| 4 | Stop the apps in `apps.txt` from starting with Windows |
| 5 | Switch to a high-performance power plan |
| 6 | Do 1, 3, 4 and 5 |
| 7 | Undo everything |
| 0 | Exit |

### Running one step

`optimizer.bat` can also run a single step without the menu or any prompts, from an Administrator command prompt. The window uses this too.

```bat
optimizer.bat quick
optimizer.bat ram
optimizer.bat pause
optimizer.bat startup
optimizer.bat power
optimizer.bat revert
```

### How it works

- **Temp files:** empties `%TEMP%` and `C:\Windows\Temp` once.
- **Free RAM:** runs [RAMMap64](https://learn.microsoft.com/en-us/sysinternals/downloads/rammap) from this folder to clear the standby list and working sets. If `RAMMap64.exe` is missing, it trims memory with PowerShell instead. Windows uses standby memory as a cache and hands it to programs when they need it, so this is worth doing occasionally, not constantly.
- **Pause updates:** sets the same pause as **Settings > Windows Update > Pause updates**, so it ends on its own after 5 weeks.
- **Startup apps:** sets the same "disabled" flag as Task Manager's Startup tab. Nothing is deleted.
- **Power plan:** creates and switches to the Ultimate Performance plan, or uses High Performance if that isn't available. The original plan is remembered so Undo can restore it.

### Files

```
.
├── run_invisible.vbs    Opens the window as Administrator
├── setup.ps1            First-time setup: unblocks the files, adds a Desktop shortcut, opens the window
├── optimizer-gui.ps1    The optimizer window
├── optimizer.ico        The app icon, used by the window and the Desktop shortcut
├── optimizer.bat        Text menu; also does the work for the window
├── apps.txt             The list of apps to close and stop at startup
├── startup.ps1          Turns startup entries off and back on
├── revert.bat           Undoes every change
├── RAMMap64.exe         Microsoft Sysinternals RAMMap
├── RAMMap-Eula.txt      RAMMap's license terms
├── state/               Created automatically: what Undo needs to restore
└── optimizer.log        Created automatically: record of every action
```

### Windows Defender warnings

Windows Defender sometimes flags `.bat` and `.vbs` files just because of their type. If that happens, scan the folder with Defender first, and read the scripts if you want to see exactly what they do. They are plain text.

---

## License

[MIT License](LICENSE)

Contributions, suggestions and issues are welcome.
