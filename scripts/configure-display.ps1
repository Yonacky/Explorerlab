param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$platform = Get-Content -Raw -LiteralPath (Join-Path $root 'config\platform.json') | ConvertFrom-Json
$hmclRoot = [System.IO.Path]::GetFullPath($platform.hmclRoot)
$settingsPath = Join-Path $hmclRoot '.hmcl\hmcl.json'
$optionsPath = Join-Path $hmclRoot (".minecraft\versions\" + $platform.hmclInstance + '\options.txt')
foreach ($path in @($settingsPath, $optionsPath)) {
    $full = [System.IO.Path]::GetFullPath($path)
    if (-not $full.StartsWith($hmclRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unexpected path: $full"
    }
    if (-not (Test-Path -LiteralPath $full)) { throw "Missing: $full" }
}
$settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
if ($settings.configurations.Default.selectedMinecraftVersion -ne $platform.hmclInstance) {
    throw 'HMCL selected instance changed.'
}
$wanted = [ordered]@{
    guiScale = [string]$platform.display.guiScale
    fov = [string]$platform.display.fovOption
    renderDistance = [string]$platform.display.renderDistance
}
$lines = @(Get-Content -LiteralPath $optionsPath)
foreach ($key in $wanted.Keys) {
    if (@($lines | Where-Object { $_ -match "^${key}:" }).Count -ne 1) { throw "Expected exactly one options entry: $key" }
}
Write-Output "HMCL window: $($platform.display.width)x$($platform.display.height)"
foreach ($key in $wanted.Keys) { Write-Output "Minecraft option: $key=$($wanted[$key])" }
if (-not $Apply) { Write-Output 'Dry run only. Pass -Apply while HMCL and Minecraft are closed.'; return }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.explorer-display-$stamp.bak"
Copy-Item -LiteralPath $optionsPath -Destination "$optionsPath.explorer-display-$stamp.bak"
$settings.configurations.Default.global.width = [int]$platform.display.width
$settings.configurations.Default.global.height = [int]$platform.display.height
$settings.configurations.Home.global.width = [int]$platform.display.width
$settings.configurations.Home.global.height = [int]$platform.display.height
$settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding utf8
foreach ($key in $wanted.Keys) {
    $lines = @($lines | ForEach-Object { if ($_ -match "^${key}:") { "${key}:$($wanted[$key])" } else { $_ } })
}
Set-Content -LiteralPath $optionsPath -Value $lines -Encoding utf8
Write-Output 'Display settings updated.'
