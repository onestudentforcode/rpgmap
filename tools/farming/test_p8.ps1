param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$logRoot = Join-Path $projectRoot '.art-work/p8-tests'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Push-Location $projectRoot
try {
    & python tools/farming/bake_p8.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P8 bake failed.' }
    & python tools/farming/test_p8_foundation.py
    if ($LASTEXITCODE -ne 0) { throw 'P8 config checks failed.' }
    function Invoke-GodotCheck([string]$name, [string[]]$arguments, [string]$marker) {
        $log = Join-Path $logRoot ($name+'.stdout.log')
        $engineLog = Join-Path $logRoot ($name+'.engine.log')
        & $GodotExe --headless --path $projectRoot --log-file $engineLog @arguments *> $log
        $exitCode = $LASTEXITCODE
        $result = Get-Content -LiteralPath $log -Raw -Encoding UTF8
        Write-Output $result.Trim()
        # Godot may return 0 after a GDScript error. Check logs AND exit status.
        if ($exitCode -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:' -or $result -notmatch $marker) { throw "P8 check failed: $name ($log)" }
    }
    Invoke-GodotCheck 'phase08a' @('--script','res://scripts/farming/tests/run_phase08a.gd') 'PHASE08A TEST OK'
    Invoke-GodotCheck 'phase08b' @('--script','res://scripts/farming/tests/run_phase08b.gd') 'PHASE08B TEST OK'
    Invoke-GodotCheck 'release' @('res://scenes/farming/farm_p8.tscn','--','--p8-smoke') 'P8 RELEASE SMOKE OK'
    Write-Output 'P8 P8.a SUITE OK'
} finally { Pop-Location }
