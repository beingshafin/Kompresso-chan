param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath,
    [switch]$Quick,
    [string]$Mode
)

# Resolve the Kompresso-chan executable next to this wrapper.
$scriptDir = Split-Path -Parent $PSCommandPath
$kompressoExe = Join-Path $scriptDir 'komchan.exe'
$configDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Kompresso-chan'
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}
$f = Join-Path $configDir 'kompresso_input.txt'

# Build arguments for komchan.exe
$exeArgs = @($f)
if ($Quick) {
    $exeArgs += '--quick'
    if ($Mode) {
        $exeArgs += '-m', $Mode
    }
}

# Write the path atomically using a mutex to avoid race conditions.
$m = New-Object Threading.Mutex($false, 'KC_W')
try {
    $m.WaitOne() | Out-Null
    if ((Test-Path $f) -and ((Get-Date) - (Get-Item $f).LastWriteTime).TotalSeconds -gt 5) {
        [IO.File]::WriteAllText($f, $TargetPath + [Environment]::NewLine)
    } else {
        [IO.File]::AppendAllText($f, $TargetPath + [Environment]::NewLine)
    }
} finally {
    try {
        $m.ReleaseMutex() | Out-Null
    } catch {
        # Ignore release failures.
    }
}

$m2 = New-Object Threading.Mutex($false, 'KC_R')
if ($m2.WaitOne(0)) {
    try {
        Start-Process -FilePath $kompressoExe -ArgumentList $exeArgs
        # Hold the lock for 2 seconds to prevent other concurrent wrappers from launching kompresso-chan again.
        Start-Sleep -Milliseconds 2000
    } finally {
        try {
            $m2.ReleaseMutex() | Out-Null
        } catch {
            # Ignore release failures.
        }
    }
}
