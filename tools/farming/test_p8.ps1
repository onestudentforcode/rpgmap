param([string]$GodotExe = $env:GODOT_EXE_CONSOLE, [switch]$IncludePlaytest, [switch]$WorkspaceStores)
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
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue' # PS 5 treats native stderr as a PowerShell error record.
            $lines = & $GodotExe --headless --path $projectRoot --log-file $engineLog @arguments 2>&1
            $exitCode = $LASTEXITCODE
            [IO.File]::WriteAllLines($log, [string[]]($lines | ForEach-Object { $_.ToString() }), [Text.UTF8Encoding]::new($false))
        } finally { $ErrorActionPreference = $previousPreference }
        $result = Get-Content -LiteralPath $log -Raw -Encoding UTF8
        Write-Output $result.Trim()
        if ($WorkspaceStores) {
            # Restricted Windows environments cannot access the OS certificate store.
            # Keep the raw warning, and exempt only this exact OS diagnostic.
            $result = $result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+', ''
        }
        # Godot may return 0 after a GDScript error. Check logs AND exit status.
        if ($exitCode -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:' -or $result -notmatch $marker) { throw "P8 check failed: $name ($log)" }
    }
    Invoke-GodotCheck 'visuals085' @('--script','res://scripts/farming/tests/run_phase085_visuals.gd') 'PHASE085 VISUALS OK'
    Invoke-GodotCheck 'visuals086' @('--script','res://scripts/farming/tests/run_p86_production.gd') 'P86 PRODUCTION OK'
    $fixtureRoot = Join-Path $logRoot 'fixtures'
    $utf8 = [Text.UTF8Encoding]::new($false)
    foreach ($phase in @('a','b','c','d','e','f','g','h_living')) {
        $name = 'run_phase08' + $phase
        $script = 'res://scripts/farming/tests/' + $name + '.gd'
        if ($WorkspaceStores) {
            New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot 'stores') | Out-Null
            $source = [IO.File]::ReadAllText((Join-Path $projectRoot ('scripts/farming/tests/' + $name + '.gd')))
            [IO.File]::WriteAllText((Join-Path $fixtureRoot ($name + '.gd')), $source.Replace('user://','res://.art-work/p8-tests/fixtures/stores/'), $utf8)
            $script = 'res://.art-work/p8-tests/fixtures/' + $name + '.gd'
        }
        $marker = if ($phase -eq 'h_living') { 'PHASE08H LIVING OK' } else { 'PHASE08' + $phase.ToUpper() + ' TEST OK' }
        Invoke-GodotCheck ('phase08'+$phase) @('--script',$script) $marker
    }
    if ($WorkspaceStores) {
        # Boot the real shell and original smoke without replacing production files.
        $fixture = @'
extends SceneTree
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var shell := Shell.new()
    shell.store = Store.new("res://.art-work/p8-tests/fixtures/ui-slots-%d" % Time.get_ticks_usec())
    shell.settings = shell.settings.get_script().new("res://.art-work/p8-tests/fixtures/settings.cfg", 0.1)
    root.add_child(shell)
    var probe = load("res://scripts/farming/validation/p8_release_smoke.gd").new()
    probe.shell = shell
    shell.add_child(probe)
    probe.run.call_deferred()
'@
        [IO.File]::WriteAllText((Join-Path $fixtureRoot 'release.gd'), $fixture, $utf8)
        Invoke-GodotCheck 'release' @('--script','res://.art-work/p8-tests/fixtures/release.gd') 'P8 RELEASE SMOKE OK'
    } else {
        Invoke-GodotCheck 'release' @('res://scenes/farming/farm_p8.tscn','--','--p8-smoke') 'P8 RELEASE SMOKE OK'
    }
    Invoke-GodotCheck 'handbook' @('--script','res://scripts/farming/tests/run_p8_handbook.gd') 'P8 HANDBOOK UI OK'
    Invoke-GodotCheck 'handbook-doc' @('--script','res://tools/farming/export_p8_handbook.gd','--','--check') 'P8 HANDBOOK DOC OK'
    Invoke-GodotCheck 'expansion' @('--script','res://scripts/farming/tests/run_p8_expansion.gd') 'P8 EXPANSION OK'
    if ($IncludePlaytest) {
        Invoke-GodotCheck 'two120' @('--script','res://scripts/farming/tests/run_p8_playtest.gd','--','--with-expansion','--audit-root=res://.art-work/p8-tests/playtest') 'P8 OPERATIONS PLAYTEST OK'
        & python tools/farming/audit_p8_playtest.py (Join-Path $logRoot 'playtest')
        if ($LASTEXITCODE -ne 0) { throw 'P8 playtest ledger audit failed.' }
        & python tools/farming/test_p8_playtest_audit.py (Join-Path $logRoot 'playtest') --probe-root (Join-Path $logRoot 'audit-negative')
        if ($LASTEXITCODE -ne 0) { throw 'P8 playtest audit corruption probes failed.' }
    }
    Write-Output 'P8 DEVELOPMENT SUITE OK'
} finally { Pop-Location }
