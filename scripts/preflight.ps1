$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Get-Content -Raw -LiteralPath (Join-Path $root 'config\platform.json') | ConvertFrom-Json
$gameRoot = Join-Path $config.hmclRoot '.minecraft'
$instanceRoot = Join-Path $gameRoot ("versions\" + $config.hmclInstance)
$versionJson = Join-Path $instanceRoot ($config.hmclInstance + '.json')
$apiJar = Join-Path $gameRoot ("mods\fabric-api-" + $config.fabricApiVersion + '.jar')
$isolatedApiJar = Join-Path $instanceRoot ("mods\fabric-api-" + $config.fabricApiVersion + '.jar')
$javaExe = Join-Path $config.javaHome 'bin\java.exe'
$javacExe = Join-Path $config.javaHome 'bin\javac.exe'
$wrapperScript = Join-Path $root 'gradlew.bat'
$wrapperJar = Join-Path $root 'gradle\wrapper\gradle-wrapper.jar'
$wrapperProperties = Join-Path $root 'gradle\wrapper\gradle-wrapper.properties'

function Report($name, $ok, $detail) {
    $state = if ($ok) { 'PASS' } else { 'CHECK' }
    Write-Output "$state $name - $detail"
}

Report 'JDK 17' ((Test-Path -LiteralPath $javaExe) -and (Test-Path -LiteralPath $javacExe)) $config.javaHome
if (Test-Path -LiteralPath $wrapperProperties) {
    $wrapperText = Get-Content -Raw -LiteralPath $wrapperProperties
    $wrapperPinned = ($wrapperText -match 'gradle-9\.5\.1-bin\.zip') -and ($wrapperText -match 'distributionSha256Sum=[a-f0-9]{64}')
    Report 'Gradle Wrapper' ((Test-Path -LiteralPath $wrapperScript) -and (Test-Path -LiteralPath $wrapperJar) -and $wrapperPinned) $wrapperProperties
} else {
    Report 'Gradle Wrapper' $false $wrapperProperties
}
if (Test-Path -LiteralPath $versionJson) {
    $manifest = Get-Content -Raw -LiteralPath $versionJson | ConvertFrom-Json
    $loader = $manifest.libraries | Where-Object { $_.name -eq ("net.fabricmc:fabric-loader:" + $config.fabricLoaderVersion) }
    Report 'Minecraft instance' ($manifest.id -eq $config.hmclInstance) $versionJson
    Report 'Fabric Loader' ($null -ne $loader) $config.fabricLoaderVersion
    Report 'Java target' ($manifest.javaVersion.majorVersion -eq $config.javaMajorVersion) ([string]$manifest.javaVersion.majorVersion)
} else {
    Report 'Minecraft instance' $false $versionJson
}
Report 'Fabric API' ((Test-Path -LiteralPath $apiJar) -or (Test-Path -LiteralPath $isolatedApiJar)) $config.fabricApiVersion
$hmclConfigPath = Join-Path $config.hmclRoot '.hmcl\hmcl.json'
if (Test-Path -LiteralPath $hmclConfigPath) {
    $hmclConfig = Get-Content -Raw -LiteralPath $hmclConfigPath | ConvertFrom-Json
    $directoryType = $hmclConfig.configurations.Default.global.gameDirType
    Report 'Instance isolation setting' ($directoryType -eq 1) "gameDirType=$directoryType (1 means version folder)"
    $javaSetting = $hmclConfig.configurations.Default.global
    $expectedJava = Join-Path $config.javaHome 'bin\java.exe'
    Report 'HMCL game Java' (($javaSetting.javaVersionType -eq 'CUSTOM') -and ($javaSetting.javaDir -eq $expectedJava)) "$($javaSetting.javaVersionType): $($javaSetting.javaDir)"
}
Report 'Isolated Fabric API' (Test-Path -LiteralPath $isolatedApiJar) $isolatedApiJar
$labJar = Join-Path $instanceRoot ("mods\explorerlab-" + $config.minecraftVersion + '-' + $config.fabricLoaderVersion + '-0.1.0.jar')
Report 'ExplorerLab G0 jar' (Test-Path -LiteralPath $labJar) $labJar
$logs = @(Get-ChildItem -LiteralPath (Join-Path $instanceRoot 'logs') -Filter '*.log' -ErrorAction SilentlyContinue)
Report 'Launch log' ($logs.Count -gt 0) 'Launch the instance once to verify runtime loading'
if ($logs.Count -gt 0) {
    $latest = $logs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $loaded = Select-String -LiteralPath $latest.FullName -Pattern 'ExplorerLab G0 loaded' -Quiet
    Report 'ExplorerLab G0 runtime' $loaded $latest.FullName
}
