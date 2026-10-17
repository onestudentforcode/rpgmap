param([string]$GodotExe = $env:GODOT_EXE_CONSOLE, [switch]$SkipPlaytest)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
$logRoot = Join-Path $projectRoot '.art-work/p101-tests'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Push-Location $projectRoot
try {
    & python tools/farming/bake_p8.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.1 production bake stale.' }
    & python tools/farming/bake_encyclopedia.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.1 encyclopedia bake stale.' }
    & python -m unittest discover -s tools/farming -p 'test_p10*.py'
    if ($LASTEXITCODE -ne 0) { throw 'P10.1 source contracts failed.' }
    function Check-Game([string]$name,[string[]]$arguments,[string]$marker) {
        $prior = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $lines = & $GodotExe --headless --path $projectRoot --log-file (Join-Path $logRoot ($name+'.engine.log')) @arguments 2>&1
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prior }
        $outputText = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
        [IO.File]::WriteAllText((Join-Path $logRoot ($name+'.log')),$outputText,[Text.UTF8Encoding]::new($false))
        Write-Output $outputText
        $checkedText = $outputText -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
        if ($code -ne 0 -or $checkedText -match 'SCRIPT ERROR:|ERROR:' -or $checkedText -notmatch $marker) { throw "P10.1 check failed: $name" }
    }
    Check-Game 'model' @('--script','res://scripts/farming/tests/run_phase101.gd') 'PHASE101 TEST OK'
    Check-Game 'ui' @('--script','res://scripts/farming/tests/run_phase101_ui.gd') 'PHASE101 UI OK'
    Check-Game 'contrasts' @('--script','res://scripts/farming/tests/run_p101_contrasts.gd') 'P101 CONTRASTS OK'
    Check-Game 'handbook' @('--script','res://tools/farming/export_p8_handbook.gd','--','--check') 'P8 HANDBOOK DOC OK'
    Check-Game 'encyclopedia' @('--script','res://tools/farming/export_encyclopedia.gd','--','--check') 'P8 ENCYCLOPEDIA DOC OK'
    if (-not $SkipPlaytest) {
        $parts = Join-Path $logRoot 'agriculture120-parts'
        New-Item -ItemType Directory -Force -Path (Join-Path $parts 'A'),(Join-Path $parts 'B') | Out-Null
        foreach ($route in @('A','B')) {
            $lines = & $GodotExe --headless --path $projectRoot --log-file (Join-Path $logRoot ("agriculture-$route.engine.log")) `
                --script 'res://scripts/farming/tests/run_p101_playtest.gd' -- "--route=$route" '--days=120' "--audit-root=res://.art-work/p101-tests/agriculture120-parts/$route" 2>&1
            $code = $LASTEXITCODE
            $text = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
            [IO.File]::WriteAllText((Join-Path $logRoot ("agriculture-$route.log")),$text,[Text.UTF8Encoding]::new($false))
            Write-Output $text
            if ($code -ne 0 -or $text -notmatch 'P8 OPERATIONS PLAYTEST OK') { throw "P10.1 agriculture route $route failed" }
        }
        & python tools/farming/assemble_p10_playtest.py $parts (Join-Path $logRoot 'agriculture120')
        if ($LASTEXITCODE -ne 0) { throw 'P10.1 route assembly failed.' }
        & python tools/farming/audit_p101_playtest.py (Join-Path $logRoot 'agriculture120')
        if ($LASTEXITCODE -ne 0) { throw 'P10.1 agriculture audit failed.' }
        & python -m unittest discover -s tools/farming -p 'test_p101_audit.py'
        if ($LASTEXITCODE -ne 0) { throw 'P10.1 audit tamper probes failed.' }
    }
    Write-Output 'P101 DEVELOPMENT SUITE OK'
} finally {
    Pop-Location
}
