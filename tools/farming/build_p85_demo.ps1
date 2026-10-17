param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$stageRoot = Join-Path $projectRoot ('.art-work/p85-release-' + [Guid]::NewGuid().ToString('N'))
$outputDir = Join-Path $projectRoot 'dist/lingtian-p85-demo'
$logDir = Join-Path $projectRoot '.art-work/p85-release-logs'
New-Item -ItemType Directory -Force -Path $stageRoot,$outputDir,$logDir | Out-Null
function Copy-ReleaseFile([string]$relative) {
    $target = Join-Path $stageRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $target
}
foreach ($directory in @('scripts/farming/p8','scripts/farming/v2','scripts/farming/v1','scripts/farming/core',
    'assets/farming/ground','assets/farming/transitions','assets/farming/ui','assets/farming/shaders','content/farming/baked/p8')) {
    Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -Recurse -File |
        Where-Object { $_.Extension -in @('.gd','.uid','.png','.svg','.json','.gdshader') } | ForEach-Object {
            Copy-ReleaseFile ($_.FullName.Substring($projectRoot.Length+1))
        }
}
foreach ($relative in @('scenes/farming/farm_p8.tscn','scripts/farming/rendering/terrain_renderer.gd',
    'scripts/farming/rendering/farm_ui_style.gd','scripts/farming/validation/p85_release_smoke.gd',
    'scripts/farming/validation/p8_release_smoke.gd','content/farming/baked/terrains.json',
    'content/farming/baked/maps/farm_02.json','content/farming/p8/world_visuals.json','project.godot')) { Copy-ReleaseFile $relative }
& python (Join-Path $PSScriptRoot 'stage_p85_png_data.py') --stage $stageRoot
if ($LASTEXITCODE -ne 0) { throw 'P8.5 raw PNG staging failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'export_p8.cfg') -Destination (Join-Path $stageRoot 'export_presets.cfg')
function Invoke-Engine([string]$name,[string[]]$arguments) {
    $log = Join-Path $logDir ($name+'.log')
    & $GodotExe --headless --path $stageRoot @arguments *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw "Build failed: $log" }
}
Invoke-Engine 'import' @('--editor','--import','--quit')
$exePath = Join-Path $outputDir 'LingTianDemoP85.exe'
Invoke-Engine 'export' @('--export-release','Windows P8 Demo',$exePath)
function Invoke-Probe([string]$executable,[string]$name,[string]$workingDirectory,[switch]$Render) {
    $log = Join-Path $logDir ($name+'.log')
    $arguments = @('--headless','--log-file',('"'+$log+'"'),'--','--p85-smoke')
    if ($Render) { $arguments = @('--resolution','1920x1080','--log-file',('"'+$log+'"'),'--','--p85-smoke',('--p85-render-probe="'+(Join-Path $logDir 'packaged-render.png')+'"')) }
    $probe = Start-Process -FilePath $executable -WorkingDirectory $workingDirectory -WindowStyle Hidden -PassThru -ArgumentList $arguments
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    while (-not $probe.WaitForExit(10000)) {
        if ([DateTime]::UtcNow -gt $deadline) { $probe.Kill(); throw "Probe timed out: $log" }
    }
    $content = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    if ($probe.ExitCode -ne 0 -or $content -notmatch 'P85 RELEASE SMOKE OK' -or $content -match 'SCRIPT ERROR:|ERROR:') { throw "Probe failed: $log" }
    Write-Output "P85 PACKAGED PROBE OK: $name"
}
Invoke-Probe $exePath 'standalone' $outputDir
$utf8 = [Text.UTF8Encoding]::new($false)
$readme = @'
LingTian Demo P8.5 - Windows x64

Run LingTianDemoP85.exe. No Blender, source repository or external PNG folder is required.
World art: seven plants with four growth stages and flowering; fifteen facility bodies.
WASD or middle mouse drag pans the map; mouse wheel zooms; right click returns to inspect.
P8 gameplay and schema17 slots are retained. This program uses the existing P8 slot namespace.
Source saves from schema16 must be started fresh; P8.5 does not introduce another schema migration.

Facility foundations/effects and resource-point models are deferred. Low zoom is for overview.
The user visual acceptance gate remains separate from automated package validation.
'@
[IO.File]::WriteAllText((Join-Path $outputDir 'README.txt'),$readme,$utf8)
$playerGuide = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs/farming') -File -Filter 'demo-p85-*.md' | Select-Object -First 1
if (-not $playerGuide) { throw 'P8.5 player guide missing.' }
Copy-Item -LiteralPath $playerGuide.FullName -Destination (Join-Path $outputDir 'README.md') -Force
$revision = (& git -C $projectRoot rev-parse HEAD).Trim()
$dirty = [bool](& git -C $projectRoot status --porcelain)
$payload = @('LingTianDemoP85.exe','README.txt','README.md')
$manifest = [ordered]@{product='LingTian Demo P8.5';schema=17;source_revision=$revision;source_dirty=$dirty;
    embedded_pck=$true;raw_png_count=44;release_smoke='passed';stage_path=$stageRoot;
    source_files=@(Get-ChildItem -LiteralPath $stageRoot -Recurse -File | Where-Object { $_.FullName -notlike ($stageRoot+'\.godot\*') } | ForEach-Object {
        [ordered]@{name=$_.FullName.Substring($stageRoot.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    });files=@($payload | ForEach-Object {
        $file = Join-Path $outputDir $_
        [ordered]@{name=$_;bytes=(Get-Item -LiteralPath $file).Length;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
    })}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputDir 'manifest.json') -Encoding UTF8
$zip = Join-Path $projectRoot 'dist/LingTianDemoP85-Windows-x64.zip'
Compress-Archive -LiteralPath @($payload+'manifest.json' | ForEach-Object { Join-Path $outputDir $_ }) -DestinationPath $zip -Force
$unpack = Join-Path $projectRoot ('.art-work/p85-unpack-'+[Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $zip -DestinationPath $unpack
foreach ($entry in $manifest.files) {
    $file = Join-Path $unpack $entry.name
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "Unpack checksum failed: $file" }
}
Invoke-Probe (Join-Path $unpack 'LingTianDemoP85.exe') 'unpacked' $unpack
Invoke-Probe (Join-Path $unpack 'LingTianDemoP85.exe') 'unpacked-gpu' $unpack -Render
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($zip+'.sha256'),($hash+'  LingTianDemoP85-Windows-x64.zip'+[Environment]::NewLine),$utf8)
Write-Output "WINDOWS P85 BUILD OK: $zip SHA256=$hash"
