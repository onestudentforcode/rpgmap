param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe='C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
$logRoot=Join-Path $projectRoot '.art-work/p102-historical'
New-Item -ItemType Directory -Force -Path (Join-Path $logRoot 'stores') | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
Push-Location $projectRoot
try {
    foreach ($version in @('v1','v2')) {
        & python ('tools/farming/bake_'+$version+'.py') --check
        if ($LASTEXITCODE -ne 0) { throw "Historical $version bake stale." }
    }
    function Check-Historical([string]$name,[string]$source,[string]$marker) {
        # Test store locations only. Preserve the assertion of the real default
        # V1 namespace; no production script, setting or player slot is rewritten.
        $source=$source.Replace('user://farm_demo_v1_slots/slot_1.json','P102_NAMESPACE_ASSERTION')
        $source=$source.Replace('user://','res://.art-work/p102-historical/stores/')
        $source=$source.Replace('P102_NAMESPACE_ASSERTION','user://farm_demo_v1_slots/slot_1.json')
        [IO.File]::WriteAllText((Join-Path $logRoot ($name+'.gd')),$source,$utf8)
        $log=Join-Path $logRoot $name
        $arguments=@('--headless','--path',('"'+$projectRoot+'"'),'--log-file',('"'+$log+'.engine.log"'),'--script',('res://.art-work/p102-historical/'+$name+'.gd'))
        $process=Start-Process -FilePath $GodotExe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput ($log+'.stdout.log') -RedirectStandardError ($log+'.stderr.log')
        $processHandle=$process.Handle
        $start=Get-Date
        while (-not $process.WaitForExit(1000)) {
            if (((Get-Date)-$start).TotalMinutes -gt 3) { $process.Kill(); throw "Historical regression timed out: $name" }
        }
        $process.Refresh()
        $result=[IO.File]::ReadAllText($log+'.stdout.log')+[IO.File]::ReadAllText($log+'.stderr.log')
        Write-Output $result.Trim()
        $checked=$result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
        if ($process.ExitCode -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch $marker) { throw "Historical regression failed: $name" }
    }
    foreach ($spec in @(
        @('run_v1_foundation','V1 FOUNDATION TEST OK'),@('run_v1_production','V1 PRODUCTION TEST OK'),
        @('run_v1_processing','V1 PROCESSING TEST OK'),@('run_v1_orders','V1 ORDERS TEST OK'),
        @('run_v1_workforce','V1 WORKFORCE TEST OK'),@('run_v1_workforce_ui','V1 WORKFORCE UI TEST OK'),
        @('run_v1_phase65_ui','V1 PHASE65 UI TEST OK'),@('run_v1_journal','V1 JOURNAL TEST OK'),
        @('run_phase07a','PHASE07A TEST OK'),@('run_phase07b','PHASE07B TEST OK'),
        @('run_phase07c','PHASE07C TEST OK'),@('run_phase07d','PHASE07D TEST OK'),
        @('run_phase07e','PHASE07E TEST OK'),@('run_phase07f','PHASE07F TEST OK'),
        @('run_v2_startup_ledger','P7.a STARTUP LEDGER OK'),@('run_v2_husbandry_replay','P7.b HUSBANDRY REPLAY OK'),
        @('run_v2_production_replay','P7.c PRODUCTION REPLAY OK'),@('run_v2_caretaker_replay','P7.d CARETAKER REPLAY OK'),
        @('run_v2_playtest','V2 TWO45 PLAYTEST OK'),@('run_v2_input_review','V2 INPUT REVIEW OK')
    )) {
        $source=[IO.File]::ReadAllText((Join-Path $projectRoot ('scripts/farming/tests/'+$spec[0]+'.gd')))
        Check-Historical $spec[0] $source $spec[1]
    }
    foreach ($version in @('v1','v2')) {
        $source=@'
extends SceneTree
const Shell := preload("res://scripts/farming/VERSION/VERSION_scene.gd")
const Store := preload("res://scripts/farming/VERSION/VERSION_slot_store.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var shell := Shell.new()
    shell.store=Store.new("res://.art-work/p102-historical/stores/VERSION-smoke-%d" % Time.get_ticks_usec())
    shell.settings=shell.settings.get_script().new("res://.art-work/p102-historical/stores/VERSION.cfg",0.25)
    root.add_child(shell)
    var probe=load("res://scripts/farming/validation/VERSION_release_smoke.gd").new()
    probe.shell=shell
    shell.add_child(probe)
    probe.run.call_deferred()
'@
        Check-Historical ($version+'-release') $source.Replace('VERSION',$version) ($version.ToUpper()+' RELEASE SMOKE OK')
    }
    Write-Output 'P102 HISTORICAL REGRESSION OK: original V1/V2 cases and release smoke, isolated stores'
} finally { Pop-Location }
