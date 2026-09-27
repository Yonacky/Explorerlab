$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Get-Content -Raw -LiteralPath (Join-Path $root 'config\platform.json') | ConvertFrom-Json
$javaBin = Join-Path $config.javaHome 'bin'
$javaExe = Join-Path $javaBin 'java.exe'
$javacExe = Join-Path $javaBin 'javac.exe'
if (-not (Test-Path -LiteralPath $javaExe) -or -not (Test-Path -LiteralPath $javacExe)) {
    throw "JDK not found at $($config.javaHome)"
}
$env:JAVA_HOME = $config.javaHome
if (($env:Path -split ';') -notcontains $javaBin) {
    $env:Path = "$javaBin;$env:Path"
}
Write-Output "JAVA_HOME=$env:JAVA_HOME"
& $javaExe -version
& $javacExe -version
