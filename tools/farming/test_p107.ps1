param(
    [ValidateSet('All','Plan','Model','Run','Audit','Probes','Report','UI','Smoke','Accept')]
    [string]$Stage = 'All',
    [string[]]$Cases,
    [string[]]$Models,
    [string]$GodotExe = $env:GODOT_EXE_CONSOLE,
    [switch]$Fresh,
    [switch]$SkipGpu
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskArgs = @('tools/farming/test_p107.py', '--stage', $Stage)
if ($Cases) { $taskArgs += '--cases'; $taskArgs += $Cases }
if ($Models) { $taskArgs += '--models'; $taskArgs += $Models }
if ($GodotExe) { $taskArgs += @('--godot', $GodotExe) }
if ($Fresh) { $taskArgs += '--fresh' }
if ($SkipGpu) { $taskArgs += '--skip-gpu' }
Push-Location $projectRoot
try { & python @taskArgs; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
finally { Pop-Location }
