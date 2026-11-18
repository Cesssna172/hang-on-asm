param([string]$Compiler = '')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (-not $Compiler) {
        $found = Get-Command gcc.exe -ErrorAction SilentlyContinue
        if ($found) { $Compiler = $found.Source }
        elseif (Test-Path -LiteralPath 'C:\msys64\mingw64\bin\gcc.exe') {
            $Compiler = 'C:\msys64\mingw64\bin\gcc.exe'
        } else { throw 'Install MSYS2 MinGW-w64 GCC or pass -Compiler with its full path.' }
    }
    New-Item -ItemType Directory -Path build, bin -Force | Out-Null
    & $Compiler -c -x assembler src/main.s -o build/hangon.o '-Wa,--fatal-warnings'
    if ($LASTEXITCODE -ne 0) { throw 'Assembly failed.' }
    & $Compiler -nostdlib '-Wl,--entry=start' '-Wl,--subsystem,windows' `
        '-Wl,--dynamicbase' '-Wl,--nxcompat' '-Wl,--no-insert-timestamp' `
        build/hangon.o -luser32 -lgdi32 -lkernel32 -lwinmm -o bin/hangon.exe
    if ($LASTEXITCODE -ne 0) { throw 'Linking failed.' }
    Write-Host "Built $PSScriptRoot\bin\hangon.exe"
} finally { Pop-Location }
