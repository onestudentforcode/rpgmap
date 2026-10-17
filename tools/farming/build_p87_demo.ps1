param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$stageRoot = Join-Path $projectRoot ('.art-work/p87-release-' + [Guid]::NewGuid().ToString('N'))
$outputDir = Join-Path $projectRoot 'dist/lingtian-p87-demo'
$logDir = Join-Path $projectRoot '.art-work/p87-release-logs'
New-Item -ItemType Directory -Force -Path $stageRoot,$outputDir,$logDir | Out-Null
function Copy-ReleaseFile([string]$relative) {
    $target = Join-Path $stageRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $target
}
foreach ($directory in @('scripts/farming/p8','scripts/farming/v2','scripts/farming/v1','scripts/farming/core',
    'assets/farming/p86','content/farming/p8','assets/farming/ground','assets/farming/transitions','assets/farming/ui','assets/farming/shaders','content/farming/baked/p8')) {
    Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -Recurse -File |
        Where-Object { $_.Extension -in @('.gd','.uid','.png','.svg','.json','.gdshader') } | ForEach-Object {
            Copy-ReleaseFile ($_.FullName.Substring($projectRoot.Length+1))
        }
}
foreach ($relative in @('scenes/farming/farm_p8.tscn','scripts/farming/rendering/terrain_renderer.gd',
    'scripts/farming/rendering/farm_ui_style.gd','scripts/farming/validation/p87_release_smoke.gd',
    'scripts/farming/validation/p86_release_smoke.gd',
    'scripts/farming/validation/p8_release_smoke.gd','content/farming/baked/terrains.json',
    'content/farming/baked/maps/farm_02.json','content/farming/p8/world_visuals.json','project.godot')) { Copy-ReleaseFile $relative }
Copy-Item -LiteralPath (Join-Path $projectRoot 'scenes/farming/farm_p87.tscn') -Destination (Join-Path $stageRoot 'scenes/farming/farm_p8.tscn') -Force
& python (Join-Path $PSScriptRoot 'stage_p85_png_data.py') --stage $stageRoot
if ($LASTEXITCODE -ne 0) { throw 'P8.7 raw PNG staging failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'export_p87.cfg') -Destination (Join-Path $stageRoot 'export_presets.cfg')
function Invoke-Engine([string]$name,[string[]]$arguments) {
    $log = Join-Path $logDir ($name+'.log')
    & $GodotExe --headless --path $stageRoot @arguments *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw "Build failed: $log" }
}
Invoke-Engine 'import' @('--editor','--import','--quit')
$exePath = Join-Path $outputDir 'LingTianDemoP87.exe'
Invoke-Engine 'export' @('--export-release','Windows P8 Demo',$exePath)
function Invoke-Probe([string]$executable,[string]$name,[string]$workingDirectory,[switch]$Render) {
    $log = Join-Path $logDir ($name+'.log')
    $arguments = @('--headless','--log-file',('"'+$log+'"'),'--','--p87-smoke')
    if ($Render) { $arguments = @('--resolution','1920x1080','--log-file',('"'+$log+'"'),'--','--p87-smoke','--shot-size=1920x1080',('--p87-render-probe="'+(Join-Path $logDir 'packaged-render.png')+'"')) }
    $probe = Start-Process -FilePath $executable -WorkingDirectory $workingDirectory -WindowStyle Hidden -PassThru -ArgumentList $arguments
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    while (-not $probe.WaitForExit(10000)) {
        if ([DateTime]::UtcNow -gt $deadline) { $probe.Kill(); throw "Probe timed out: $log" }
    }
    $content = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    if ($probe.ExitCode -ne 0 -or $content -notmatch 'P87 RELEASE SMOKE OK' -or $content -match 'SCRIPT ERROR:|ERROR:') { throw "Probe failed: $log" }
    Write-Output "P87 PACKAGED PROBE OK: $name"
}
Invoke-Probe $exePath 'standalone' $outputDir
$utf8 = [Text.UTF8Encoding]::new($false)
$readme = @'
LingTian Demo P8.7 - Windows x64

Run LingTianDemoP87.exe. No Blender, source repository or external PNG folder is required.
World art: seven plants with four growth stages and flowering; fifteen facility bodies.
WASD or middle mouse drag pans the map; mouse wheel zooms; right click returns to inspect.
P8 gameplay and schema17 slots are retained. This program uses the existing P8 slot namespace.
Source saves from schema16 must be started fresh; P8.7 does not introduce another schema migration.

The 35-degree ground projection matches body sprites. Logical 64-unit tiles and schema17 are unchanged.
Contact shadows, seven-family seedlings, smooth terrain/water shores and three resource scenery models are included. Facility foundations/effects remain deferred. Low zoom is for overview.
The user visual acceptance gate remains separate from automated package validation.
'@
[IO.File]::WriteAllText((Join-Path $outputDir 'README.txt'),$readme,$utf8)
$playerGuide = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs/farming') -File -Filter 'demo-p87-*.md' | Select-Object -First 1
if (-not $playerGuide) { throw 'P8.7 player guide missing.' }
Copy-Item -LiteralPath $playerGuide.FullName -Destination (Join-Path $outputDir 'README.md') -Force
$revision = "workspace-snapshot"
$dirty = $true
if (Test-Path -LiteralPath (Join-Path $projectRoot ".git")) {
    $revision = (& git -C $projectRoot rev-parse HEAD).Trim()
    $dirty = [bool](& git -C $projectRoot status --porcelain)
}
$payload = @('LingTianDemoP87.exe','README.txt','README.md')
$manifest = [ordered]@{product='LingTian Demo P8.7';schema=17;source_revision=$revision;source_dirty=$dirty;entry_scene_source='scenes/farming/farm_p87.tscn';entry_scene_alias='scenes/farming/farm_p8.tscn';
    embedded_pck=$true;raw_png_count=((Get-Content -LiteralPath (Join-Path $stageRoot 'png-data-count.json') -Raw | ConvertFrom-Json).raw_png_count);release_smoke='passed';stage_path=$stageRoot;
    source_files=@(Get-ChildItem -LiteralPath $stageRoot -Recurse -File | Where-Object { $_.FullName -notlike ($stageRoot+'\.godot\*') } | ForEach-Object {
        [ordered]@{name=$_.FullName.Substring($stageRoot.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    });files=@($payload | ForEach-Object {
        $file = Join-Path $outputDir $_
        [ordered]@{name=$_;bytes=(Get-Item -LiteralPath $file).Length;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
    })}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputDir 'manifest.json') -Encoding UTF8
$zip = Join-Path $projectRoot 'dist/LingTianDemoP87-Windows-x64.zip'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$zipStream = [IO.File]::Open($zip,[IO.FileMode]::Create,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$archive = [IO.Compression.ZipArchive]::new($zipStream,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in @($payload+'manifest.json')) {
        # The archive cmdlet requests exclusive access to freshly executed EXEs.
        # The framework reader shares reads with Windows' post-execution scanners.
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $outputDir $name),$name,[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose(); $zipStream.Dispose() }
$unpack = Join-Path $projectRoot ('.art-work/p87-unpack-'+[Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $zip -DestinationPath $unpack
foreach ($entry in $manifest.files) {
    $file = Join-Path $unpack $entry.name
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "Unpack checksum failed: $file" }
}
Invoke-Probe (Join-Path $unpack 'LingTianDemoP87.exe') 'unpacked' $unpack
Invoke-Probe (Join-Path $unpack 'LingTianDemoP87.exe') 'unpacked-gpu' $unpack -Render
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($zip+'.sha256'),($hash+'  LingTianDemoP87-Windows-x64.zip'+[Environment]::NewLine),$utf8)
Write-Output "WINDOWS P87 BUILD OK: $zip SHA256=$hash"
