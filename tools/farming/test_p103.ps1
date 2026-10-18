param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$logRoot = Join-Path $projectRoot '.art-work/p103-tests'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Push-Location $projectRoot
try {
    & python tools/farming/bake_p8.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.3 production bake stale.' }
    & python tools/farming/bake_encyclopedia.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10.3 encyclopedia bake stale.' }
    function Check-Game([string]$name,[string]$script,[string]$marker,[int]$timeoutMs = 600000) {
        $stdout = Join-Path $logRoot ($name+'.stdout.log')
        $stderr = Join-Path $logRoot ($name+'.stderr.log')
        $arguments = @('--headless','--path',('"'+$projectRoot+'"'),'--script',$script)
        $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if (-not $process.WaitForExit($timeoutMs)) {
            $process.Kill()
            throw "P10.3 check timed out: $name; inspect $stdout and $stderr"
        }
        $process.Refresh()
        $exitCode = $process.ExitCode
        $result = [IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
        Write-Output $result.Trim()
        $checked = $result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
        if ($exitCode -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch $marker) { throw "P10.3 check failed: $name ($stdout)" }
    }
    Check-Game 'model' 'res://scripts/farming/tests/run_phase103.gd' 'P103 MODEL OK'
    Write-Output 'P103 FAST CHECKS OK'
} finally {
    Pop-Location
}
