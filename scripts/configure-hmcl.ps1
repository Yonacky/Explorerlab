param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$platform = Get-Content -Raw -LiteralPath (Join-Path $root 'config\platform.json') | ConvertFrom-Json
$hmclRoot = [System.IO.Path]::GetFullPath($platform.hmclRoot)
$gameRoot = Join-Path $hmclRoot '.minecraft'
$instanceRoot = Join-Path $gameRoot ("versions\" + $platform.hmclInstance)
$settingsPath = Join-Path $hmclRoot '.hmcl\hmcl.json'
$sourceApi = Join-Path $gameRoot ("mods\fabric-api-" + $platform.fabricApiVersion + '.jar')
$targetMods = Join-Path $instanceRoot 'mods'
$targetApi = Join-Path $targetMods ("fabric-api-" + $platform.fabricApiVersion + '.jar')

foreach ($path in @($settingsPath, $instanceRoot, $sourceApi)) {
    $full = [System.IO.Path]::GetFullPath($path)
    if (-not $full.StartsWith($hmclRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unexpected path outside HMCL root: $full"
    }
    if (-not (Test-Path -LiteralPath $full)) { throw "Missing: $full" }
}
if (Test-Path -LiteralPath $targetApi) { throw "Already present: $targetApi" }

$settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
if ($settings.configurations.Default.gameDir -ne '.minecraft') {
    throw 'HMCL default game directory differs from inspected path.'
}
if ($settings.configurations.Default.selectedMinecraftVersion -ne $platform.hmclInstance) {
    throw 'HMCL selected instance changed; inspect before applying.'
}
Write-Output "HMCL config: $settingsPath"
Write-Output "Set Default and Home gameDirType to 1 (version folder isolation)."
Write-Output "Move Fabric API: $sourceApi -> $targetApi"
if (-not $Apply) { Write-Output 'Dry run only. Pass -Apply after exiting HMCL.'; return }

$backup = "$settingsPath.explorer-backup"
if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
Copy-Item -LiteralPath $settingsPath -Destination $backup
$settings.configurations.Default.global.gameDirType = 1
$settings.configurations.Home.global.gameDirType = 1
$json = $settings | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $settingsPath -Value $json -Encoding utf8
New-Item -ItemType Directory -Path $targetMods -Force | Out-Null
Move-Item -LiteralPath $sourceApi -Destination $targetApi
Write-Output "Updated HMCL settings; backup: $backup"
