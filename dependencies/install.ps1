# Ensure the script is running with Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Cyan
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Install Script for Kompresso-chan
$installationResults = @{
    HandBrake = "Success"
    KompressoChan = "Failed"
    Shortcut = "Failed"
    CLI = "Failed"
    ContextMenu = "Failed"
}

# Define Paths
$handbrakeDestDir = "C:\Program Files\HandBrake"
$handbrakeCliPath = Join-Path $handbrakeDestDir "HandBrakeCLI.exe"
$handbrakeSrcDir = Join-Path $PSScriptRoot "HandBrake"

$kompressoChanDestDir = "C:\Program Files\Kompresso-chan"
$kompressoChanExeName = "Kompresso-chan.exe"
$kompressoChanDestPath = Join-Path $kompressoChanDestDir $kompressoChanExeName
$kompressoChanSrcPath = Join-Path $PSScriptRoot "$kompressoChanExeName"
$uninstallSrcPath = Join-Path $PSScriptRoot "uninstall.ps1"
$uninstallDestPath = Join-Path $kompressoChanDestDir "uninstall.ps1"
$uninstallExeSrcPath = Join-Path $PSScriptRoot "..\uninstall.exe"
$uninstallExeDestPath = Join-Path $kompressoChanDestDir "uninstall.exe"
$wrapperSrcPath = Join-Path $PSScriptRoot "kompresso-context-wrapper.ps1"
$wrapperDestPath = Join-Path $kompressoChanDestDir "kompresso-context-wrapper.ps1"
$vbsLauncherSrcPath = Join-Path $PSScriptRoot "kompresso-launch.vbs"
$vbsLauncherDestPath = Join-Path $kompressoChanDestDir "kompresso-launch.vbs"
$vbsQuickLauncherSrcPath = Join-Path $PSScriptRoot "kompresso-quick-launch.vbs"
$vbsQuickLauncherDestPath = Join-Path $kompressoChanDestDir "kompresso-quick-launch.vbs"
$menuFolderSrcPath = Join-Path $PSScriptRoot "Assets\menu"
$menuFolderDestPath = Join-Path $kompressoChanDestDir "menu"
$contextMenuSrcPath = Join-Path $PSScriptRoot "Add-KompressoChan-Menu.reg"
$regRemoveSrcPath = Join-Path $PSScriptRoot "Remove-KompressoChan-Menu.reg"
$regRemoveDestPath = Join-Path $kompressoChanDestDir "Remove-KompressoChan-Menu.reg"

Write-Host "--- Starting Installation ---`n" -ForegroundColor Cyan

# 1. Install HandBrakeCLI
Write-Host "[Step 1/5] Installing HandBrakeCLI..." -ForegroundColor White
if (Test-Path $handbrakeSrcDir) {
    try {
        if (-not (Test-Path $handbrakeDestDir)) {
            New-Item -ItemType Directory -Path $handbrakeDestDir -Force | Out-Null
        }

        $srcItems = Get-ChildItem -Path $handbrakeSrcDir
        $replacedList = @()
        
        foreach ($item in $srcItems) {
            $destPath = Join-Path $handbrakeDestDir $item.Name
            if (Test-Path $destPath) {
                $replacedList += $item.Name
                # Delete only the specific conflicting file or folder
                Remove-Item -Path $destPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            # Copy the specific item (file or directory) to the destination
            Copy-Item -Path $item.FullName -Destination $handbrakeDestDir -Recurse -Force
        }
        
        if ($replacedList.Count -gt 0) {
            $fileList = $replacedList -join ", "
            $installationResults.HandBrake = "Success (Replaced: $fileList)"
            Write-Host "HandBrake dependencies replaced: $fileList" -ForegroundColor Gray
        } else {
            $installationResults.HandBrake = "Success"
            Write-Host "HandBrake dependencies installed." -ForegroundColor Gray
        }
    } catch {
        $installationResults.HandBrake = "Error: $($_.Exception.Message)"
    }
} else {
    $installationResults.HandBrake = "Error: Source dependencies folder missing"
}

# 2. Copy Kompresso-chan.exe
Write-Host "[Step 2/5] Installing Kompresso-chan..." -ForegroundColor White
if (Test-Path $kompressoChanSrcPath) {
    try {
        if (-not (Test-Path $kompressoChanDestDir)) {
            New-Item -ItemType Directory -Path $kompressoChanDestDir -Force | Out-Null
        }
        
        $alreadyExisted = Test-Path $kompressoChanDestPath
        Copy-Item -Path $kompressoChanSrcPath -Destination $kompressoChanDestPath -Force
        Write-Host "Executable copied successfully." -ForegroundColor Gray
        
        if ($alreadyExisted) {
            $installationResults.KompressoChan = "Success (Replaced)"
        } else {
            $installationResults.KompressoChan = "Success"
        }

        # Copy uninstall.ps1 if it exists
        if (Test-Path $uninstallSrcPath) {
            Copy-Item -Path $uninstallSrcPath -Destination $uninstallDestPath -Force
            Write-Host "Uninstaller script copied successfully." -ForegroundColor Gray
        }

        # Copy uninstall.exe if it exists
        if (Test-Path $uninstallExeSrcPath) {
            Copy-Item -Path $uninstallExeSrcPath -Destination $uninstallExeDestPath -Force
            Write-Host "Uninstaller executable copied successfully." -ForegroundColor Gray
        }

        # Copy the wrapper script used by the context menu to pass full paths safely.
        if (Test-Path $wrapperSrcPath) {
            Copy-Item -Path $wrapperSrcPath -Destination $wrapperDestPath -Force
            Write-Host "Context menu wrapper script copied successfully." -ForegroundColor Gray
        }

        # Copy the VBS launcher for silent context menu execution.
        if (Test-Path $vbsLauncherSrcPath) {
            Copy-Item -Path $vbsLauncherSrcPath -Destination $vbsLauncherDestPath -Force
            Write-Host "VBS launcher script copied successfully." -ForegroundColor Gray
        }

        # Copy the quick-launch VBS launcher for quick compression context menu.
        if (Test-Path $vbsQuickLauncherSrcPath) {
            Copy-Item -Path $vbsQuickLauncherSrcPath -Destination $vbsQuickLauncherDestPath -Force
            Write-Host "Quick compression VBS launcher copied successfully." -ForegroundColor Gray
        }

        # Copy the menu icons folder for context menu icons.
        if (Test-Path $menuFolderSrcPath) {
            if (-not (Test-Path $menuFolderDestPath)) {
                New-Item -ItemType Directory -Path $menuFolderDestPath -Force | Out-Null
            }
            Copy-Item -Path "$menuFolderSrcPath\*" -Destination $menuFolderDestPath -Recurse -Force
            Write-Host "Menu icons copied successfully." -ForegroundColor Gray
        }

        # Copy Remove-KompressoChan-Menu.reg if it exists
        if (Test-Path $regRemoveSrcPath) {
            Copy-Item -Path $regRemoveSrcPath -Destination $regRemoveDestPath -Force
            Write-Host "Context menu removal script copied successfully." -ForegroundColor Gray
        }
    } catch {
        $installationResults.KompressoChan = "Error: $($_.Exception.Message)"
    }
} else {
    $installationResults.KompressoChan = "Error: Source EXE missing"
}

# 3. Create Desktop Shortcut
Write-Host "[Step 3/5] Creating Desktop shortcut..." -ForegroundColor White
try {
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
    if (-not $DesktopPath) { $DesktopPath = Join-Path $env:USERPROFILE "Desktop" }
    $ShortcutPath = Join-Path $DesktopPath "Kompresso-chan.lnk"

    $alreadyExisted = $false
    if (Test-Path $ShortcutPath) {
        Write-Host "Shortcut already exists. Replacing..." -ForegroundColor Gray
        Remove-Item -Path $ShortcutPath -Force
        $alreadyExisted = $true
    }
    
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $kompressoChanDestPath
    $Shortcut.WorkingDirectory = $kompressoChanDestDir
    $Shortcut.Save()
    
    # Release COM object explicitly
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($WshShell) | Out-Null
    
    Write-Host "Shortcut created." -ForegroundColor Gray
    if ($alreadyExisted) {
        $installationResults.Shortcut = "Success (Replaced)"
    } else {
        $installationResults.Shortcut = "Success"
    }
} catch {
    $installationResults.Shortcut = "Error: $($_.Exception.Message)"
}

# 4. Add to PATH and create 'komchan' command
Write-Host "[Step 4/5] Setting up CLI command 'komchan'..." -ForegroundColor White
try {
    $shimPath = Join-Path $kompressoChanDestDir "komchan.exe"
    # Ensure any existing file/link is removed first to prevent link persistence (the "red arrow" issue)
    if (Test-Path $shimPath) {
        Remove-Item -Path $shimPath -Force -ErrorAction SilentlyContinue
    }
    
    # Use Copy-Item instead of HardLink to ensure it's a regular file
    Copy-Item -Path $kompressoChanDestPath -Destination $shimPath -Force
    Write-Host "Alias 'komchan' created (as a regular copy)." -ForegroundColor Gray

    Write-Host "Checking System PATH..." -ForegroundColor Gray
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$kompressoChanDestDir*") {
        Write-Host "Adding to System PATH (this may take a moment)..." -ForegroundColor Gray
        $newPath = "$currentPath;$kompressoChanDestDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "Added to System PATH." -ForegroundColor Gray
        $installationResults.CLI = "Success (Path updated - restart terminal)"
    } else {
        $installationResults.CLI = "Success (Already in PATH)"
    }
} catch {
    $installationResults.CLI = "Error: $($_.Exception.Message)"
}

# 5. Add to Context Menu
Write-Host "[Step 5/5] Adding to Windows Context Menu..." -ForegroundColor White
if (Test-Path $contextMenuSrcPath) {
    try {
        # Run regedit in silent mode to import the .reg file
        $process = Start-Process regedit.exe -ArgumentList "/s `"$contextMenuSrcPath`"" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Context menu entries added." -ForegroundColor Gray
            $installationResults.ContextMenu = "Success"
            
            # Restart Explorer to apply context menu changes
            Write-Host "Restarting Windows Explorer to apply changes..." -ForegroundColor Gray
            Stop-Process -Name explorer -Force
            Start-Process explorer.exe
        } else {
            $installationResults.ContextMenu = "Error: regedit exited with code $($process.ExitCode)"
        }
    } catch {
        $installationResults.ContextMenu = "Error: $($_.Exception.Message)"
    }
} else {
    $installationResults.ContextMenu = "Error: Context menu registry file missing"
}

# Summary
Write-Host "`n--- Installation Summary ---" -ForegroundColor Cyan
Write-Host "HandBrake:      $($installationResults.HandBrake)"
Write-Host "Kompresso-chan: $($installationResults.KompressoChan)"
Write-Host "Desktop Shortcut: $($installationResults.Shortcut)"
Write-Host "CLI Access:     $($installationResults.CLI)"
Write-Host "Context Menu:   $($installationResults.ContextMenu)"

Write-Host "`nInstallation Complete!" -ForegroundColor Yellow
Write-Host "Try running " -NoNewline; Write-Host "komchan --help" -ForegroundColor Cyan -NoNewline; Write-Host " to get started.`n"

for ($i = 15; $i -gt 0; $i--) {
    Write-Host -NoNewline "`rClosing this window in $($i)s... " -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}
exit
