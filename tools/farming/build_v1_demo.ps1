param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe -or -not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
# Copy a small isolated project. The working project's V0 default/export preset is never edited.
$stageRoot = Join-Path $projectRoot ('.art-work/v1-release-' + [Guid]::NewGuid().ToString('N'))
$outputDir = Join-Path $projectRoot 'dist/lingtian-v1-demo'
$logDir = Join-Path $projectRoot '.art-work'
New-Item -ItemType Directory -Force -Path $stageRoot,$outputDir,$logDir | Out-Null
function Copy-ReleaseFile([string]$relative) {
    $target = Join-Path $stageRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $target
}
foreach ($directory in @('scripts/farming/v1','scripts/farming/core','assets/farming/ground','assets/farming/transitions')) {
    $prefix = Join-Path $projectRoot $directory
    Get-ChildItem -LiteralPath $prefix -Recurse -File | Where-Object { $_.Extension -in @('.gd','.uid','.png') } | ForEach-Object {
        Copy-ReleaseFile ($_.FullName.Substring($projectRoot.Length+1))
    }
}
foreach ($relative in @('scenes/farming/farm_v1.tscn','scripts/farming/rendering/terrain_renderer.gd','scripts/farming/rendering/farm_ui_style.gd',
    'scripts/farming/validation/v1_release_smoke.gd','content/farming/baked/v1/production.json','content/farming/baked/terrains.json','content/farming/baked/maps/farm_01.json')) {
    Copy-ReleaseFile $relative
}
$configuration = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')).Replace('run/main_scene="res://scenes/farming/farm_demo.tscn"','run/main_scene="res://scenes/farming/farm_v1.tscn"')
if ($configuration -notmatch 'run/main_scene="res://scenes/farming/farm_v1.tscn"') { throw 'Unexpected project main scene; staging aborted.' }
[IO.File]::WriteAllText((Join-Path $stageRoot 'project.godot'),$configuration,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'export_v1.cfg') -Destination (Join-Path $stageRoot 'export_presets.cfg')
$importLog = Join-Path $logDir 'v1-f-release-import.log'
& $GodotExe --headless --path $stageRoot --editor --import *> $importLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw "Staging import failed: $importLog" }
$exePath = Join-Path $outputDir 'LingTianDemoV1.exe'
$exportLog = Join-Path $logDir 'v1-f-export.log'
& $GodotExe --headless --path $stageRoot --export-release 'Windows V1 Demo' $exePath *> $exportLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw "V1 export failed: $exportLog" }
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw 'No V1 executable produced.' }
$smokeLog = Join-Path $logDir 'v1-f-release-smoke.log'
$probe = Start-Process -FilePath $exePath -WindowStyle Hidden -PassThru -ArgumentList @('--headless','--log-file',('"'+$smokeLog+'"'),'--','--v1-smoke')
if (-not $probe.WaitForExit(60000)) { $probe.Kill(); throw "V1 release smoke timed out: $smokeLog" }
$smokeText = Get-Content -LiteralPath $smokeLog -Raw -Encoding UTF8
if ($probe.ExitCode -ne 0 -or $smokeText -notmatch 'V1 RELEASE SMOKE OK' -or $smokeText -match 'SCRIPT ERROR:|ERROR:') { throw "V1 release smoke failed: $smokeLog" }
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/farming/demo-v1-操作说明.md') -Destination (Join-Path $outputDir 'README.md') -Force
$files = @('LingTianDemoV1.exe','README.md')
$manifest = [ordered]@{ product='LingTian Demo V1'; art='placeholder'; release_smoke='passed'; files=@($files | ForEach-Object {
    $path = Join-Path $outputDir $_
    [ordered]@{ name=$_; bytes=(Get-Item -LiteralPath $path).Length; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
}) }
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputDir 'manifest.json') -Encoding UTF8
$zipPath = Join-Path $projectRoot 'dist/LingTianDemoV1-Windows-x64.zip'
$packageFiles = @($files+'manifest.json' | ForEach-Object { Join-Path $outputDir $_ })
Compress-Archive -LiteralPath $packageFiles -DestinationPath $zipPath -Force
Write-Output "WINDOWS V1 DEMO BUILD OK: $zipPath"
