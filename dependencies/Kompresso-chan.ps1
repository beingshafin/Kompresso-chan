param (
    [Parameter(Position=0)]
    [string]$Path,

    [Alias("u")]
    [switch]$Uninstall,

    [Alias("h", "?")]
    [switch]$Help
)

$Version = "1.2.0"

# Handle Help parameter
if ($Help -or ($args -contains "--help")) {
    Write-Host -NoNewline "$([char]27)[2J$([char]27)[H"
    Write-Host "
   __ __                                         
  / //_/__  __ _  ___  _______ ___ ___ ___  ____ 
 / ,< / _ \/  ' \/ _ \/ __/ -_|_-<(_-</ _ \/___/ 
/_/|_|\___/_/_/_/ .__/_/  \__/___/___/\___/      
               /_/         v$Version
" -ForegroundColor Cyan
    Write-Host "  HELP GUIDE" -ForegroundColor Cyan
    Write-Host "  ===========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Kompresso-chan is a powerful CLI and Context Menu tool for video compression."
    Write-Host ""
    Write-Host "  USAGE (CLI):" -ForegroundColor White
    Write-Host "    komchan [Path]              - Start compression for a file, folder, or .txt list."
    Write-Host "    komchan -Help               - Show this help guide."
    Write-Host "    komchan -Uninstall          - Uninstall Kompresso-chan from your system."
    Write-Host ""
    Write-Host "  CONTEXT MENU:" -ForegroundColor White
    Write-Host "    Right-click any file or folder in Windows Explorer and select"
    Write-Host "    'Compress with Kompresso-chan' to instantly add it to the queue."
    Write-Host "    If you select multiple items, they will all be queued for batch processing."
    Write-Host ""
    Write-Host "  FEATURES:" -ForegroundColor White
    Write-Host "    - Multiple Presets: 24 options covering 4K, 1080p, 720p, 576p, and 480p."
    Write-Host ""
    Write-Host "    - Processing Modes:"
    Write-Host "        1. Replace: Overwrite the original file with the compressed version."
    Write-Host "        2. Cascade: Save as 'original_kompressochan.mp4' in the same folder."
    Write-Host "        3. Mirror : Recreate the folder structure for bulk processing."
    Write-Host "    - Logging: Session and folder-specific logs are created automatically."
    Write-Host "    - Automation: Optional system shutdown after long compression tasks."
    Write-Host ""
    Write-Host "  Press any key to exit..." -ForegroundColor Yellow
    while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Handle Uninstall parameter
if ($Uninstall) {
    Write-Host -NoNewline "$([char]27)[2J$([char]27)[H"
    Write-Host "
   __ __                                         
  / //_/__  __ _  ___  _______ ___ ___ ___  ____ 
 / ,< / _ \/  ' \/ _ \/ __/ -_|_-<(_-</ _ \/___/ 
/_/|_|\___/_/_/_/ .__/_/  \__/___/___/\___/      
               /_/         v$Version
" -ForegroundColor Cyan
    Write-Host "  UNINSTALLER" -ForegroundColor Red
    Write-Host "  ============================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  This will remove Kompresso-chan and its context menu from your system."
    Write-Host ""
    Write-Host -NoNewline "  "
    $confirm = Read-Host "Are you sure you want to uninstall? [y/N]"
    if ($confirm.ToLower() -eq "y") {
        $uninstaller = "C:\Program Files\Kompresso-chan\uninstall.ps1"
        if (Test-Path $uninstaller) {
            Write-Host "  Launching uninstaller..." -ForegroundColor Gray
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$uninstaller`"" -Verb RunAs
            exit
        } else {
            Write-Host "  Error: Uninstaller not found at $uninstaller" -ForegroundColor Red
        }
    } else {
        Write-Host "  Uninstallation cancelled."
    }
    exit
}

Write-Host -NoNewline "$([char]27)[2J$([char]27)[H"
Write-Host "
   __ __                                         
  / //_/__  __ _  ___  _______ ___ ___ ___  ____ 
 / ,< / _ \/  ' \/ _ \/ __/ -_|_-<(_-</ _ \/___/ 
/_/|_|\___/_/_/_/ .__/_/  \__/___/___/\___/      
               /_/         v$Version
" -ForegroundColor Cyan

$handbrake = "C:\Program Files\HandBrake\HandBrakeCLI.exe"

# Check HandBrake exists, or try to find it in PATH
if (!(Test-Path $handbrake)) {
    $handbrake = Get-Command HandBrakeCLI -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (!$handbrake) {
        Write-Host "HandBrakeCLI not found at default path or in System PATH." -ForegroundColor Red
        Write-Host "Please install HandBrakeCLI or update the path in this script." -ForegroundColor Yellow
        exit
    }
}

# ---------------------------------------------------------------
#  PRESET MENU
# ---------------------------------------------------------------
$presets = @(
    # --- VERY FAST ---
    [PSCustomObject]@{ Id = 1;  Label = "4K - Very Fast AV1";   Preset = "Very Fast 2160p60 4K AV1"; OutputPct = "~40-60%"; AvgFPS = "120+"; CompressPct = 50 },
    [PSCustomObject]@{ Id = 2;  Label = "4K - Very Fast HEVC";  Preset = "Very Fast 2160p60 4K MKV HEVC"; OutputPct = "~45-65%"; AvgFPS = "110+"; CompressPct = 45 },
    [PSCustomObject]@{ Id = 3;  Label = "1080p - Very Fast";    Preset = "Very Fast 1080p30"; OutputPct = "~45-65%"; AvgFPS = "370+"; CompressPct = 45 },
    [PSCustomObject]@{ Id = 4;  Label = "720p - Very Fast";     Preset = "Very Fast 720p30"; OutputPct = "~40-46%"; AvgFPS = "460+"; CompressPct = 57 },
    [PSCustomObject]@{ Id = 5;  Label = "576p - Very Fast";     Preset = "Very Fast 576p25"; OutputPct = "~35-45%"; AvgFPS = "550+"; CompressPct = 60 },
    [PSCustomObject]@{ Id = 6;  Label = "480p - Very Fast";     Preset = "Very Fast 480p30"; OutputPct = "~30-40%"; AvgFPS = "600+"; CompressPct = 65 },
    
    # --- FAST ---
    [PSCustomObject]@{ Id = 7;  Label = "4K - Fast AV1";        Preset = "Fast 2160p60 4K AV1"; OutputPct = "~50-70%"; AvgFPS = "90+"; CompressPct = 40 },
    [PSCustomObject]@{ Id = 8;  Label = "4K - Fast HEVC";       Preset = "Fast 2160p60 4K MKV HEVC"; OutputPct = "~55-75%"; AvgFPS = "80+"; CompressPct = 35 },
    [PSCustomObject]@{ Id = 9;  Label = "1080p - Fast (Default)"; Preset = "Fast 1080p30"; OutputPct = "~50-89%"; AvgFPS = "260+"; CompressPct = 30 },
    [PSCustomObject]@{ Id = 10; Label = "720p - Fast";          Preset = "Fast 720p30"; OutputPct = "~45-55%"; AvgFPS = "350+"; CompressPct = 40 },
    [PSCustomObject]@{ Id = 11; Label = "576p - Fast";          Preset = "Fast 576p25"; OutputPct = "~40-50%"; AvgFPS = "450+"; CompressPct = 45 },
    [PSCustomObject]@{ Id = 12; Label = "480p - Fast";          Preset = "Fast 480p30"; OutputPct = "~35-45%"; AvgFPS = "500+"; CompressPct = 50 },

    # --- HQ ---
    [PSCustomObject]@{ Id = 13; Label = "4K - HQ AV1 Surround";  Preset = "HQ 2160p60 4K AV1 Surround"; OutputPct = "~60-80%"; AvgFPS = "60+"; CompressPct = 20 },
    [PSCustomObject]@{ Id = 14; Label = "4K - HQ HEVC Surround"; Preset = "HQ 2160p60 4K MKV HEVC Surround"; OutputPct = "~65-85%"; AvgFPS = "50+"; CompressPct = 15 },
    [PSCustomObject]@{ Id = 15; Label = "1080p - HQ Surround";   Preset = "HQ 1080p30 Surround"; OutputPct = "~60-172%"; AvgFPS = "210+"; CompressPct = 5 },
    [PSCustomObject]@{ Id = 16; Label = "720p - HQ Surround";    Preset = "HQ 720p30 Surround"; OutputPct = "~50-139%"; AvgFPS = "290+"; CompressPct = 10 },
    [PSCustomObject]@{ Id = 17; Label = "576p - HQ Surround";    Preset = "HQ 576p25 Surround"; OutputPct = "~45-120%"; AvgFPS = "350+"; CompressPct = 12 },
    [PSCustomObject]@{ Id = 18; Label = "480p - HQ Surround";    Preset = "HQ 480p30 Surround"; OutputPct = "~40-110%"; AvgFPS = "400+"; CompressPct = 15 },

    # --- SUPER HQ ---
    [PSCustomObject]@{ Id = 19; Label = "4K - Super HQ AV1";     Preset = "Super HQ 2160p60 4K AV1 Surround"; OutputPct = "~70-90%"; AvgFPS = "30+"; CompressPct = 10 },
    [PSCustomObject]@{ Id = 20; Label = "4K - Super HQ HEVC";    Preset = "Super HQ 2160p60 4K MKV HEVC Surround"; OutputPct = "~75-95%"; AvgFPS = "25+"; CompressPct = 5 },
    [PSCustomObject]@{ Id = 21; Label = "1080p - Super HQ";      Preset = "Super HQ 1080p30 Surround"; OutputPct = "~80-150%"; AvgFPS = "150+"; CompressPct = 0 },
    [PSCustomObject]@{ Id = 22; Label = "720p - Super HQ";       Preset = "Super HQ 720p30 Surround"; OutputPct = "~70-130%"; AvgFPS = "200+"; CompressPct = 0 },
    [PSCustomObject]@{ Id = 23; Label = "576p - Super HQ";       Preset = "Super HQ 576p25 Surround"; OutputPct = "~65-120%"; AvgFPS = "250+"; CompressPct = 0 },
    [PSCustomObject]@{ Id = 24; Label = "480p - Super HQ";       Preset = "Super HQ 480p30 Surround"; OutputPct = "~60-110%"; AvgFPS = "300+"; CompressPct = 0 }
)

Write-Host ""
Write-Host ""
Write-Host "  KOMPRESSO-CHAN - SELECT A PRESET"
Write-Host ""
Write-Host ("  {0,-3}  {1,-40}  {2,-14}  {3}" -f "#", "Preset Label", "Output %", "Avg FPS")
Write-Host ("  {0,-3}  {1,-40}  {2,-14}  {3}" -f ("-"*3), ("-"*40), ("-"*14), ("-"*7))

foreach ($p in $presets) {
    Write-Host ("  {0,-3}  {1,-40}  {2,-14}  {3}" -f `
        $p.Id,
        $p.Label,
        $p.OutputPct,
        $p.AvgFPS
    )
}

Write-Host ""

do {
    Write-Host -NoNewline "  "
    $choice = Read-Host "Enter preset number"
    if ($choice -as [int]) {
        $selectedPreset = $presets | Where-Object { $_.Id -eq [int]$choice }
    } else {
        $selectedPreset = $null
    }
    
    if (-not $selectedPreset) {
        Write-Host "  Invalid choice." -ForegroundColor Yellow
    }
} while (-not $selectedPreset)

Write-Host "  Selected : $($selectedPreset.Label)"
Write-Host ""

# ---------------------------------------------------------------
#  INPUT PATHS & SETTINGS
# ---------------------------------------------------------------
$inputItems = @()

# Helper to process a single path (could be a file, folder, or .txt list)
function Get-ItemsFromPath {
    param([string]$rawPath)
    $results = @()
    $cleaned = $rawPath.Trim().Trim('"').Trim("'")
    if ($cleaned -eq "") { return $results }
    
    if (Test-Path -LiteralPath $cleaned) {
        $item = Get-Item -LiteralPath $cleaned
        # If it's a .txt file, read paths from it
        if ($item.Extension -eq ".txt" -and -not $item.PSIsContainer) {
            $script:inputListPath = $item.FullName
            Write-Host "  Reading paths from list: $($item.Name)" -ForegroundColor Gray
            $lines = Get-Content -LiteralPath $cleaned
            foreach ($line in $lines) {
                $lineCleaned = $line.Trim().Trim('"').Trim("'")
                if ($lineCleaned -ne "") {
                    if (Test-Path -LiteralPath $lineCleaned) {
                        $results += Get-Item -LiteralPath $lineCleaned
                    } else {
                        Write-Host "  Path in list does not exist: $lineCleaned" -ForegroundColor Red
                    }
                }
            }
        } else {
            $results += $item
        }
    } else {
        Write-Host "  Input path does not exist: $cleaned" -ForegroundColor Red
    }
    return $results
}

if ($Path) {
    $inputItems = Get-ItemsFromPath -rawPath $Path
    Write-Host ""
}

if ($inputItems.Count -eq 0) {
    do {
        Write-Host -NoNewline "  "
        $userInput = Read-Host "Input path (File, Folder, or .txt list)"
        if ($userInput.Trim() -eq "") { continue }
        $inputItems = Get-ItemsFromPath -rawPath $userInput
        Write-Host ""
    } while ($inputItems.Count -eq 0)
}

$hasFolder = $false
foreach ($item in $inputItems) { if ($item.PSIsContainer) { $hasFolder = $true; break } }

Write-Host "  Compressed videos should:"
Write-Host "  1. Replace (Overwrite original)"
Write-Host "  2. Cascade (Create x_kompressochan.mp4)"
if ($hasFolder) {
    Write-Host "  3. Mirror  (New folder structure for folders)"
}
Write-Host ""

$maxMode = if ($hasFolder) { "3" } else { "2" }

do {
    Write-Host -NoNewline "  "
    $modeChoiceInput = Read-Host "Enter mode (1-$maxMode)"
    if ($modeChoiceInput -eq "") { 
        $modeChoice = "1" 
    } else { 
        $modeChoice = $modeChoiceInput 
    }
    
    $validModes = if ($hasFolder) { "1","2","3" } else { "1","2" }
    $validMode = ($validModes -contains $modeChoice)
    if (!$validMode) {
        Write-Host "  Invalid choice. Please enter $(if ($hasFolder) {'1, 2, or 3'} else {'1 or 2'})." -ForegroundColor Yellow
    }
} while (!$validMode)

$modeLabel = switch ($modeChoice) {
    "1" { "1 (Replace - Overwrite original)" }
    "2" { "2 (Cascade - Create x_kompressochan.mp4)" }
    "3" { "3 (Mirror - New folder structure)" }
    Default { "1 (Replace - Overwrite original)" }
}

Write-Host ""
Write-Host -NoNewline "  "
$shutdownPrompt = Read-Host "Shutdown when everything is done? [y/N]"
$doShutdown = ($shutdownPrompt.ToLower() -eq "y")
Write-Host -NoNewline "$([char]27)[2J$([char]27)[H"

# ---------------------------------------------------------------
#  MIRROR SETUP (if mode 3)
# ---------------------------------------------------------------
$mirrorMap = @{}
if ($modeChoice -eq "3") {
    foreach ($item in $inputItems) {
        if ($item.PSIsContainer) {
            $parent = Split-Path $item.FullName -Parent
            $leaf = Split-Path $item.FullName -Leaf
            $mirrorRoot = Join-Path $parent "$leaf`_kompressochan"
            $mirrorMap[$item.FullName] = $mirrorRoot

            if (Test-Path -LiteralPath $mirrorRoot) {
                Write-Host "`n  Warning: The mirror folder already exists: $mirrorRoot" -ForegroundColor Yellow
                Write-Host -NoNewline "  "
                $deleteChoice = Read-Host "Existing folder will be deleted. Proceed? [y/N]"
                if ($deleteChoice.ToLower() -eq "y") {
                    Write-Host "  Deleting existing mirror folder..." -ForegroundColor Gray
                    Remove-Item -LiteralPath $mirrorRoot -Recurse -Force -ErrorAction Stop
                } else {
                    Write-Host "  Exiting..."
                    exit
                }
            }
            
            if (!(Test-Path -LiteralPath $mirrorRoot)) {
                New-Item -ItemType Directory -Path $mirrorRoot -Force | Out-Null
            }
            
            Write-Host "`n  Preparing mirror structure for $($item.Name)..." -ForegroundColor Gray
            
            # 1. Mirror all directories
            Get-ChildItem -LiteralPath $item.FullName -Recurse -Directory | ForEach-Object {
                $rel = $_.FullName.Substring($item.FullName.Length).TrimStart("\")
                $dest = Join-Path $mirrorRoot $rel
                if (!(Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
            }
            
            # 2. Copy non-video files
            Write-Host "  Copying non-video files..." -ForegroundColor Gray
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File | Where-Object { $_.Extension -ne ".mp4" -and $_.Name -notlike "*compression_log*.txt" } | ForEach-Object {
                $rel = $_.FullName.Substring($item.FullName.Length).TrimStart("\")
                $dest = Join-Path $mirrorRoot $rel
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }
        }
    }
}

# ---------------------------------------------------------------
#  SCANNING
# ---------------------------------------------------------------
$tasks = @()
$seenFiles = @{}
$inputFolderCount = 0
$inputFileCount = 0

foreach ($rootObj in $inputItems) {
    if ($rootObj.PSIsContainer) { $inputFolderCount++ } else { $inputFileCount++ }
    Write-Host "`n  Scanning: $($rootObj.FullName)" -ForegroundColor Gray
    if ($rootObj.PSIsContainer) {
        $found = Get-ChildItem -LiteralPath $rootObj.FullName -Recurse -File -Filter *.mp4 -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*.tmp.mp4" -and $_.Name -notlike "*_kompressochan.mp4" }
        foreach ($f in $found) {
            if (!$seenFiles.ContainsKey($f.FullName)) {
                $seenFiles[$f.FullName] = $true
                $tasks += [PSCustomObject]@{ File = $f; InputRoot = $rootObj }
            }
        }
    } else {
        if ($rootObj.Extension -eq ".mp4") {
            if (!$seenFiles.ContainsKey($rootObj.FullName)) {
                $seenFiles[$rootObj.FullName] = $true
                $tasks += [PSCustomObject]@{ File = $rootObj; InputRoot = $rootObj }
            }
        }
    }
}

# ---------------------------------------------------------------
#  LOG INITIALIZATION
# ---------------------------------------------------------------
$allLogPaths = @()
$sessionLogPath = $null
$perLogStats = @{} # Track stats per folder/log
$logTime = Get-Date -Format "yyyy-M-d-HH.mm.ss"

$shouldCreateSessionLog = $false
if ($script:inputListPath) {
    # Check if there is only 1 folder, only 1 file, or exactly 1 folder & 1 file in the list
    $isSingleOrOneOfEach = ($inputFolderCount -le 1 -and $inputFileCount -le 1 -and ($inputFolderCount + $inputFileCount) -gt 0)
    $shouldCreateSessionLog = -not $isSingleOrOneOfEach
}

if ($shouldCreateSessionLog) {
    $logDirForSession = Split-Path $script:inputListPath -Parent
    
    # Special case: If the input list is the system one, put the session log next to the first actual item
    $systemInputPath = Join-Path ([Environment]::GetEnvironmentVariable('TEMP')) 'kompresso_input.txt'
    if ($script:inputListPath -eq $systemInputPath -and $inputItems.Count -gt 0) {
        $logDirForSession = Split-Path $inputItems[0].FullName -Parent
    }

    $sessionLogPath = Join-Path $logDirForSession "session_compression_log_$logTime.txt"
    $allLogPaths += $sessionLogPath

    $settingsHeader = @"
// settings
Chosen Preset  :  $($selectedPreset.Label)
Mode           :  $modeLabel
Start Time     :  $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    $settingsHeader | Out-File -LiteralPath $sessionLogPath -Encoding utf8
}

if ($tasks.Count -eq 0) {
    Write-Host "  No .mp4 files found." -ForegroundColor Yellow
    if ($sessionLogPath) { "No .mp4 files found." | Add-Content -LiteralPath $sessionLogPath }
    exit
}

$totalFiles = $tasks.Count
if ($script:inputListPath) {
    $formattedListSummary = @"

// list summary
Folders      : $inputFolderCount
Files        : $inputFileCount
Total MP4    : $totalFiles
"@
    Write-Host "`n  List Summary" -ForegroundColor Gray
    Write-Host "    Folders  : $inputFolderCount"
    Write-Host "    Files    : $inputFileCount"
    Write-Host "    Total MP4: $totalFiles`n"
    
    if ($sessionLogPath) { 
        $formattedListSummary | Add-Content -LiteralPath $sessionLogPath 
    }
} else {
    Write-Host "  Total videos found: $totalFiles"
}

if ($sessionLogPath) {
    "`n// timeline" | Add-Content -LiteralPath $sessionLogPath
}

$createFolderLogs = $true # Default for single inputs
if ($script:inputListPath -and $inputFolderCount -gt 0) {
    Write-Host -NoNewline "  "
    $logChoice = Read-Host "Create a log file for each folder in the list? [y/N]"
    $createFolderLogs = ($logChoice -eq "y" -or $logChoice -eq "Y")
}
Write-Host ""

$globalStartTime = Get-Date
Write-Host "  Start time   : $($globalStartTime.ToString('yyyy-MM-dd HH:mm:ss'))"

$successCount = 0
$failCount = 0
$currentFile = 0
$totalOriginalBytes = 0
$totalOutputBytes = 0
$lastUndone = ""

# ---------------------------------------------------------------
#  PROCESSING LOOP
# ---------------------------------------------------------------
foreach ($task in $tasks) {
    $currentFile++
    $inputFile = $task.File.FullName
    $lastUndone = $inputFile

    try {
        $rootObj = $task.InputRoot
        
        $logDir = if ($rootObj.PSIsContainer) { $rootObj.FullName } else { Split-Path $rootObj.FullName -Parent }
        $currentLogPath = if ($modeChoice -eq "3" -and $rootObj.PSIsContainer) { Join-Path $mirrorMap[$rootObj.FullName] "compression_log.txt" } else { Join-Path $logDir "compression_log.txt" }

        if (-not $perLogStats.ContainsKey($currentLogPath)) {
            $now = Get-Date
            $perLogStats[$currentLogPath] = @{ 
                success   = 0; 
                fail      = 0; 
                total     = 0; 
                origBytes = 0; 
                outBytes  = 0; 
                duration  = New-TimeSpan;
                startTime = $now;
                endTime   = $now
            }
            
            # If it's a folder log, write its specific header only if requested
            if ($currentLogPath -ne $sessionLogPath) {
                if ($createFolderLogs -and $rootObj.PSIsContainer) {
                    $folderHeader = @"
// settings
Chosen Preset  :  $($selectedPreset.Label)
Mode           :  $modeLabel
Start Time     :  $($now.ToString("yyyy-MM-dd HH:mm:ss"))

// timeline
"@
                    $folderHeader | Out-File -LiteralPath $currentLogPath -Encoding utf8
                    
                    if ($allLogPaths -notcontains $currentLogPath) {
                        $allLogPaths += $currentLogPath
                    }
                }
            }
        }

        $ps = $perLogStats[$currentLogPath]
        $ps.total++
        
        # Determine Output Path
        if ($modeChoice -eq "2") {
            $outputFile = $inputFile -replace '\.mp4$', '_kompressochan.mp4'
        }
        elseif ($modeChoice -eq "3") {
            if ($rootObj.PSIsContainer) {
                $relativePath = $inputFile.Substring($rootObj.FullName.Length).TrimStart("\")
                $mRoot = $mirrorMap[$rootObj.FullName]
                $outputFile = Join-Path $mRoot $relativePath
            } else {
                # File input in Mirror mode acts like Cascade
                $outputFile = $inputFile -replace '\.mp4$', '_kompressochan.mp4'
            }
        }
        else {
            $outputFile = "$inputFile.tmp.mp4"
        }

        $fileSizeMB     = [Math]::Round($task.File.Length / 1MB, 1)
        $estimatedOutMB = [Math]::Round($fileSizeMB * (1 - $selectedPreset.CompressPct / 100), 1)

        $displayPath = if ($task.InputRoot.PSIsContainer) { $task.File.FullName.Substring($task.InputRoot.FullName.Length).TrimStart("\") } else { $task.File.Name }
        Write-Host "`n  Processing [$currentFile/$totalFiles] : $displayPath" -ForegroundColor Cyan
        Write-Host "  Input size : $fileSizeMB MB   ->   Est. output: ~$estimatedOutMB MB"
        Write-Host "  Encoding..."

        $startTime = Get-Date
        & "$handbrake" `
            -i "$inputFile" `
            -o "$outputFile" `
            -Z "$($selectedPreset.Preset)" 2>&1 | ForEach-Object {
                if ($_ -match "Encoding: task") {
                    Write-Host -NoNewline "`r  $($_)"
                }
            }
        $elapsed = (Get-Date) - $startTime
        $timeStr = ""
        if ($elapsed.Hours -gt 0) { $timeStr += "$($elapsed.Hours)h " }
        if ($elapsed.Minutes -gt 0) { $timeStr += "$($elapsed.Minutes)m " }
        $timeStr += "$($elapsed.Seconds)s"

        Write-Host ""

        $status = "Fail"
        $sizeInfo = "$fileSizeMB MB -> ?"

        if (Test-Path -LiteralPath $outputFile) {
            $outputSize   = (Get-Item -LiteralPath $outputFile).Length
            $originalSize = (Get-Item -LiteralPath $inputFile).Length

            if ($outputSize -gt 0) {
                $totalOriginalBytes += $originalSize
                $totalOutputBytes += $outputSize

                if ($modeChoice -eq "1") {
                    Remove-Item -LiteralPath $inputFile -Force -ErrorAction Stop
                    Rename-Item -LiteralPath $outputFile -NewName $task.File.Name -ErrorAction Stop
                }

                $ps.success++
                $ps.origBytes += $originalSize
                $ps.outBytes += $outputSize
                $ps.duration += $elapsed
                $ps.endTime   = Get-Date

                $origMB = [Math]::Round($originalSize / 1MB, 2)
                $compMB = [Math]::Round($outputSize / 1MB, 2)
                $pctChange = [Math]::Round((($originalSize - $outputSize) / $originalSize) * 100, 1)

                if ($pctChange -ge 0) {
                    Write-Host "  Done: $origMB MB --> $compMB MB ($pctChange% smaller) in $timeStr" -ForegroundColor Gray
                } else {
                    $absPct = [Math]::Abs($pctChange)
                    Write-Host "  Done: $origMB MB --> $compMB MB ($absPct% larger) in $timeStr" -ForegroundColor Yellow
                }
                
                $status = "Success"
                $sizeInfo = "$origMB MB -> $compMB MB"
                $successCount++
                $lastUndone = ""
            }
            else {
                Write-Host "  Failed (empty output file)" -ForegroundColor Red
                Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
                $totalOriginalBytes += $originalSize
                $totalOutputBytes += $originalSize
                $failCount++
                
                $ps.fail++
                $ps.origBytes += $originalSize
                $ps.outBytes += $originalSize
                $ps.duration += $elapsed
            }
        }
        else {
            Write-Host "  Failed (no output file created)" -ForegroundColor Red
            $totalOriginalBytes += $task.File.Length
            $totalOutputBytes += $task.File.Length
            $failCount++
            
            $ps.fail++
            $ps.origBytes += $task.File.Length
            $ps.outBytes += $task.File.Length
            $ps.duration += $elapsed
            $ps.endTime   = Get-Date
        }
        
        $logEntry = "$inputFile , $status, $sizeInfo , $timeStr"
        foreach ($lp in $allLogPaths) {
            if ($lp -eq $sessionLogPath -or $lp -eq $currentLogPath) {
                $logEntry | Add-Content -LiteralPath $lp
            }
        }

    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "  Error: $errMsg" -ForegroundColor Red
        if (Test-Path -LiteralPath $outputFile) {
            Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
        }
        $totalOriginalBytes += $task.File.Length
        $totalOutputBytes += $task.File.Length
        $failCount++

        $ps.fail++
        $ps.origBytes += $task.File.Length
        $ps.outBytes += $task.File.Length
        $ps.endTime   = Get-Date
        # Note: duration not updated here as it might have failed early

        $logEntry = "$inputFile , Error, $errMsg"
        foreach ($lp in $allLogPaths) {
            if ($lp -eq $sessionLogPath -or $lp -eq $currentLogPath) {
                $logEntry | Add-Content -LiteralPath $lp
            }
        }
    }
}

# ---------------------------------------------------------------
#  SUMMARY
# ---------------------------------------------------------------
$globalDuration = (Get-Date) - $globalStartTime
$gTimeStr = ""
if ($globalDuration.Hours -gt 0) { $gTimeStr += "$($globalDuration.Hours)h " }
if ($globalDuration.Minutes -gt 0) { $gTimeStr += "$($globalDuration.Minutes)m " }
$gTimeStr += "$($globalDuration.Seconds)s"

$totalOrigMB = [Math]::Round($totalOriginalBytes / 1MB, 1)
$totalOutMB = [Math]::Round($totalOutputBytes / 1MB, 1)
$totalSavedMB = [Math]::Round(($totalOriginalBytes - $totalOutputBytes) / 1MB, 1)
$totalSavedPct = 0
if ($totalOriginalBytes -gt 0) {
    $totalSavedPct = [Math]::Round(($totalSavedMB * 1024 * 1024 / $totalOriginalBytes) * 100, 1)
}

foreach ($lp in $allLogPaths) {
    $stats = $null
    if ($lp -eq $sessionLogPath) {
        $stats = @{
            success   = $successCount
            total     = $totalFiles
            fail      = $failCount
            origBytes = $totalOriginalBytes
            outBytes  = $totalOutputBytes
            duration  = $globalDuration
        }
    } else {
        $stats = $perLogStats[$lp]
    }

    $s_success   = $stats.success
    $s_total     = $stats.total
    $s_fail      = $stats.fail
    $s_origBytes = $stats.origBytes
    $s_outBytes  = $stats.outBytes
    $s_duration  = $stats.duration

    $s_timeStr = ""
    if ($s_duration.Hours -gt 0) { $s_timeStr += "$($s_duration.Hours)h " }
    if ($s_duration.Minutes -gt 0) { $s_timeStr += "$($s_duration.Minutes)m " }
    $s_timeStr += "$($s_duration.Seconds)s"

    $s_origMB = [Math]::Round($s_origBytes / 1MB, 1)
    $s_outMB = [Math]::Round($s_outBytes / 1MB, 1)
    $s_savedMB = [Math]::Round(($s_origBytes - $s_outBytes) / 1MB, 1)
    $s_savedPct = 0
    if ($s_origBytes -gt 0) {
        $s_savedPct = [Math]::Round(($s_savedMB * 1024 * 1024 / $s_origBytes) * 100, 1)
    }

    $s_savingsLine = if ($s_savedMB -ge 0) {
        "Total Saved  :  $s_savedMB MB ($s_savedPct% smaller)"
    } else {
        "Total Change :  $([Math]::Abs($s_savedMB)) MB larger"
    }

    $s_endTime = if ($lp -eq $sessionLogPath) { Get-Date } else { $stats.endTime }

    $s_text = @"

// summary
Total        :  $s_success/$s_total ($s_timeStr) $(if ($s_fail -gt 0) { "($s_fail failed)" })
Total Size   :  $s_origMB MB -> $s_outMB MB
$s_savingsLine
End Time     :  $($s_endTime.ToString("yyyy-MM-dd HH:mm:ss"))
"@

    if ($lastUndone -and $lastUndone -ne "" -and $lp -eq $sessionLogPath) {
        $s_text += "`nLast Undone Job (if exists) : $lastUndone"
    }

    $s_text | Add-Content -LiteralPath $lp
}

Write-Host "`n`n  SUMMARY"
Write-Host "  Total        : $successCount/$totalFiles ($gTimeStr) $(if ($failCount -gt 0) { "($failCount failed)" })"
Write-Host "  Total Size   : $totalOrigMB MB -> $totalOutMB MB"
if ($totalSavedMB -ge 0) {
    Write-Host "  Total Saved  : $totalSavedMB MB ($totalSavedPct% smaller)"
} else {
    $absSavedMB = [Math]::Abs($totalSavedMB)
    Write-Host "  Total Change : $absSavedMB MB larger"
}
Write-Host "  End Time     : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
if ($sessionLogPath) {
    Write-Host "  Session Log  : $sessionLogPath"
} elseif ($allLogPaths.Count -gt 0) {
    Write-Host "  Log file     : $($allLogPaths[0])"
}

Write-Host "`n  All tasks completed!"

if ($doShutdown) {
    Write-Host "Shutting down in 30 seconds... (Cancel with 'shutdown /a')" -ForegroundColor Red
    shutdown /s /t 30
} else {
    Write-Host "`n  Press any key to exit..." -ForegroundColor Yellow
    while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
