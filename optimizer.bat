@echo off
setlocal EnableExtensions
title Windows Optimizer
color 0A

set "BASE=%~dp0"
set "LOG=%BASE%optimizer.log"
set "STATE=%BASE%state"
set "APPS=%BASE%apps.txt"

:: === Needs Administrator rights (temp folders, HKLM registry, power plans) ===
net session >nul 2>&1
if errorlevel 1 (
    echo [!] Please run this script as Administrator.
    echo     Right-click optimizer.bat and choose "Run as administrator", or use run_invisible.vbs.
    if "%~1"=="" pause
    exit /b 1
)

:: === Command-line mode, used by optimizer-gui.ps1 ===
if not "%~1"=="" goto cli

call :log "Optimizer started"

:menu
echo.
echo ==================================================
echo   Windows Optimizer   (log: optimizer.log)
echo ==================================================
echo   1. Quick clean - temp files, close apps in apps.txt
echo   2. Free RAM now - RAMMap standby clear
echo   3. Pause Windows Update for 5 weeks
echo   4. Stop apps in apps.txt from starting with Windows
echo   5. Switch to a high-performance power plan
echo   6. Do 1, 3, 4 and 5
echo   7. Undo everything (revert.bat)
echo   0. Exit
echo.
set "choice="
set /p "choice=Choose an option [0-7]: "
if "%choice%"=="1" call :quick_clean
if "%choice%"=="2" call :free_ram
if "%choice%"=="3" call :pause_updates
if "%choice%"=="4" call :startup_disable
if "%choice%"=="5" call :power_plan
if "%choice%"=="6" call :do_all
if "%choice%"=="7" call "%BASE%revert.bat" /nopause
if "%choice%"=="0" goto end
goto menu

:end
call :log "Optimizer closed"
endlocal
exit /b 0

:: optimizer.bat quick^|ram^|pause^|startup^|power^|revert runs one step without the menu or any prompts
:cli
set "ACTION="
if /i "%~1"=="quick"   set "ACTION=:quick_clean"
if /i "%~1"=="ram"     set "ACTION=:free_ram"
if /i "%~1"=="pause"   set "ACTION=:pause_updates"
if /i "%~1"=="startup" set "ACTION=:startup_disable"
if /i "%~1"=="power"   set "ACTION=:power_plan"
if /i "%~1"=="revert" (
    call "%BASE%revert.bat" /nopause
    exit /b 0
)
if not defined ACTION (
    echo Usage: optimizer.bat [quick^|ram^|pause^|startup^|power^|revert]
    exit /b 2
)
call %ACTION%
exit /b 0


:: ================= Subroutines =================

:log
echo [*] %~1
>>"%LOG%" echo [%date% %time%] %~1
exit /b

:ram_usage
for /f "delims=" %%R in ('powershell -NoProfile -Command "$o = Get-CimInstance Win32_OperatingSystem; 'Used: {0:N2} GB / Total: {1:N2} GB' -f (($o.TotalVisibleMemorySize - $o.FreePhysicalMemory)/1MB), ($o.TotalVisibleMemorySize/1MB)"') do call :log "RAM %~1 - %%R"
exit /b

:: === 1. Temp files + close apps ===
:quick_clean
call :ram_usage before
call :log "Cleaning temp folders"
del /q /f /s "%TEMP%\*" >nul 2>&1
for /d %%D in ("%TEMP%\*") do rd /s /q "%%D" >nul 2>&1
del /q /f /s "%SystemRoot%\Temp\*" >nul 2>&1
for /d %%D in ("%SystemRoot%\Temp\*") do rd /s /q "%%D" >nul 2>&1

if not exist "%APPS%" (
    call :log "apps.txt not found, no apps closed"
    goto qc_done
)
call :log "Closing apps listed in apps.txt"
for /f "usebackq eol=# tokens=*" %%A in ("%APPS%") do (
    taskkill /f /im "%%A" >nul 2>&1 && call :log "Closed %%A"
)
:qc_done
call :ram_usage after
exit /b

:: === 2. One-time RAM clear ===
:free_ram
call :ram_usage before
if exist "%BASE%RAMMap64.exe" (
    reg add "HKCU\Software\Sysinternals\RamMap" /v EulaAccepted /t REG_DWORD /d 1 /f >nul
    call :log "Clearing standby list and working sets with RAMMap64"
    start "" /wait "%BASE%RAMMap64.exe" -Et
    start "" /wait "%BASE%RAMMap64.exe" -Ew
) else (
    call :log "RAMMap64.exe not found, trimming working sets with PowerShell instead"
    powershell -NoProfile -Command "Get-Process | Where-Object { $_.Id -ne $PID } | ForEach-Object { try { $_.MinWorkingSet = $_.MinWorkingSet } catch {} }"
)
call :ram_usage after
exit /b

:: === 3. Pause Windows Update (same as Settings > Pause updates, ends by itself) ===
:pause_updates
set "PAUSED_UNTIL="
for /f "delims=" %%D in ('powershell -NoProfile -Command "$k = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; if (-not (Test-Path $k)) { $null = New-Item -Path $k -Force }; $s = (Get-Date).ToUniversalTime(); $e = $s.AddDays(35); foreach ($n in 'PauseUpdatesStartTime','PauseQualityUpdatesStartTime','PauseFeatureUpdatesStartTime') { Set-ItemProperty -Path $k -Name $n -Value ($s.ToString('s') + 'Z') }; foreach ($n in 'PauseUpdatesExpiryTime','PauseQualityUpdatesEndTime','PauseFeatureUpdatesEndTime') { Set-ItemProperty -Path $k -Name $n -Value ($e.ToString('s') + 'Z') }; $e.ToLocalTime().ToString('yyyy-MM-dd')"') do set "PAUSED_UNTIL=%%D"
if defined PAUSED_UNTIL (
    call :log "Windows Update paused until %PAUSED_UNTIL%"
) else (
    call :log "Could not pause Windows Update"
)
exit /b

:: === 4. Startup entries ===
:startup_disable
powershell -NoProfile -ExecutionPolicy Bypass -File "%BASE%startup.ps1" -Disable
exit /b

:: === 5. Power plan ===
:power_plan
if not exist "%STATE%" mkdir "%STATE%"

:: Remember the plan in use before the first switch, so revert.bat can go back to it
if exist "%STATE%\power_scheme.txt" goto pp_saved
for /f "delims=" %%G in ('powershell -NoProfile -Command "$t = (powercfg /getactivescheme) -join ' '; if ($t -match '[0-9a-fA-F-]{36}') { $matches[0] }"') do >"%STATE%\power_scheme.txt" echo %%G
if exist "%STATE%\power_scheme.txt" call :log "Saved the current power plan so it can be restored"
:pp_saved

:: Reuse the Ultimate Performance copy made on an earlier run, if it still exists
set "NEWPLAN="
if exist "%STATE%\ultimate_scheme.txt" set /p NEWPLAN=<"%STATE%\ultimate_scheme.txt"
if defined NEWPLAN powercfg /query %NEWPLAN% >nul 2>&1 || set "NEWPLAN="
if defined NEWPLAN goto pp_activate

for /f "delims=" %%G in ('powershell -NoProfile -Command "$t = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) -join ' '; if (($t -match '[0-9a-fA-F-]{36}') -and ($matches[0] -ne 'e9a42b02-d5df-448d-aa00-03f14749eb61')) { $matches[0] }"') do set "NEWPLAN=%%G"
if defined NEWPLAN >"%STATE%\ultimate_scheme.txt" echo %NEWPLAN%

:pp_activate
if not defined NEWPLAN goto pp_high
powercfg /setactive %NEWPLAN% >nul 2>&1
if errorlevel 1 goto pp_high
call :log "Switched to the Ultimate Performance power plan"
exit /b

:pp_high
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
if errorlevel 1 (
    call :log "Could not switch power plan - this PC may only offer Balanced"
) else (
    call :log "Switched to the High Performance power plan"
)
exit /b

:: === 6. Everything except the RAM clear, which is offered at the end ===
:do_all
call :quick_clean
call :pause_updates
call :startup_disable
call :power_plan
set "ans="
set /p "ans=Also free RAM now with RAMMap? (Y/N): "
if /i "%ans%"=="Y" call :free_ram
exit /b
