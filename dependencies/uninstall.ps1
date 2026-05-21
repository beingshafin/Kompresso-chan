# Ensure the script is running with Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Cyan
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction Stop
    } catch {
        Write-Host "Failed to request Administrator privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please run this script as Administrator manually."
        Read-Host "Press Enter to exit..."
    }
    exit
}

# Uninstall Script for Kompresso-chan
$uninstallationResults = @{
    ContextMenu = "Skipped"
    Shortcut = "Skipped"
    PATH = "Skipped"
    KompressoChan = "Skipped"
    HandBrakeCLI = "Skipped"
    AppData = "Skipped"
}

# Define Paths
$handbrakeDestDir = "C:\Program Files\HandBrake"
$handbrakeCliPath = Join-Path $handbrakeDestDir "HandBrakeCLI.exe"

$kompressoChanDestDir = "C:\Program Files\Kompresso-chan"
$regRemovePath = Join-Path $PSScriptRoot "Remove-KompressoChan-Menu.reg"

Write-Host "--- Starting Uninstallation ---`n" -ForegroundColor Cyan

# 0. Stop Running Processes
Write-Host "[Step 0/7] Stopping running processes..." -ForegroundColor White
$processesToStop = @("komchan", "HandBrakeCLI", "Kompresso-chan")
$processesStopped = 0
foreach ($procName in $processesToStop) {
    # Find processes, excluding the current uninstaller process itself
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
    if ($procs) {
        Write-Host "Found running process: $procName. Stopping..." -ForegroundColor Yellow
        try {
            $procs | Stop-Process -Force -ErrorAction Stop
            Write-Host "Successfully stopped $procName." -ForegroundColor Gray
            $processesStopped++
        } catch {
            Write-Host "Failed to stop ${procName}: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
if ($processesStopped -gt 0) {
    Write-Host "All identified processes stopped. Waiting for system to release files..." -ForegroundColor Gray
    Start-Sleep -Seconds 1
}
Write-Host "Done checking processes.`n" -ForegroundColor Gray

# 1. Remove Context Menu
Write-Host "[Step 1/7] Removing Windows Context Menu..." -ForegroundColor White
if (Test-Path $regRemovePath) {
    try {
        $process = Start-Process regedit.exe -ArgumentList "/s `"$regRemovePath`"" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Context menu entries removed." -ForegroundColor Gray
            $uninstallationResults.ContextMenu = "Success"

            # Restart Explorer to apply context menu changes
            Write-Host "Restarting Windows Explorer to apply changes..." -ForegroundColor Gray
            Stop-Process -Name explorer -Force
            Start-Process explorer.exe
        } else {
            $uninstallationResults.ContextMenu = "Error: regedit exited with code $($process.ExitCode)"
        }
    } catch {
        $uninstallationResults.ContextMenu = "Error: $($_.Exception.Message)"
    }
} else {
    $uninstallationResults.ContextMenu = "Error: Registry removal file missing"
}

# 2. Remove Desktop Shortcut
Write-Host "[Step 2/7] Removing Desktop shortcut..." -ForegroundColor White
try {
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
    if (-not $DesktopPath) { $DesktopPath = Join-Path $env:USERPROFILE "Desktop" }
    $ShortcutPath = Join-Path $DesktopPath "Kompresso-chan.lnk"

    if (Test-Path $ShortcutPath) {
        Remove-Item -Path $ShortcutPath -Force
        Write-Host "Shortcut removed." -ForegroundColor Gray
        $uninstallationResults.Shortcut = "Success"
    } else {
        Write-Host "Shortcut not found." -ForegroundColor Gray
        $uninstallationResults.Shortcut = "Not Found"
    }
} catch {
    $uninstallationResults.Shortcut = "Error: $($_.Exception.Message)"
}

# 3. Remove from System PATH
Write-Host "[Step 3/7] Removing from System PATH..." -ForegroundColor White
try {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -like "*$kompressoChanDestDir*") {
        # Filter out the directory from PATH
        $pathParts = $currentPath -split ";" | Where-Object { $_ -ne $kompressoChanDestDir -and $_ -ne "$kompressoChanDestDir\" -and -not [string]::IsNullOrWhiteSpace($_) }
        $newPath = $pathParts -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "Removed from System PATH." -ForegroundColor Gray
        $uninstallationResults.PATH = "Success"
    } else {
        Write-Host "Not found in System PATH." -ForegroundColor Gray
        $uninstallationResults.PATH = "Not Found"
    }
} catch {
    $uninstallationResults.PATH = "Error: $($_.Exception.Message)"
}

# 4. Remove Kompresso-chan Files
Write-Host "[Step 4/7] Removing Kompresso-chan files..." -ForegroundColor White
try {
    if (Test-Path $kompressoChanDestDir) {
        Remove-Item -Path $kompressoChanDestDir -Recurse -Force
        Write-Host "Kompresso-chan directory deleted." -ForegroundColor Gray
        $uninstallationResults.KompressoChan = "Success"
    } else {
        Write-Host "Kompresso-chan directory not found." -ForegroundColor Gray
        $uninstallationResults.KompressoChan = "Not Found"
    }
} catch {
    $uninstallationResults.KompressoChan = "Error: $($_.Exception.Message)"
}

# 5. Remove HandBrakeCLI (Keep GUI)
Write-Host "[Step 5/7] Removing HandBrakeCLI..." -ForegroundColor White
try {
    if (Test-Path $handbrakeCliPath) {
        Remove-Item -Path $handbrakeCliPath -Force
        Write-Host "HandBrakeCLI.exe removed." -ForegroundColor Gray
        $uninstallationResults.HandBrakeCLI = "Success"
    } else {
        Write-Host "HandBrakeCLI.exe not found." -ForegroundColor Gray
        $uninstallationResults.HandBrakeCLI = "Not Found"
    }
} catch {
    $uninstallationResults.HandBrakeCLI = "Error: $($_.Exception.Message)"
}

# 6. Check & Optionally Remove AppData Config
Write-Host "[Step 6/7] Checking configuration..." -ForegroundColor White
try {
    $configDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Kompresso-chan'
    $configPath = Join-Path $configDir 'config.json'

    $isModified = $false
    if (Test-Path $configPath) {
        try {
            $content = Get-Content $configPath -Raw -ErrorAction Stop
            $parsed = $content | ConvertFrom-Json -ErrorAction Stop
            if ([string]$parsed.resolution -ne "original") { $isModified = $true }
            if ([string]$parsed.fps -ne "original") { $isModified = $true }
            if ([string]$parsed.quality -ne "veryfast") { $isModified = $true }
            if ([string]$parsed.mode -ne "mirror") { $isModified = $true }
            if ([bool]$parsed.smart -ne $false) { $isModified = $true }
            if ([bool]$parsed.shutdown -ne $false) { $isModified = $true }
            if ([string]$parsed.log -ne "both") { $isModified = $true }
        } catch {
            $isModified = $true
        }
    }

    if ($isModified) {
        Write-Host "Custom settings detected in configuration file." -ForegroundColor Yellow
        Write-Host -NoNewline "  "
        $deleteConfig = Read-Host "Delete configuration? [y/N]"
        if ($deleteConfig.ToLower() -eq "y") {
            if (Test-Path $configDir) {
                Remove-Item -Path $configDir -Recurse -Force
                Write-Host "Configuration deleted." -ForegroundColor Gray
                $uninstallationResults.AppData = "Deleted"
            } else {
                $uninstallationResults.AppData = "Not Found"
            }
        } else {
            Write-Host "Configuration preserved." -ForegroundColor Gray
            $uninstallationResults.AppData = "Preserved"
        }
    } else {
        Write-Host "Configuration is using default settings. Nothing to clean up." -ForegroundColor Gray
        $uninstallationResults.AppData = "Default (Skipped)"
    }
} catch {
    $uninstallationResults.AppData = "Error: $($_.Exception.Message)"
}

# Summary
Write-Host "`n--- Uninstallation Summary ---" -ForegroundColor Cyan
Write-Host "Context Menu:   $($uninstallationResults.ContextMenu)"
Write-Host "Desktop Shortcut: $($uninstallationResults.Shortcut)"
Write-Host "System PATH:    $($uninstallationResults.PATH)"
Write-Host "Kompresso-chan: $($uninstallationResults.KompressoChan)"
Write-Host "HandBrakeCLI:   $($uninstallationResults.HandBrakeCLI)"
Write-Host "AppData/Config: $($uninstallationResults.AppData)"

Write-Host "`nUninstallation Complete!" -ForegroundColor Yellow

for ($i = 15; $i -gt 0; $i--) {
    Write-Host -NoNewline "`rClosing this window in $($i)s... " -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}
exit
