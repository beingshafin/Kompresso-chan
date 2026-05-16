# Ensure the script is running with Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Cyan
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Uninstall Script for Kompresso-chan
$uninstallationResults = @{
    ContextMenu = "Skipped"
    Shortcut = "Skipped"
    PATH = "Skipped"
    KompressoChan = "Skipped"
    HandBrakeCLI = "Skipped"
}

# Define Paths
$handbrakeDestDir = "C:\Program Files\HandBrake"
$handbrakeCliPath = Join-Path $handbrakeDestDir "HandBrakeCLI.exe"

$kompressoChanDestDir = "C:\Program Files\Kompresso-chan"
$regRemovePath = Join-Path $PSScriptRoot "dependencies\Remove-KompressoChan-Menu.reg"

Write-Host "--- Starting Uninstallation ---`n" -ForegroundColor Cyan

# 1. Remove Context Menu
Write-Host "[Step 1/5] Removing Windows Context Menu..." -ForegroundColor White
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
Write-Host "[Step 2/5] Removing Desktop shortcut..." -ForegroundColor White
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
Write-Host "[Step 3/5] Removing from System PATH..." -ForegroundColor White
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
Write-Host "[Step 4/5] Removing Kompresso-chan files..." -ForegroundColor White
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
Write-Host "[Step 5/5] Removing HandBrakeCLI..." -ForegroundColor White
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

# Summary
Write-Host "`n--- Uninstallation Summary ---" -ForegroundColor Cyan
Write-Host "Context Menu:   $($uninstallationResults.ContextMenu)"
Write-Host "Desktop Shortcut: $($uninstallationResults.Shortcut)"
Write-Host "System PATH:    $($uninstallationResults.PATH)"
Write-Host "Kompresso-chan: $($uninstallationResults.KompressoChan)"
Write-Host "HandBrakeCLI:   $($uninstallationResults.HandBrakeCLI)"

Write-Host "`nUninstallation Complete!" -ForegroundColor Yellow

for ($i = 15; $i -gt 0; $i--) {
    Write-Host -NoNewline "`rClosing this window in $($i)s... " -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}
exit
