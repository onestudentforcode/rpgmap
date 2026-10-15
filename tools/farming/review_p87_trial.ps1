param(
    [string]$GodotExe = $env:GODOT_EXE_CONSOLE,
    [string[]]$Sizes = @('2560x1440','1920x1080','960x540'),
    [switch]$ChecksOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
$logRoot = Join-Path $projectRoot '.art-work/p87-trial'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
function Invoke-P87([string]$Name,[string[]]$EngineArgs,[string]$Marker) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = & $GodotExe --path $projectRoot --log-file (Join-Path $logRoot ($Name+'.engine.log')) @EngineArgs 2>&1
        $engineExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    $log = Join-Path $logRoot ($Name+'.log')
    [IO.File]::WriteAllLines($log,[string[]]($lines | ForEach-Object { $_.ToString() }),[Text.UTF8Encoding]::new($false))
    $result = [IO.File]::ReadAllText($log)
    # Preserve the raw log. Exempt only the established restricted Windows OS-store diagnostic.
    $checked = $result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+', ''
    if ($engineExit -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch $Marker) { throw "P8.7 failed: $Name; see $log" }
    Write-Output "$Name OK: exit $engineExit"
}
Invoke-P87 'projection-tests' @('--headless','--script','res://scripts/farming/tests/run_p87_projection.gd') 'P87 PROJECTION OK'
Invoke-P87 'production-tests' @('--headless','--script','res://scripts/farming/tests/run_p87_production.gd') 'P87 PRODUCTION OK'
Invoke-P87 'p85-lifecycle' @('--headless','--script','res://scripts/farming/tests/run_phase085_visuals.gd') 'PHASE085 VISUALS OK'
Invoke-P87 'p86-production' @('--headless','--script','res://scripts/farming/tests/run_p86_production.gd') 'P86 PRODUCTION OK'
if ($ChecksOnly) { exit 0 }
foreach ($size in $Sizes) {
    if ($size -notmatch '^\d+x\d+$') { throw "Invalid viewport: $size" }
    Invoke-P87 $size @('--rendering-method','gl_compatibility','--script','res://scripts/farming/validation/p87_projection_preview.gd','--',"--p87-dir=res://.art-work/p87-trial/$size","--shot-size=$size",'--ui-scale=100') 'P87 VISUAL PREVIEW OK: 22 frames'
    $folder = Join-Path $logRoot $size
    $trial = Get-Content -LiteralPath (Join-Path $folder 'trial.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $dimensions = Get-Content -LiteralPath (Join-Path $folder 'dimensions.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $parts = $size.Split('x')
    if ($trial.failures.Count -ne 0 -or $trial.frames.Count -ne 22 -or $dimensions.viewport[0] -ne [int]$parts[0] -or $dimensions.viewport[1] -ne [int]$parts[1] -or $trial.world_hash_before -ne $trial.world_hash_after) { throw "Incomplete matrix or mutated gameplay: $size" }
    foreach ($frame in $trial.frames) {
        if ($frame.size[0] -ne [int]$parts[0] -or $frame.size[1] -ne [int]$parts[1] -or -not (Test-Path -LiteralPath (Join-Path $folder $frame.file))) { throw "Invalid frame: $($frame.file)" }
    }
}
