param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$stageRoot = Join-Path $projectRoot ('.art-work/v2-release-' + [Guid]::NewGuid().ToString('N'))
$outputDir = Join-Path $projectRoot 'dist/lingtian-v2-demo'
$logDir = Join-Path $projectRoot '.art-work'
New-Item -ItemType Directory -Force -Path $stageRoot,$outputDir,$logDir | Out-Null
$sourceFiles = [Collections.Generic.List[object]]::new()
function Copy-ReleaseFile([string]$relative) {
    $source = Join-Path $projectRoot $relative
    $target = Join-Path $stageRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
    $sourceFiles.Add([ordered]@{name=$relative.Replace('\','/'); sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()})
}
foreach ($directory in @('scripts/farming/v2','scripts/farming/v1','scripts/farming/core','assets/farming/ground','assets/farming/transitions','assets/farming/ui')) {
    Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -Recurse -File | Where-Object { $_.Extension -in @('.gd','.uid','.png','.svg','.json') } | ForEach-Object {
        Copy-ReleaseFile ($_.FullName.Substring($projectRoot.Length+1))
    }
}
foreach ($relative in @('scenes/farming/farm_v2.tscn','scripts/farming/rendering/terrain_renderer.gd','scripts/farming/rendering/farm_ui_style.gd',
    'scripts/farming/validation/v2_release_smoke.gd','scripts/farming/validation/v2_playthrough.gd',
    'content/farming/baked/v2/production.json','content/farming/baked/v2/terrains.json','content/farming/baked/terrains.json','content/farming/baked/maps/farm_02.json')) { Copy-ReleaseFile $relative }
$configuration = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')) -replace 'run/main_scene="[^"]+"','run/main_scene="res://scenes/farming/farm_v2.tscn"'
[IO.File]::WriteAllText((Join-Path $stageRoot 'project.godot'),$configuration,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'export_v2.cfg') -Destination (Join-Path $stageRoot 'export_presets.cfg')
function Invoke-Engine([string]$name,[string[]]$arguments) {
    $log = Join-Path $logDir ($name+'.log')
    & $GodotExe --headless --path $stageRoot @arguments *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw "Build failed: $log" }
}
Invoke-Engine 'v2-release-import' @('--editor','--import')
$exePath = Join-Path $outputDir 'LingTianDemoV2.exe'
Invoke-Engine 'v2-export' @('--export-release','Windows V2 Demo',$exePath)
function Invoke-ReleaseSmoke([string]$executable,[string]$name) {
    $log = Join-Path $logDir ($name+'.log')
    $probe = Start-Process -FilePath $executable -WindowStyle Hidden -PassThru -ArgumentList @('--headless','--log-file',('"'+$log+'"'),'--','--v2-smoke')
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    while (-not $probe.WaitForExit(10000)) {
        if ([DateTime]::UtcNow -gt $deadline) { $probe.Kill(); throw "Release smoke timed out: $log" }
    }
    $smoke = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    if ($probe.ExitCode -ne 0 -or $smoke -notmatch 'V2 RELEASE SMOKE OK' -or $smoke -match 'SCRIPT ERROR:|ERROR:') { throw "Release smoke failed: $log" }
    Write-Output "V2 RELEASE SMOKE PASSED: $name"
}
Invoke-ReleaseSmoke $exePath 'v2-release-smoke'
$readme = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs/farming') -File -Filter 'demo-v2-*.md' | Select-Object -First 1
if (-not $readme) { throw 'V2 player instructions missing.' }
Copy-Item -LiteralPath $readme.FullName -Destination (Join-Path $outputDir 'README.md') -Force
$revision = (& git -C $projectRoot rev-parse HEAD).Trim()
$dirty = [bool](& git -C $projectRoot status --porcelain)
$files = @('LingTianDemoV2.exe','README.md')
$manifest = [ordered]@{ product='LingTian Demo V2'; phase='7.f'; source_revision=$revision; source_dirty=$dirty; schema=11;
    art='world-placeholder; existing terrain and vector UI'; release_smoke='passed'; embedded_pck=$true;
    source_files=@($sourceFiles); files=@($files | ForEach-Object {
        $path = Join-Path $outputDir $_
        [ordered]@{name=$_;bytes=(Get-Item -LiteralPath $path).Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
    }) }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outputDir 'manifest.json') -Encoding UTF8
$zipPath = Join-Path $projectRoot 'dist/LingTianDemoV2-Windows-x64.zip'
Compress-Archive -LiteralPath @($files+'manifest.json' | ForEach-Object { Join-Path $outputDir $_ }) -DestinationPath $zipPath -Force
$unpack = Join-Path $projectRoot ('.art-work/v2-unpack-'+[Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $zipPath -DestinationPath $unpack
foreach ($entry in $manifest.files) {
    $file = Join-Path $unpack $entry.name
    if ((Get-Item -LiteralPath $file).Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "Unpacked checksum mismatch: $file" }
}
Invoke-ReleaseSmoke (Join-Path $unpack 'LingTianDemoV2.exe') 'v2-unpacked-smoke'
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($zipPath+'.sha256'),($hash+'  LingTianDemoV2-Windows-x64.zip'+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
Write-Output "WINDOWS V2 DEMO BUILD OK: $zipPath SHA256=$hash"
