# Attempt to set execution policy silently (may still prompt for permission)
Try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
} Catch {
    Write-Host "⚠️ Could not change execution policy automatically. You may need to run:"
    Write-Host "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
    Start-Sleep -Seconds 3
}

# Unblock all files in the current directory
Get-ChildItem -Recurse | Unblock-File

# Desktop shortcut to the invisible launcher, using the app icon
Try {
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Windows Optimizer.lnk'))
    $shortcut.TargetPath = Join-Path $PSScriptRoot 'run_invisible.vbs'
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = Join-Path $PSScriptRoot 'optimizer.ico'
    $shortcut.Save()
} Catch {
    Write-Host "Could not create the desktop shortcut: $($_.Exception.Message)"
}

# Run the invisible VBS launcher
Start-Process "run_invisible.vbs"
