param([string]$GodotExe = $env:GODOT_EXE_CONSOLE, [switch]$SkipPlaytest)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$logRoot = Join-Path $projectRoot '.art-work/v2-tests'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Push-Location $projectRoot
try {
    & python tools/farming/bake_v2.py --check
    if ($LASTEXITCODE -ne 0) { throw 'V2 bake failed.' }
    & python tools/farming/test_v2_foundation.py
    if ($LASTEXITCODE -ne 0) { throw 'V2 config checks failed.' }
    function Invoke-GodotCheck([string]$name, [string[]]$arguments, [string]$marker) {
        $log = Join-Path $logRoot ($name+'.stdout.log')
        $engineLog = Join-Path $logRoot ($name+'.engine.log')
        & $GodotExe --headless --path $projectRoot --log-file $engineLog @arguments *> $log
        $exitCode = $LASTEXITCODE
        $result = Get-Content -LiteralPath $log -Raw -Encoding UTF8
        Write-Output $result.Trim()
        # Godot may return0 after a GDScript error. Check logs AND exit status.
        if ($exitCode -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:' -or $result -notmatch $marker) { throw "V2 check failed: $name ($log)" }
    }
    foreach ($phase in @('a','b','c','d','e','f')) {
        Invoke-GodotCheck ('phase07'+$phase) @('--script',('res://scripts/farming/tests/run_phase07'+$phase+'.gd')) ('PHASE07'+$phase.ToUpper()+' TEST OK')
    }
    foreach ($spec in @(
        @('startup','run_v2_startup_ledger.gd','P7.a STARTUP LEDGER OK'),
        @('juveniles','run_v2_husbandry_replay.gd','P7.b HUSBANDRY REPLAY OK'),
        @('production','run_v2_production_replay.gd','P7.c PRODUCTION REPLAY OK'),
        @('caretakers','run_v2_caretaker_replay.gd','P7.d CARETAKER REPLAY OK')
    )) { Invoke-GodotCheck $spec[0] @('--script',('res://scripts/farming/tests/'+$spec[1])) $spec[2] }
    if (-not $SkipPlaytest) {
        Invoke-GodotCheck 'two45' @('--script','res://scripts/farming/tests/run_v2_playtest.gd') 'V2 TWO45 PLAYTEST OK'
        Invoke-GodotCheck 'input' @('--script','res://scripts/farming/tests/run_v2_input_review.gd') 'V2 INPUT REVIEW OK'
    }
    Invoke-GodotCheck 'release' @('res://scenes/farming/farm_v2.tscn','--','--v2-smoke') 'V2 RELEASE SMOKE OK'
    Write-Output 'V2 P7.f SUITE OK'
} finally { Pop-Location }
