param(
    [ValidateSet('All','Plan','Model','UI','Route-Replay','Route','Regression','GPU','Accept')]
    [string]$Stage = 'All',
    [string[]]$Models,
    [string]$GodotExe = $env:GODOT_EXE_CONSOLE
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskArgs = @('tools/farming/test_p108.py', '--stage', $Stage)
if ($Models) { $taskArgs += '--models'; $taskArgs += $Models }
if ($GodotExe) { $taskArgs += @('--godot', $GodotExe) }
Push-Location $projectRoot
try { & python @taskArgs; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
finally { Pop-Location }
