param (
    [Parameter(Position=0)]
    [string]$Path,

    [Alias("u")]
    [switch]$Uninstall,

    [Alias("h", "?")]
    [switch]$Help,

    [Alias("r")]
    [string]$Res,

    [Alias("f")]
    [string]$Fps,

    [Alias("q")]
    [string]$Qual,

    [Alias("p")]
    [string]$Preset,

    [Alias("shut")]
    [string]$Shutdown = "",

    [Alias("l")]
    [string]$Log = "",

    [Alias("m")]
    [string]$Mode,

    [string]$Quick = "",

    [string]$Smart = "",

    [switch]$Config
)

$Version = "1.0.0-stable"

function Resolve-BoolFlag {
    param([string]$value, [bool]$wasPassed)
    if (-not $wasPassed) { return $false }
    if ($value -eq "") { return $true }
    $lower = $value.ToLower().TrimStart(':')
    if ($lower -match "^(y|yes|true|1)$") { return $true }
    if ($lower -match "^(n|no|false|0)$") { return $false }
    return $true
}

function Resolve-LogMode {
    param([string]$value)
    if ($value -eq "") { return @{ Session = $true; Folder = $true } }
    $lower = $value.ToLower()
    switch ($lower) {
        { $_ -match "^(session|s)$" } { return @{ Session = $true;  Folder = $false } }
        { $_ -match "^(folder|f)$" }  { return @{ Session = $false; Folder = $true  } }
        { $_ -match "^(both|b)$" }    { return @{ Session = $true;  Folder = $true  } }
        { $_ -match "^(none|n)$" }    { return @{ Session = $false; Folder = $false } }
        Default { return @{ Session = $false; Folder = $false } }
    }
}
$resolutions = @(
    [PSCustomObject]@{ Id = 1; Label = "Original"; HandBrakeScale = $null }
    [PSCustomObject]@{ Id = 2; Label = "4K";       HandBrakeScale = "2160" }
    [PSCustomObject]@{ Id = 3; Label = "1440p";    HandBrakeScale = "1440" }
    [PSCustomObject]@{ Id = 4; Label = "1080p";    HandBrakeScale = "1080" }
    [PSCustomObject]@{ Id = 5; Label = "720p";     HandBrakeScale = "720" }
    [PSCustomObject]@{ Id = 6; Label = "480p";     HandBrakeScale = "480" }
)

$qualityPresets = @(
    [PSCustomObject]@{ Id = 1; Label = "VeryFast";    EncoderPreset = "veryfast";  RF = 24 }
    [PSCustomObject]@{ Id = 2; Label = "Fast";        EncoderPreset = "fast";      RF = 22 }
    [PSCustomObject]@{ Id = 3; Label = "Balanced";    EncoderPreset = "medium";    RF = 20 }
    [PSCustomObject]@{ Id = 4; Label = "HQ";          EncoderPreset = "slow";      RF = 18 }
    [PSCustomObject]@{ Id = 5; Label = "SuperHQ";     EncoderPreset = "slower";    RF = 16 }
)

# HandBrake-supported input containers; output is always .mp4
$script:SupportedVideoExtensions = @(
    '.mp4', '.m4v', '.mkv', '.avi', '.mov', '.mpg', '.mpeg',
    '.ts', '.mts', '.m2ts', '.wmv', '.flv', '.webm', '.3gp', '.vob'
)

function Test-IsSupportedVideoFile {
    param($FileItem)
    if (-not $FileItem.Extension) { return $false }
    return $script:SupportedVideoExtensions -contains $FileItem.Extension.ToLower()
}

function Test-IsKompressoOutputArtifact {
    param([string]$FileName)
    return ($FileName -like "*.tmp.mp4" -or $FileName -like "*_kompressochan.mp4")
}

function Get-CascadeOutputPath {
    param([string]$InputFile)
    $dir = [System.IO.Path]::GetDirectoryName($InputFile)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    return [System.IO.Path]::Combine($dir, "${base}_kompressochan.mp4")
}

function Get-MirrorOutputPath {
    param([string]$MirrorRoot, [string]$RelativePath)
    $relMp4 = [System.IO.Path]::ChangeExtension($RelativePath, '.mp4')
    return [System.IO.Path]::Combine($MirrorRoot, $relMp4)
}

function Get-ReplaceOutputFinalName {
    param([string]$InputFile)
    return [System.IO.Path]::GetFileName([System.IO.Path]::ChangeExtension($InputFile, '.mp4'))
}

function Resolve-Resolution {
    param([string]$value)
    $id = $value -as [int]
    if ($id -ne $null) {
        if ($id -lt 1 -or $id -gt 6) { return $null }
        return $resolutions | Where-Object { $_.Id -eq $id }
    }
    return $resolutions | Where-Object { $_.Label.ToLower() -eq $value.ToLower() }
}

function Resolve-Quality {
    param([string]$value)
    $id = $value -as [int]
    if ($id -ne $null) {
        if ($id -lt 1 -or $id -gt 5) { return $null }
        return $qualityPresets | Where-Object { $_.Id -eq $id }
    }
    return $qualityPresets | Where-Object { $_.Label.ToLower() -eq $value.ToLower() }
}

function Resolve-Fps {
    param([string]$value)
    if ($value -eq "1" -or $value.ToLower() -eq "original") { return @{ Fps = "Original"; Custom = $null } }
    $v = $value -as [int]
    if ($v -ne $null) {
        if ($v -lt 1) { return $null }
        return @{ Fps = $v; Custom = $v }
    }
    $v2 = $value -as [double]
    if ($v2 -ne $null) {
        $v = [double]$value
        if ($v -lt 1) { return $null }
        return @{ Fps = $v; Custom = $v }
    }
    return $null
}

function Get-ConfigPath {
    $configDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Kompresso-chan'
    return Join-Path $configDir 'config.json'
}

function Get-Defaults {
    $configPath = Get-ConfigPath
    $defaultConfig = [ordered]@{
        resolution = "original"
        fps        = "original"
        quality    = "veryfast"
        mode       = "mirror"
        smart      = $false
        shutdown   = $false
        log        = "both"
    }

    # If config file doesn't exist, create it with defaults and return
    if (-not (Test-Path $configPath)) {
        Save-Defaults -config $defaultConfig
        return $defaultConfig
    }

    # Config file exists - read it and use its values
    $config = [ordered]@{}

    # Start with defaults, then override with whatever is in the config file
    foreach ($key in $defaultConfig.Keys) {
        $config[$key] = $defaultConfig[$key]
    }

    try {
        $content = Get-Content $configPath -Raw -ErrorAction Stop
        $parsed = $content | ConvertFrom-Json -ErrorAction Stop
        foreach ($prop in $parsed.PSObject.Properties) {
            $config[$prop.Name] = $prop.Value
        }
    } catch {
        # If parsing fails, return defaults without overwriting the file
        return $defaultConfig
    }

    # Normalize resolution: accept any string value as-is (trust the config)
    $resValue = [string]$config.resolution
    $validResolutions = @("original", "4k", "1440p", "1080p", "720p", "480p")
    $resValid = $false
    foreach ($v in $validResolutions) { if ($resValue -eq $v) { $resValid = $true; break } }
    if (-not $resValid) {
        $resId = $resValue -as [int]
        if ($resId -ge 1 -and $resId -le 6) {
            $config.resolution = ($resolutions | Where-Object { $_.Id -eq $resId }).Label.ToLower()
        } else {
            $config.resolution = $defaultConfig.resolution
        }
    }

    # Normalize quality: accept any string value as-is (trust the config)
    $qualValue = [string]$config.quality
    $validQualities = @("veryfast", "fast", "balanced", "hq", "superhq")
    $qualValid = $false
    foreach ($v in $validQualities) { if ($qualValue -eq $v) { $qualValid = $true; break } }
    if (-not $qualValid) {
        $qualId = $qualValue -as [int]
        if ($qualId -ge 1 -and $qualId -le 5) {
            $config.quality = ($qualityPresets | Where-Object { $_.Id -eq $qualId }).Label.ToLower()
        } else {
            $config.quality = $defaultConfig.quality
        }
    }

    # Normalize FPS
    if ([string]$config.fps -eq "1") { $config.fps = "original" }

    # Normalize mode
    $modeValue = [string]$config.mode
    $validModes = @("replace", "cascade", "mirror")
    $modeValid = $false
    foreach ($v in $validModes) { if ($modeValue -eq $v) { $modeValid = $true; break } }
    if (-not $modeValid) {
        $config.mode = $defaultConfig.mode
    }

    # Normalize log
    $logValue = [string]$config.log
    $validLogs = @("session", "folder", "both", "none")
    $logValid = $false
    foreach ($v in $validLogs) { if ($logValue -eq $v) { $logValid = $true; break } }
    if (-not $logValid) {
        $config.log = $defaultConfig.log
    }

    return $config
}

function Save-Defaults {
    param([hashtable]$config)
    $configPath = Get-ConfigPath
    $configDir = Split-Path $configPath -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    $ordered = [ordered]@{
        resolution = $config.resolution
        fps        = $config.fps
        quality    = $config.quality
        mode       = $config.mode
        smart      = $config.smart
        shutdown   = $config.shutdown
        log        = $config.log
    }
    $ordered | ConvertTo-Json | Out-File -LiteralPath $configPath -Encoding utf8
}


function IdToLabel {
    param([string]$type, [string]$value)
    if ($type -eq "resolution") {
        $res = Resolve-Resolution -value $value
        if ($res) { return $res.Label.ToLower() }
        return "original"
    }
    if ($type -eq "quality") {
        $qual = Resolve-Quality -value $value
        if ($qual) { return $qual.Label.ToLower() }
        return "veryfast"
    }
    return $value
}

function LabelToId {
    param([string]$type, [string]$value)
    if ($type -eq "resolution") {
        $res = Resolve-Resolution -value $value
        if ($res) { return $res.Id.ToString() }
        return "1"
    }
    if ($type -eq "quality") {
        $qual = Resolve-Quality -value $value
        if ($qual) { return $qual.Id.ToString() }
        return "1"
    }
    return $value
}

$defaults = Get-Defaults

$doQuick = Resolve-BoolFlag -value $Quick -wasPassed $PSBoundParameters.ContainsKey('Quick')
$doSmart = Resolve-BoolFlag -value $Smart -wasPassed $PSBoundParameters.ContainsKey('Smart')
$doShutdown = Resolve-BoolFlag -value $Shutdown -wasPassed $PSBoundParameters.ContainsKey('Shutdown')

if ($PSBoundParameters.ContainsKey('Log')) {
    $logMode = Resolve-LogMode -value $Log
} else {
    $logMode = Resolve-LogMode -value $defaults.log
}

# Handle Config parameter
if ($Config) {
    $configArgs = $PSBoundParameters.Keys | Where-Object { $_ -ne 'Config' }
    if ($configArgs.Count -gt 0 -or ($Path -ne "")) {
        Write-Host "  ERROR: --config must be used alone." -ForegroundColor Red
        exit
    }
    Write-Host -NoNewline "$([char]27)[2J$([char]27)[H"

    function Get-ResLine {
        $line = ""
        for ($i = 1; $i -le 6; $i++) {
            $label = ($resolutions | Where-Object { $_.Id -eq $i }).Label
            $resLabel = $label.ToLower()
            $marker = if ($defaults.resolution -eq $resLabel) { " *" } else { "" }
            $line += "[$i] $label$marker"
            if ($i -lt 6) { $line += "   " }
        }
        return $line
    }

    function Get-QualLine {
        $line = ""
        for ($i = 1; $i -le 5; $i++) {
            $label = ($qualityPresets | Where-Object { $_.Id -eq $i }).Label
            $qualLabel = $label.ToLower()
            $marker = if ($defaults.quality -eq $qualLabel) { " *" } else { "" }
            $line += "[$i] $label$marker"
            if ($i -lt 5) { $line += "   " }
        }
        return $line
    }

    function Get-ModeLine {
        $line = ""
        $modes = @("Replace", "Cascade", "Mirror")
        for ($i = 1; $i -le 3; $i++) {
            $marker = if ($defaults.mode -eq $modes[$i-1].ToLower()) { " *" } else { "" }
            $line += "[$i] $($modes[$i-1])$marker"
            if ($i -lt 3) { $line += "   " }
        }
        return $line
    }

    function Get-LogLine {
        $line = ""
        $logs = @("Session", "Folder", "Both", "None")
        for ($i = 1; $i -le 4; $i++) {
            $marker = if ($defaults.log -eq $logs[$i-1].ToLower()) { " *" } else { "" }
            $line += "[$i] $($logs[$i-1])$marker"
            if ($i -lt 4) { $line += "   " }
        }
        return $line
    }

    function Get-FpsHint {
        if ($defaults.fps -eq "1" -or $defaults.fps -eq "original") {
            return "Enter a Number or use 1 for Original (current: Original*)"
        } else {
            return "Enter a Number or use 1 for Original (current: $($defaults.fps)*)"
        }
    }

    $configPath = Get-ConfigPath

    Write-Host "KOMPRESSO-CHAN DEFAULT SETUP"
    Write-Host ""
    Write-Host "Config File"
    Write-Host "  $configPath"
    Write-Host "  (You can also edit this file manually.)"
    Write-Host ""
    Write-Host "Press ESC to exit without saving."
    Write-Host "* = current default"
    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host ""
    Write-Host "VIDEO"
    Write-Host ""
    Write-Host "Resolution"
    Write-Host "  $(Get-ResLine)"
    do {
        Write-Host -NoNewline "  > "
        $resInput = Read-Host
        if ($resInput.ToLower() -eq "esc") { exit }
        if ($resInput -eq "") { break }
        $resInt = $resInput -as [int]
        if ($resInt -ge 1 -and $resInt -le 6) {
            $defaults.resolution = ($resolutions | Where-Object { $_.Id -eq $resInt }).Label.ToLower()
            break
        }
        $resLower = $resInput.ToLower()
        $match = @("original","4k","1440p","1080p","720p","480p") | Where-Object { $_ -eq $resLower }
        if ($match) {
            $defaults.resolution = $resLower
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Yellow
    } while ($true)

    Write-Host ""
    Write-Host "FPS"
    Write-Host "  $(Get-FpsHint)"
    do {
        Write-Host -NoNewline "  > "
        $fpsInput = Read-Host
        if ($fpsInput.ToLower() -eq "esc") { exit }
        if ($fpsInput -eq "") { break }
        if ($fpsInput -eq "1") {
            $defaults.fps = "original"
            break
        }
        $fpsVal = $fpsInput -as [double]
        if ($fpsVal -ne $null -and $fpsVal -ge 1) {
            $defaults.fps = $fpsInput
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Yellow
    } while ($true)

    Write-Host ""
    Write-Host "Quality Preset"
    Write-Host "  $(Get-QualLine)"
    do {
        Write-Host -NoNewline "  > "
        $qualInput = Read-Host
        if ($qualInput.ToLower() -eq "esc") { exit }
        if ($qualInput -eq "") { break }
        $qualInt = $qualInput -as [int]
        if ($qualInt -ge 1 -and $qualInt -le 5) {
            $defaults.quality = ($qualityPresets | Where-Object { $_.Id -eq $qualInt }).Label.ToLower()
            break
        }
        $qualLower = $qualInput.ToLower()
        $match = @("veryfast","fast","balanced","hq","superhq") | Where-Object { $_ -eq $qualLower }
        if ($match) {
            $defaults.quality = $qualLower
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Yellow
    } while ($true)

    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host ""
    Write-Host "OUTPUT"
    Write-Host ""
    Write-Host "Save Mode"
    Write-Host "  $(Get-ModeLine)"
    do {
        Write-Host -NoNewline "  > "
        $modeInput = Read-Host
        if ($modeInput.ToLower() -eq "esc") { exit }
        if ($modeInput -eq "") { break }
        $modeLower = $modeInput.ToLower()
        $modeChoice = switch ($modeLower) {
            "1" { "replace" }
            "replace" { "replace" }
            "2" { "cascade" }
            "cascade" { "cascade" }
            "3" { "mirror" }
            "mirror" { "mirror" }
            Default { "" }
        }
        if ($modeChoice -ne "") {
            $defaults.mode = $modeChoice
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Yellow
    } while ($true)

    Write-Host ""
    Write-Host "Smart Mode"
    Write-Host "  Skip replacement if compressed file is larger."
    $smartCurrent = if ($defaults.smart) { "[Y/n]*" } else { "[y/N]" }
    Write-Host -NoNewline "  $smartCurrent > "
    $smartInput = Read-Host
    if ($smartInput.ToLower() -eq "esc") { exit }
    if ($smartInput -eq "") {
    } elseif ($smartInput.ToLower() -eq "y") {
        $defaults.smart = $true
    } else {
        $defaults.smart = $false
    }

    Write-Host ""
    Write-Host "Shutdown After Finish"
    $shutCurrent = if ($defaults.shutdown) { "[Y/n]*" } else { "[y/N]" }
    Write-Host -NoNewline "  $shutCurrent > "
    $shutInput = Read-Host
    if ($shutInput.ToLower() -eq "esc") { exit }
    if ($shutInput -eq "") {
    } elseif ($shutInput.ToLower() -eq "y") {
        $defaults.shutdown = $true
    } else {
        $defaults.shutdown = $false
    }

    Write-Host ""
    Write-Host "--------------------------------------------------"
    Write-Host ""
    Write-Host "LOGGING"
    Write-Host ""
    Write-Host "Log Mode"
    Write-Host "  $(Get-LogLine)"
    do {
        Write-Host -NoNewline "  > "
        $logInput = Read-Host
        if ($logInput.ToLower() -eq "esc") { exit }
        if ($logInput -eq "") { break }
        $logLower = $logInput.ToLower()
        $logChoice = switch ($logLower) {
            "1" { "session" }
            "s" { "session" }
            "session" { "session" }
            "2" { "folder" }
            "f" { "folder" }
            "folder" { "folder" }
            "3" { "both" }
            "b" { "both" }
            "both" { "both" }
            "4" { "none" }
            "n" { "none" }
            "none" { "none" }
            Default { "" }
        }
        if ($logChoice -ne "") {
            $defaults.log = $logChoice
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Yellow
    } while ($true)

    Write-Host ""
    Write-Host "--------------------------------------------------"

    Save-Defaults -config $defaults
    Write-Host ""
    Write-Host "Saved Successfully"
    Write-Host ""
    Write-Host "Config updated:"
    Write-Host "  $configPath"
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Handle Help parameter
if ($Help -or $Path -eq "--help" -or $Path -eq "-help" -or $Path -eq "-h" -or $Path -eq "-?") {
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
    Write-Host "  USAGE:" -ForegroundColor White
    Write-Host "    komchan [Path]              - Start compression for a file, folder, or .txt list."
    Write-Host "    komchan --help, -h          - Show this help guide."
    Write-Host "    komchan --uninstall         - Uninstall Kompresso-chan from your system."
    Write-Host ""
    Write-Host "  FLAGS:" -ForegroundColor White
    Write-Host "    -r, -res      Resolution (number or name, case-insensitive)"
    Write-Host "    -f, -fps      FPS (1 = original, or a number like 30, 60, 23.976)"
    Write-Host "    -q, -qual     Quality (number or name, case-insensitive)"
    Write-Host "    -m, -mode     Processing mode: replace/cascade/mirror (case-insensitive)"
    Write-Host "    -p, -preset   Single string combining res/fps/qual"
    Write-Host "    -shut         Auto-shutdown PC after all encoding finishes (append :y/:n or y/n)"
    Write-Host "    -l, -log      Log mode: session(s), folder(f), both(b), none(n). Default: both"
    Write-Host "    -quick        Skip all prompts, use defaults (append :y/:n or y/n)"
    Write-Host "    -smart        Replace/Mirror: skip if compressed is larger (append :y/:n or y/n)"
    Write-Host "    --config      Open interactive config menu to set persistent defaults"
    Write-Host "    Note: Defaults stored in %APPDATA%\Kompresso-chan\config.json"
    Write-Host ""
    Write-Host "  RESOLUTION OPTIONS:" -ForegroundColor White
    Write-Host "    1, original   - Keep source resolution"
    Write-Host "    2, 4k         - Scale to 2160p max"
    Write-Host "    3, 1440p      - Scale to 1440p max"
    Write-Host "    4, 1080p      - Scale to 1080p max"
    Write-Host "    5, 720p       - Scale to 720p max"
    Write-Host "    6, 480p       - Scale to 480p max"
    Write-Host ""
    Write-Host "  FPS OPTIONS:" -ForegroundColor White
    Write-Host "    1             - Keep source framerate"
    Write-Host "    <number>      - Set custom FPS (e.g. 30, 60, 23.976)"
    Write-Host "    Note: If configured FPS exceeds source framerate, it will be capped automatically."
    Write-Host ""
    Write-Host "  QUALITY OPTIONS:" -ForegroundColor White
    Write-Host "    1, veryfast   - Fast encoding, smaller file"
    Write-Host "    2, fast       - Good speed/quality balance"
    Write-Host "    3, balanced   - Medium encoding, good quality"
    Write-Host "    4, hq         - Slow encoding, high quality"
    Write-Host "    5, superhq    - Slowest encoding, best quality"
    Write-Host ""
    Write-Host "  SUPPORTED INPUT FORMATS (output is always .mp4):" -ForegroundColor White
    Write-Host "    mp4, m4v, mkv, avi, mov, mpg, mpeg, ts, mts, m2ts, wmv, flv, webm, 3gp, vob"
    Write-Host ""
    Write-Host "  PROCESSING MODES:" -ForegroundColor White
    Write-Host "    1, replace  - Overwrite the original with compressed .mp4 (extension updated if needed)."
    Write-Host "    2, cascade  - Save as 'basename_kompressochan.mp4' in the same folder."
    Write-Host "    3, mirror   - Recreate the folder structure for bulk processing (videos as .mp4)."
    Write-Host "    Note: If only file paths are given (no folders), mirror mode falls back to cascade."
    Write-Host ""
    Write-Host "  EXAMPLES:" -ForegroundColor White
    Write-Host "    # Interactive prompt (enter path and choose settings manually)"
    Write-Host "    komchan video.mp4"
    Write-Host ""
    Write-Host "    # Skip prompt with short flags"
    Write-Host "    komchan video.mp4 -r 1080p -f 60 -q fast"
    Write-Host ""
    Write-Host "    # Same as above using numbers"
    Write-Host "    komchan video.mp4 -r 4 -f 60 -q 2"
    Write-Host ""
    Write-Host "    # Use preset string instead of individual flags"
    Write-Host "    komchan video.mp4 -preset \"1080p 60 fast\""
    Write-Host ""
    Write-Host "    # Cascade mode (creates _kompressochan.mp4 next to original)"
    Write-Host "    komchan video.mp4 -r 720p -f 30 -q 2 -m cascade"
    Write-Host ""
    Write-Host "    # Mirror mode for folder batch (recreates folder structure)"
    Write-Host "    komchan D:\Recordings -r 1080p -f 60 -q fast -m mirror"
    Write-Host ""
    Write-Host "    # Auto-shutdown after encoding completes"
    Write-Host "    komchan D:\Recordings -r 720p -f 30 -q 2 -shut"
    Write-Host ""
    Write-Host "    # Force folder logs for multi-folder batch"
    Write-Host "    komchan my_list.txt -r 4k -f 1 -q balanced -log"
    Write-Host ""
    Write-Host "    # Combine flags for overnight batch run"
    Write-Host "    komchan D:\Movies -r 1440p -f 30 -q fast -shut -log"
    Write-Host ""
    Write-Host "  CONTEXT MENU:" -ForegroundColor White
    Write-Host "    Right-click any file or folder in Windows Explorer and select"
    Write-Host "    'Compress with Kompresso-chan' to instantly add it to the queue."
    Write-Host "    If you select multiple items, they will all be queued for batch processing."
    Write-Host ""
    Write-Host "  Press any key to exit..." -ForegroundColor Yellow
    while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Handle Uninstall parameter
if ($Uninstall -or $Path -eq "--uninstall" -or $Path -eq "-uninstall") {
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

$useCliPreset = ($Res -or $Fps -or $Qual -or $Preset -or $doQuick)

if ($doQuick) {
    if (-not $Res) { $Res = $defaults.resolution }
    if (-not $Fps) { $Fps = $defaults.fps }
    if (-not $Qual) { $Qual = $defaults.quality }
    if (-not $Mode) { $Mode = $defaults.mode }
    if (-not $Preset) { $Preset = "" }
}

if ($useCliPreset) {
    if ($Preset) {
        $presetParts = $Preset.Trim() -split '\s+'
        if ($presetParts.Count -ne 3) {
            Write-Host "  Invalid preset format. Use: Resolution FPS Quality" -ForegroundColor Red
            Write-Host "  Example: komchan video.mp4 -preset `"1080p 60 fast`"" -ForegroundColor Yellow
            exit
        }
        $Res = $presetParts[0]
        $Fps = $presetParts[1]
        $Qual = $presetParts[2]
    }

    if (-not $Res) { $Res = $defaults.resolution }
    if (-not $Fps) { $Fps = $defaults.fps }
    if (-not $Qual) { $Qual = $defaults.quality }

    $selectedResolution = Resolve-Resolution -value $Res
    if (-not $selectedResolution) {
        Write-Host "  Invalid resolution: $Res" -ForegroundColor Red
        Write-Host "  Valid: 1-6 or original/4k/1440p/1080p/720p/480p" -ForegroundColor Yellow
        exit
    }

    $fpsResult = Resolve-Fps -value $Fps
    if (-not $fpsResult) {
        Write-Host "  Invalid FPS: $Fps" -ForegroundColor Red
        Write-Host "  Valid: 1 or a positive number" -ForegroundColor Yellow
        exit
    }
    $selectedFps = $fpsResult.Fps
    $customFps = $fpsResult.Custom

    $selectedQuality = Resolve-Quality -value $Qual
    if (-not $selectedQuality) {
        Write-Host "  Invalid quality: $Qual" -ForegroundColor Red
        Write-Host "  Valid: 1-5 or veryfast/fast/balanced/hq/superhq" -ForegroundColor Yellow
        exit
    }

    Write-Host "  Selected:"
    Write-Host "  Resolution -> $($selectedResolution.Id). $($selectedResolution.Label)"
    Write-Host "  FPS -> $($selectedFps)"
    Write-Host "  Quality -> $($selectedQuality.Id). $($selectedQuality.Label)"
    Write-Host ""
} else {
Write-Host "  KOMPRESSO-CHAN"
Write-Host ""
Write-Host "  Select options:"
Write-Host ""
Write-Host "  --------------------------------------------------"
Write-Host ""

$resLine = ""
for ($i = 1; $i -le 6; $i++) {
    $label = ($resolutions | Where-Object { $_.Id -eq $i }).Label
    $resLabel = $label.ToLower()
    $marker = if ($defaults.resolution -eq $resLabel) { " *" } else { "" }
    $resLine += "[$i] $label$marker"
    if ($i -lt 6) { $resLine += "   " }
}
Write-Host "  Resolution"
Write-Host "  $resLine"
Write-Host ""

if ($defaults.fps -eq "1" -or $defaults.fps -eq "original") {
    $fpsHint = "Enter a Number or use 1 for Original (current: Original*)"
} else {
    $fpsHint = "Enter a Number or use 1 for Original (current: $($defaults.fps)*)"
}
Write-Host "  FPS"
Write-Host "  $fpsHint"
Write-Host ""

$qualLine = ""
for ($i = 1; $i -le 5; $i++) {
    $label = ($qualityPresets | Where-Object { $_.Id -eq $i }).Label
    $qualLabel = $label.ToLower()
    $marker = if ($defaults.quality -eq $qualLabel) { " *" } else { "" }
    $qualLine += "[$i] $label$marker"
    if ($i -lt 5) { $qualLine += "   " }
}
Write-Host "  Quality Preset"
Write-Host "  $qualLine"
Write-Host ""
Write-Host "  --------------------------------------------------"
Write-Host ""

$defaultResId = (Resolve-Resolution -value $defaults.resolution).Id.ToString()
$defaultQualId = (Resolve-Quality -value $defaults.quality).Id.ToString()

do {
    Write-Host -NoNewline "  Resolution FPS Quality (eg: 3 60 2) : "
    $presetInput = Read-Host
    
    if ($presetInput.Trim() -eq "") {
        $defaultFpsValue = if ($defaults.fps -eq "original") { "1" } else { $defaults.fps }
        $presetInput = "$defaultResId $defaultFpsValue $defaultQualId"
    }
    
    $parts = $presetInput.Trim() -split '\s+'
    
    if ($parts.Count -ne 3) {
        Write-Host "  Invalid format. Use: Resolution FPS Quality" -ForegroundColor Yellow
        continue
    }
    
    $resChoice = $parts[0]
    $fpsChoice = $parts[1]
    $qualChoice = $parts[2]
    
    # Resolve resolution: number or string (case-insensitive)
    $selectedResolution = $null
    $resInt = $resChoice -as [int]
    if ($resInt -ne $null) {
        if ($resInt -lt 1 -or $resInt -gt 6) {
            Write-Host "  Invalid resolution. Choose 1-6 or name (original/4k/1440p/1080p/720p/480p)." -ForegroundColor Yellow
            continue
        }
        $selectedResolution = $resolutions | Where-Object { $_.Id -eq $resInt }
    } else {
        $resLower = $resChoice.ToLower()
        $selectedResolution = $resolutions | Where-Object { $_.Label.ToLower() -eq $resLower }
        if (-not $selectedResolution) {
            Write-Host "  Invalid resolution. Choose 1-6 or name (original/4k/1440p/1080p/720p/480p)." -ForegroundColor Yellow
            continue
        }
    }
    
    # Resolve FPS: 1 = original, number = custom
    $customFps = $null
    if ($fpsChoice -eq "1") {
        $selectedFps = "Original"
    } else {
        $fpsInt = $fpsChoice -as [int]
        $fpsDouble = $fpsChoice -as [double]
        if ($fpsInt -ne $null) {
            if ($fpsInt -lt 1) {
                Write-Host "  Invalid FPS. Must be a positive number." -ForegroundColor Yellow
                continue
            }
            $selectedFps = $fpsInt
            $customFps = $fpsInt
        } elseif ($fpsDouble -ne $null) {
            if ($fpsDouble -lt 1) {
                Write-Host "  Invalid FPS. Must be a positive number." -ForegroundColor Yellow
                continue
            }
            $selectedFps = $fpsDouble
            $customFps = $fpsDouble
        } else {
            Write-Host "  Invalid FPS. Enter 1 for Original or a number." -ForegroundColor Yellow
            continue
        }
    }
    
    # Resolve quality: number or string (case-insensitive)
    $selectedQuality = $null
    $qualInt = $qualChoice -as [int]
    if ($qualInt -ne $null) {
        if ($qualInt -lt 1 -or $qualInt -gt 5) {
            Write-Host "  Invalid quality. Choose 1-5 or name (veryfast/fast/balanced/hq/superhq)." -ForegroundColor Yellow
            continue
        }
        $selectedQuality = $qualityPresets | Where-Object { $_.Id -eq $qualInt }
    } else {
        $qualLower = $qualChoice.ToLower()
        $selectedQuality = $qualityPresets | Where-Object { $_.Label.ToLower() -eq $qualLower }
        if (-not $selectedQuality) {
            Write-Host "  Invalid quality. Choose 1-5 or name (veryfast/fast/balanced/hq/superhq)." -ForegroundColor Yellow
            continue
        }
    }
    
    break
} while ($true)

Write-Host ""
Write-Host "  Selected:"
Write-Host "  Resolution -> $($selectedResolution.Id). $($selectedResolution.Label)"
Write-Host "  FPS -> $($selectedFps)"
Write-Host "  Quality -> $($selectedQuality.Id). $($selectedQuality.Label)"
Write-Host ""
}

$hbExtraArgs = @()

if ($selectedResolution.HandBrakeScale) {
    $hbExtraArgs += "--maxHeight", $selectedResolution.HandBrakeScale
}

if ($customFps) {
    $hbExtraArgs += "--rate", $customFps.ToString(), "--pfr"
}

$hbExtraArgs += "-e", "x264", "-q", $selectedQuality.RF.ToString(), "--encoder-preset", $selectedQuality.EncoderPreset

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

$onlyFiles = $inputItems.Count -gt 0 -and (-not $hasFolder)

if ($Mode) {
    $modeLower = $Mode.ToLower()
    $modeChoice = switch ($modeLower) {
        "1" { "1" }
        "replace" { "1" }
        "2" { "2" }
        "cascade" { "2" }
        "3" { "3" }
        "mirror" { "3" }
        Default { "" }
    }
    if ($modeChoice -eq "") {
        Write-Host "  Invalid mode: $Mode" -ForegroundColor Red
        Write-Host "  Valid: 1/replace, 2/cascade, 3/mirror" -ForegroundColor Yellow
        exit
    }
    if ($modeChoice -eq "3" -and (-not $hasFolder)) {
        $modeChoice = "2"
    }
} elseif (-not $doQuick) {
    Write-Host "  Compressed videos should:"
    $defaultModeNum = switch ($defaults.mode.ToLower()) {
        "replace" { "1" }
        "cascade" { "2" }
        "mirror"  { "3" }
        Default   { "2" }
    }
    $effectiveDefault = $defaultModeNum
    if ($defaultModeNum -eq "3" -and -not $hasFolder) {
        $effectiveDefault = "2"
    }
    Write-Host "  1. Replace$(if ($effectiveDefault -eq '1') {'*'}) (Overwrite original)"
    Write-Host "  2. Cascade$(if ($effectiveDefault -eq '2') {'*'}) (Create x_kompressochan.mp4)"
    if ($hasFolder) {
        Write-Host "  3. Mirror$(if ($effectiveDefault -eq '3') {'*'})  (New folder structure for folders)"
    }
    Write-Host ""

    $maxMode = if ($hasFolder) { "3" } else { "2" }

    do {
        Write-Host -NoNewline "  "
        $modeChoiceInput = Read-Host "Enter mode (1-$maxMode)"
        if ($modeChoiceInput -eq "") { 
            $modeChoice = $effectiveDefault
        } else { 
            $modeChoice = $modeChoiceInput 
        }
        
        $validModes = if ($hasFolder) { "1","2","3" } else { "1","2" }
        $validMode = ($validModes -contains $modeChoice)
        if (!$validMode) {
            Write-Host "  Invalid choice. Please enter $(if ($hasFolder) {'1, 2, or 3'} else {'1 or 2'})." -ForegroundColor Yellow
        }
    } while (!$validMode)
}

$modeLabel = switch ($modeChoice) {
    "1" { "1 (Replace - Overwrite original)" }
    "2" { "2 (Cascade - Create x_kompressochan.mp4)" }
    "3" { "3 (Mirror - New folder structure)" }
    Default { "1 (Replace - Overwrite original)" }
}

Write-Host ""
if (-not $doSmart -and ($modeChoice -eq "1" -or $modeChoice -eq "3") -and -not $doQuick) {
    Write-Host -NoNewline "  "
    $smartDefault = if ($defaults.smart) { "[Y/n]" } else { "[y/N]" }
    if ($modeChoice -eq "1") {
        $smartPrompt = Read-Host "Smart mode: skip replacement if compressed is larger? $smartDefault"
    } else {
        $smartPrompt = Read-Host "Smart mode: copy original video if compressed is larger? $smartDefault"
    }
    if ($smartPrompt -eq "") {
        $doSmart = $defaults.smart
    } elseif ($smartPrompt.ToLower() -eq "y") {
        $doSmart = $true
    }
}

Write-Host ""
if (-not $doShutdown -and -not $doQuick) {
    Write-Host -NoNewline "  "
    $shutDefault = if ($defaults.shutdown) { "[Y/n]" } else { "[y/N]" }
    $shutdownPrompt = Read-Host "Shutdown when everything is done? $shutDefault"
    if ($shutdownPrompt -eq "") {
        $doShutdown = $defaults.shutdown
    } else {
        $doShutdown = ($shutdownPrompt.ToLower() -eq "y")
    }
}
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
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File | Where-Object { -not (Test-IsSupportedVideoFile $_) -and $_.Name -notlike "*compression_log*.txt" } | ForEach-Object {
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
    if ($rootObj.PSIsContainer) {
        Write-Host "`n  Scanning: $($rootObj.FullName)" -ForegroundColor Gray
        $found = Get-ChildItem -LiteralPath $rootObj.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            (Test-IsSupportedVideoFile $_) -and -not (Test-IsKompressoOutputArtifact $_.Name)
        }
        foreach ($f in $found) {
            if (!$seenFiles.ContainsKey($f.FullName)) {
                $seenFiles[$f.FullName] = $true
                $tasks += [PSCustomObject]@{ File = $f; InputRoot = $rootObj }
            }
        }
    } else {
        if ((Test-IsSupportedVideoFile $rootObj) -and -not (Test-IsKompressoOutputArtifact $rootObj.Name)) {
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
if ($logMode.Session -and $script:inputListPath) {
    $isSingleOrOneOfEach = ($inputFolderCount -le 1 -and $inputFileCount -le 1 -and ($inputFolderCount + $inputFileCount) -gt 0)
    $shouldCreateSessionLog = -not $isSingleOrOneOfEach
} elseif ($Log -eq "" -and $script:inputListPath) {
    $isSingleOrOneOfEach = ($inputFolderCount -le 1 -and $inputFileCount -le 1 -and ($inputFolderCount + $inputFileCount) -gt 0)
    $shouldCreateSessionLog = -not $isSingleOrOneOfEach
}

if ($shouldCreateSessionLog) {
    $logDirForSession = Split-Path $script:inputListPath -Parent
    
    # Special case: If the input list is the system one, put the session log next to the first actual item
    $systemInputPath = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Kompresso-chan\kompresso_input.txt'
    if ($script:inputListPath -eq $systemInputPath -and $inputItems.Count -gt 0) {
        $logDirForSession = Split-Path $inputItems[0].FullName -Parent
    }

    $sessionLogPath = Join-Path $logDirForSession "session_compression_log_$logTime.txt"
    $allLogPaths += $sessionLogPath

    $presetLabel = "$($selectedResolution.Label) / FPS:$($selectedFps) / $($selectedQuality.Label)"

$settingsHeader = @"
// settings
Chosen Preset  :  $presetLabel
Mode           :  $modeLabel
Start Time     :  $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    $settingsHeader | Out-File -LiteralPath $sessionLogPath -Encoding utf8
}

if ($tasks.Count -eq 0) {
    Write-Host "  No supported video files found." -ForegroundColor Yellow
    if ($sessionLogPath) { "No supported video files found." | Add-Content -LiteralPath $sessionLogPath }
    exit
}

$totalFiles = $tasks.Count
if ($script:inputListPath) {
    $formattedListSummary = @"

// list summary
Folders      : $inputFolderCount
Files        : $inputFileCount
Total Videos : $totalFiles
"@
    Write-Host "`n  List Summary" -ForegroundColor Gray
    Write-Host "    Folders  : $inputFolderCount"
    Write-Host "    Files    : $inputFileCount"
    Write-Host "    Total Videos: $totalFiles`n"
    
    if ($sessionLogPath) { 
        $formattedListSummary | Add-Content -LiteralPath $sessionLogPath 
    }
} else {
    Write-Host "  Total videos found: $totalFiles"
}

if ($sessionLogPath) {
    "`n// timeline" | Add-Content -LiteralPath $sessionLogPath
}

$createFolderLogs = $logMode.Folder
if (-not $logMode.Folder -and -not $logMode.Session -and $Log -eq "") {
    $createFolderLogs = $true
    if ($script:inputListPath -and $inputFolderCount -gt 1) {
        Write-Host -NoNewline "  "
        $logChoice = Read-Host "Create a log file for each folder in the list? [Y/n]"
        $createFolderLogs = ($logChoice -ne "n" -and $logChoice -ne "N")
    }
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
Chosen Preset  :  $presetLabel
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
        
        # Determine Output Path (always .mp4)
        if ($modeChoice -eq "2") {
            $outputFile = Get-CascadeOutputPath $inputFile
        }
        elseif ($modeChoice -eq "3") {
            if ($rootObj.PSIsContainer) {
                $relativePath = $inputFile.Substring($rootObj.FullName.Length).TrimStart("\")
                $mRoot = $mirrorMap[$rootObj.FullName]
                $outputFile = Get-MirrorOutputPath -MirrorRoot $mRoot -RelativePath $relativePath
            } else {
                # File input in Mirror mode acts like Cascade
                $outputFile = Get-CascadeOutputPath $inputFile
            }
        }
        else {
            $outputFile = "$inputFile.tmp.mp4"
        }

        $fileSizeMB     = [Math]::Round($task.File.Length / 1MB, 1)
        $compressPct = switch ($selectedQuality.Id) {
            1 { 45 }
            2 { 35 }
            3 { 25 }
            4 { 10 }
            5 { 5 }
            Default { 35 }
        }
        $estimatedOutMB = [Math]::Round($fileSizeMB * (1 - $compressPct / 100), 1)

        $displayPath = if ($task.InputRoot.PSIsContainer) { $task.File.FullName.Substring($task.InputRoot.FullName.Length).TrimStart("\") } else { $task.File.Name }
        Write-Host "`n  Processing [$currentFile/$totalFiles] : $displayPath" -ForegroundColor Cyan
        Write-Host "  Input size : $fileSizeMB MB   ->   Est. output: ~$estimatedOutMB MB"
        Write-Host "  Encoding..."

        $startTime = Get-Date

        $hbArgs = @(
            "-i", "$inputFile",
            "-o", "$outputFile"
        ) + $hbExtraArgs
        
        & "$handbrake" @hbArgs 2>&1 | ForEach-Object {
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

                $isSmartSkipped = $false

                if ($modeChoice -eq "1" -and $doSmart -and ($outputSize -ge $originalSize)) {
                    Write-Host "  Smart: Compressed file is larger or equal. Skipping replacement." -ForegroundColor Yellow
                    Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
                    $totalOutputBytes += $originalSize
                    $isSmartSkipped = $true
                } elseif ($modeChoice -eq "3" -and $doSmart -and ($outputSize -ge $originalSize)) {
                    Write-Host "  Smart: Compressed file is larger or equal. Copying original instead." -ForegroundColor Yellow
                    Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
                    $smartDest = $outputFile
                    if ($rootObj.PSIsContainer) {
                        $inputExt = $task.File.Extension.ToLower()
                        if ($inputExt -ne '.mp4' -and $inputExt -ne '.m4v') {
                            $smartDest = Join-Path $mirrorMap[$rootObj.FullName] $relativePath
                        }
                    }
                    $smartDestDir = Split-Path -Parent $smartDest
                    if ($smartDestDir -and -not (Test-Path -LiteralPath $smartDestDir)) {
                        New-Item -ItemType Directory -Path $smartDestDir -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $inputFile -Destination $smartDest -Force
                    $totalOutputBytes += $originalSize
                    $isSmartSkipped = $true
                } else {
                    $totalOutputBytes += $outputSize
                }

                if ($modeChoice -eq "1" -and -not $isSmartSkipped) {
                    Remove-Item -LiteralPath $inputFile -Force -ErrorAction Stop
                    $finalName = Get-ReplaceOutputFinalName $inputFile
                    Rename-Item -LiteralPath $outputFile -NewName $finalName -ErrorAction Stop
                }

                $ps.success++
                $ps.origBytes += $originalSize
                if ($isSmartSkipped) {
                    $ps.outBytes += $originalSize
                } else {
                    $ps.outBytes += $outputSize
                }
                $ps.duration += $elapsed
                $ps.endTime   = Get-Date

                $origMB = [Math]::Round($originalSize / 1MB, 2)

                if ($isSmartSkipped) {
                    $status = "Skipped"
                    $sizeInfo = "$origMB MB (unchanged - compressed was larger)"
                } else {
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
                }

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
