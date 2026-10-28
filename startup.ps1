# Disables (or restores) the Windows startup entries of the apps listed in apps.txt.
# Uses the same StartupApproved flag as Task Manager's Startup tab, so the entries
# themselves are never deleted.
#   startup.ps1 -Disable   disable matching entries and remember them
#   startup.ps1 -Restore   re-enable everything that -Disable turned off

param(
    [switch]$Disable,
    [switch]$Restore
)

$base      = $PSScriptRoot
$appsFile  = Join-Path $base 'apps.txt'
$stateDir  = Join-Path $base 'state'
$stateFile = Join-Path $stateDir 'startup_disabled.txt'
$logFile   = Join-Path $base 'optimizer.log'

$approvedRoot = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$locations = @{
    HKCU   = @{ Run = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKCU:\$approvedRoot\Run" }
    HKLM   = @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKLM:\$approvedRoot\Run" }
    HKLM32 = @{ Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$approvedRoot\Run32" }
}

# First byte of the StartupApproved value: 02 = enabled, 03 = disabled (odd = disabled)
$ENABLED  = [byte]2
$DISABLED = [byte]3

function Write-Log([string]$msg) {
    Write-Host "[*] $msg"
    Add-Content -Path $logFile -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

function Set-StartupFlag([string]$loc, [string]$name, [byte]$flag) {
    $path = $locations[$loc].Approved
    if (-not (Test-Path $path)) { $null = New-Item -Path $path -Force }
    $bytes = [byte[]](@($flag) + (,0 * 11))
    Set-ItemProperty -Path $path -Name $name -Value $bytes -Type Binary
}

if ($Disable) {
    if (-not (Test-Path $appsFile)) { Write-Log 'apps.txt not found, no startup entries changed'; return }
    $apps = Get-Content $appsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }

    if (-not (Test-Path $stateDir)) { $null = New-Item -ItemType Directory -Path $stateDir }
    $recorded = @()
    if (Test-Path $stateFile) { $recorded = @(Get-Content $stateFile) }

    $count = 0
    foreach ($loc in $locations.Keys) {
        $runPath = $locations[$loc].Run
        if (-not (Test-Path $runPath)) { continue }
        $runKey = Get-Item $runPath
        foreach ($name in $runKey.GetValueNames()) {
            $cmd = ([string]$runKey.GetValue($name)).ToLower()
            $app = $apps | Where-Object { $cmd.Contains($_.ToLower()) } | Select-Object -First 1
            if (-not $app) { continue }

            # Leave entries the user had already disabled alone, so -Restore won't turn them on
            $current = (Get-ItemProperty -Path $locations[$loc].Approved -Name $name -ErrorAction SilentlyContinue).$name
            if ($current -and ($current[0] -band 1)) { continue }

            Set-StartupFlag $loc $name $DISABLED
            $entry = "$loc|$name"
            if ($recorded -notcontains $entry) {
                Add-Content -Path $stateFile -Value $entry
                $recorded += $entry
            }
            Write-Log "Disabled startup entry '$name' ($app)"
            $count++
        }
    }
    if ($count -eq 0) { Write-Log 'No enabled startup entries matched apps.txt' }
}
elseif ($Restore) {
    if (-not (Test-Path $stateFile)) { Write-Log 'No startup entries to restore'; return }
    foreach ($line in Get-Content $stateFile) {
        $loc, $name = $line -split '\|', 2
        if (-not $name -or -not $locations.ContainsKey($loc)) { continue }
        Set-StartupFlag $loc $name $ENABLED
        Write-Log "Re-enabled startup entry '$name'"
    }
    Remove-Item $stateFile
}
else {
    Write-Host 'Usage: startup.ps1 -Disable | -Restore'
    exit 1
}
