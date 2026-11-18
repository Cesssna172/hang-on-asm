$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'bin\hangon.exe'
if (-not (Test-Path -LiteralPath $exe)) { & "$PSScriptRoot\build.ps1" }
$process = Start-Process -FilePath $exe -ArgumentList '--self-test' -PassThru
if (-not $process.WaitForExit(15000)) {
    $process.Kill()
    throw 'Self-test exceeded 15 seconds.'
}
if ($process.ExitCode -ne 0) { throw "Assembly self-test failed, exit code $($process.ExitCode)." }
Write-Host 'PASS: countdown, acceleration, steering, braking, pause, checkpoints, finish, timeout, off-road, traffic collision, full five-stage race.'
