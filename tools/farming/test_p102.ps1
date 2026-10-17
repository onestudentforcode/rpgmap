param([string]$GodotExe = $env:GODOT_EXE_CONSOLE, [switch]$SkipPlaytest,
      [switch]$AuditExisting, [string]$EvidenceRoot = '.art-work/p102-playtest/business-v5')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$logRoot = Join-Path $projectRoot '.art-work/p102-tests'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Push-Location $projectRoot
try {
    if ($AuditExisting) {
        & (Join-Path $PSScriptRoot 'run_p102_business.ps1') -GodotExe $GodotExe -EvidenceRoot $EvidenceRoot -AuditExisting
        exit $LASTEXITCODE
    }
    & python tools/farming/bake_p8.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.2 production bake stale.' }
    & python tools/farming/bake_encyclopedia.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.2 encyclopedia bake stale.' }
    & python -m unittest discover -s tools/farming -p 'test_*.py'
    if ($LASTEXITCODE -ne 0) { throw 'Python contracts failed.' }
    function Check-Game([string]$name,[string]$script,[string]$marker,[string[]]$extra=@()) {
        $stdout = Join-Path $logRoot ($name+'.stdout.log')
        $stderr = Join-Path $logRoot ($name+'.stderr.log')
        $arguments = @('--headless','--path',('"'+$projectRoot+'"'),'--log-file',('"'+(Join-Path $logRoot ($name+'.engine.log'))+'"'),'--script',$script)+$extra
        $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $processHandle = $process.Handle
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            throw "P10.2 check timed out: $name; inspect $stdout and $stderr"
        }
        $process.Refresh()
        $exitCode = $process.ExitCode
        $result = [IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
        Write-Output $result.Trim()
        # Restricted Windows cannot read the certificate store. Retain the raw
        # diagnostic and exempt precisely this known OS warning, nothing else.
        $checked = $result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
        if ($exitCode -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch $marker) { throw "P10.2 check failed: $name ($stdout)" }
    }
    Check-Game 'model' 'res://scripts/farming/tests/run_phase102.gd' 'P102 MODEL OK'
    Check-Game 'ui' 'res://scripts/farming/tests/run_phase102_ui.gd' 'P102 UI OK'
    Check-Game 'logistics-model' 'res://scripts/farming/tests/run_phase10.gd' 'PHASE10 TEST OK'
    Check-Game 'logistics-ui' 'res://scripts/farming/tests/run_phase10_ui.gd' 'PHASE10 UI OK'
    Check-Game 'agriculture-model' 'res://scripts/farming/tests/run_phase101.gd' 'PHASE101 TEST OK'
    Check-Game 'agriculture-ui' 'res://scripts/farming/tests/run_phase101_ui.gd' 'PHASE101 UI OK'
    Check-Game 'handbook-ui' 'res://scripts/farming/tests/run_p8_handbook.gd' 'P8 HANDBOOK UI OK'
    Check-Game 'encyclopedia-ui' 'res://scripts/farming/tests/run_p9_encyclopedia.gd' 'P9 ENCYCLOPEDIA OK'
    Check-Game 'handbook-doc' 'res://tools/farming/export_p8_handbook.gd' 'P8 HANDBOOK DOC OK' @('--','--check')
    Check-Game 'encyclopedia-doc' 'res://tools/farming/export_encyclopedia.gd' 'P8 ENCYCLOPEDIA DOC OK' @('--','--check')
    Check-Game 'business-layout' 'res://scripts/farming/tests/run_p102_playtest.gd' 'P102 BUSINESS LAYOUT OK' @('--','--layout-only')
    Write-Output 'P102 DEVELOPMENT CHECKS OK (business acceptance is a separate gate)'
    if (-not $SkipPlaytest) {
        & (Join-Path $PSScriptRoot 'run_p102_business.ps1') -GodotExe $GodotExe -EvidenceRoot $EvidenceRoot
        if (-not $?) { throw 'P102 business acceptance failed.' }
    }
} finally {
    Pop-Location
}
