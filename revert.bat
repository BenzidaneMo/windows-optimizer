@echo off
setlocal EnableExtensions
title Revert Windows Optimizer Changes
color 0C

set "BASE=%~dp0"
set "LOG=%BASE%optimizer.log"
set "STATE=%BASE%state"

net session >nul 2>&1
if errorlevel 1 (
    echo [!] Please run this script as Administrator.
    goto done
)

:: === Windows Update pause (optimizer.bat option 3) ===
call :log "Removing the Windows Update pause"
for %%V in (PauseUpdatesStartTime PauseUpdatesExpiryTime PauseQualityUpdatesStartTime PauseQualityUpdatesEndTime PauseFeatureUpdatesStartTime PauseFeatureUpdatesEndTime) do (
    reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v %%V /f >nul 2>&1
)

:: === Windows Update disabled by older versions of this tool (clear_ram_loop.bat) ===
:: Services are only touched if they are still disabled.
sc qc wuauserv | findstr /c:"DISABLED" >nul && (
    call :log "Re-enabling the Windows Update service"
    sc config wuauserv start= demand >nul
    sc start wuauserv >nul 2>&1
)
sc qc UsoSvc | findstr /c:"DISABLED" >nul && (
    call :log "Re-enabling the Update Orchestrator service"
    sc config UsoSvc start= delayed-auto >nul
    sc start UsoSvc >nul 2>&1
)
sc qc bits | findstr /c:"DISABLED" >nul && (
    call :log "Re-enabling the BITS service"
    sc config bits start= demand >nul
    sc start bits >nul 2>&1
)
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /f >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WindowsUpdate\Scheduled Start" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WindowsUpdate\sih" /Enable >nul 2>&1
schtasks /Change /TN "Microsoft\Windows\WindowsUpdate\sihboot" /Enable >nul 2>&1

:: === Startup entries (option 4) ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%BASE%startup.ps1" -Restore

:: === Power plan (option 5) ===
if not exist "%STATE%\power_scheme.txt" goto power_done
set "ORIG="
set /p ORIG=<"%STATE%\power_scheme.txt"
powercfg /setactive %ORIG% >nul 2>&1 && (
    call :log "Restored the original power plan"
    del "%STATE%\power_scheme.txt"
)
:power_done
if not exist "%STATE%\ultimate_scheme.txt" goto ultimate_done
set "ULT="
set /p ULT=<"%STATE%\ultimate_scheme.txt"
:: Fails while the copy is still the active plan, so the file is kept for the next try
powercfg /delete %ULT% >nul 2>&1 && (
    call :log "Removed the Ultimate Performance plan copy"
    del "%STATE%\ultimate_scheme.txt"
)
:ultimate_done

call :log "Revert finished"

:done
if /i not "%~1"=="/nopause" pause
endlocal
exit /b

:log
echo [*] %~1
>>"%LOG%" echo [%date% %time%] %~1
exit /b
