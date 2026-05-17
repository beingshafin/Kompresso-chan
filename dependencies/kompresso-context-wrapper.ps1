param(
    [Parameter(Mandatory=$true)]
    [string]$TargetPath
)

# Resolve the Kompresso-chan executable next to this wrapper.
$scriptDir = Split-Path -Parent $PSCommandPath
$kompressoExe = Join-Path $scriptDir 'komchan.exe'
$f = Join-Path ([Environment]::GetEnvironmentVariable('TEMP')) 'kompresso_input.txt'

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
        Start-Process -FilePath $kompressoExe -ArgumentList @($f)
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
