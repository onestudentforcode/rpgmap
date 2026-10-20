param([string]$GodotExe = $env:GODOT_EXE_CONSOLE,
      [switch]$SkipPlaytest)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
$evidenceRoot = Join-Path $projectRoot '.art-work/p105-playtest'
$logRoot = Join-Path $projectRoot '.art-work/p105-tests'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Push-Location $projectRoot
try {
    if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
    & python tools/farming/bake_p8.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.5 production bake stale.' }
    & python tools/farming/bake_encyclopedia.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.5 encyclopedia bake stale.' }
    function Check-Game([string]$name,[string]$script,[string]$marker,[int]$timeoutMs = 1200000) {
        $stdout = Join-Path $logRoot ($name+'.stdout.log')
        $stderr = Join-Path $logRoot ($name+'.stderr.log')
        $arguments = @('--headless','--path',('"'+$projectRoot+'"'),'--script',$script)
        $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $processHandle = $process.Handle
        if (-not $process.WaitForExit($timeoutMs)) {
            $process.Kill()
            throw "P10.5 check timed out: $name; inspect $stdout and $stderr"
        }
        $process.Refresh()
        $exitCode = $process.ExitCode
        $result = [IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
        Write-Output $result.Trim()
        $checked = $result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
        if ($exitCode -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch $marker) { throw "P10.5 check failed: $name ($stdout)" }
    }
    Check-Game 'model' 'res://scripts/farming/tests/run_phase105.gd' 'P105 MODEL OK' 300000
    Check-Game 'p103-model' 'res://scripts/farming/tests/run_phase103.gd' 'P103 MODEL OK' 300000
    Check-Game 'fixture-lint' 'res://scripts/farming/tests/run_fixture_lint.gd' 'FIXTURE LINT OK' 300000
    if (-not $SkipPlaytest) {
        Check-Game 'playtest' 'res://scripts/farming/tests/run_p105_playtest.gd' 'P105 PLAYTEST OK'
        & python tools/farming/audit_p105_playtest.py $evidenceRoot
        if ($LASTEXITCODE -ne 0) { throw 'P10.5 business audit failed.' }
    }
    Write-Output 'P105 CHECKS OK'
}
finally { Pop-Location }
