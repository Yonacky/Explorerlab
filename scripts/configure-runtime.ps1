param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$platform = Get-Content -Raw -LiteralPath (Join-Path $root 'config\platform.json') | ConvertFrom-Json
$hmclRoot = [System.IO.Path]::GetFullPath($platform.hmclRoot)
$settingsPath = Join-Path $hmclRoot '.hmcl\hmcl.json'
$javaExe = Join-Path $platform.javaHome 'bin\java.exe'
if (-not (Test-Path -LiteralPath $settingsPath)) { throw "Missing HMCL settings: $settingsPath" }
if (-not (Test-Path -LiteralPath $javaExe)) { throw "Missing JDK 17: $javaExe" }
$settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
if ($settings.configurations.Default.selectedMinecraftVersion -ne $platform.hmclInstance) {
    throw 'HMCL selected instance changed.'
}
Write-Output "Pin HMCL Java to $javaExe"
if (-not $Apply) { Write-Output 'Dry run only. Pass -Apply while HMCL is closed.'; return }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.explorer-java-$stamp.bak"
$settings.configurations.Default.global.javaVersionType = 'CUSTOM'
$settings.configurations.Default.global.javaDir = $javaExe
$settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding utf8
Write-Output 'HMCL Java runtime pinned.'
