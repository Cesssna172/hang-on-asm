param([string]$Destination = '')
$ErrorActionPreference = 'Stop'
if (-not $Destination) { $Destination = Join-Path (Split-Path $PSScriptRoot -Parent) 'hang-on-asm.zip' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'bin\hangon.exe'))) {
    & (Join-Path $PSScriptRoot 'build.ps1')
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$files = @('README.md', 'LICENSE', '.gitignore', 'build.ps1', 'run.bat', 'test.ps1', 'package.ps1')
foreach ($folder in @('src', 'bin', 'tests', 'docs', 'assets', 'tools')) {
    $path = Join-Path $PSScriptRoot $folder
    if (Test-Path -LiteralPath $path) {
        foreach ($file in Get-ChildItem -LiteralPath $path -Recurse -File) {
            if ($file.FullName -notmatch '__pycache__') {
                $files += $file.FullName.Substring($PSScriptRoot.Length + 1)
            }
        }
    }
}
$stream = [IO.File]::Open($Destination, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
try {
    foreach ($relative in $files) {
        $entry = 'hang-on-asm/' + $relative.Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, (Join-Path $PSScriptRoot $relative), $entry,
            [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }
Write-Host "Packaged $Destination"
