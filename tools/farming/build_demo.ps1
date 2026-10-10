param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { throw 'Supply -GodotExe or set GODOT_EXE_CONSOLE to the Godot console executable.' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw "Godot not found: $GodotExe" }
$outputDir = Join-Path $projectRoot 'dist/lingtian-demo'
$logDir = Join-Path $projectRoot '.art-work'
New-Item -ItemType Directory -Force -Path $outputDir, $logDir | Out-Null
$exePath = Join-Path $outputDir 'LingTianDemo.exe'
$exportLog = Join-Path $logDir 'phase06-export.log'
& $GodotExe --headless --path $projectRoot --export-release 'Windows Demo' $exePath *> $exportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {
    throw "Export failed; see $exportLog"
}
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw 'Export produced no executable.' }
# GUI release executables must be explicitly waited for, and their own marker checked.
$smokeLog = Join-Path $logDir 'phase06-release-smoke.log'
$probe = Start-Process -FilePath $exePath -WindowStyle Hidden -Wait -PassThru -ArgumentList @('--headless','--log-file',('"'+$smokeLog+'"'),'--','--demo-smoke')
$smokeText = Get-Content -LiteralPath $smokeLog -Raw -Encoding UTF8
if ($probe.ExitCode -ne 0 -or $smokeText -notmatch 'DEMO RELEASE SMOKE OK' -or $smokeText -match 'SCRIPT ERROR:|ERROR:|\[fail\]') {
    throw "Release smoke failed (exit $($probe.ExitCode)); see $smokeLog"
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/farming/demo-操作说明.md') -Destination (Join-Path $outputDir 'README.md') -Force
$files = @('LingTianDemo.exe','README.md')
$manifest = [ordered]@{ platform = 'Windows x64'; files = @($files | ForEach-Object {
    $filePath = Join-Path $outputDir $_
    [ordered]@{ name = $_; bytes = (Get-Item -LiteralPath $filePath).Length; sha256 = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant() }
}); release_smoke = 'passed' }
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputDir 'manifest.json') -Encoding UTF8
$zipPath = Join-Path $projectRoot 'dist/LingTianDemo-Windows-x64.zip'
$packageFiles = @($files + 'manifest.json' | ForEach-Object { Join-Path $outputDir $_ })
Compress-Archive -LiteralPath $packageFiles -DestinationPath $zipPath -Force
Write-Output "WINDOWS DEMO BUILD OK: $zipPath"
