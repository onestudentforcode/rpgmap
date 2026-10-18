param([string]$GodotExe = $env:GODOT_EXE_CONSOLE,
      [string]$EvidenceRoot = '.art-work/p102-playtest/business-v5',
      [switch]$AuditExisting, [ValidateRange(1,8)][int]$Parallel = 4,
      [ValidateSet('Plan','Run','Assemble','Audit','Probes','Accept')][string]$Stage = 'Accept',
      [string]$Cases = 'all', [switch]$Rerun)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
$arguments=@('tools/farming/run_p102_business.py','--evidence-root',$EvidenceRoot,
    '--godot',$GodotExe,'--parallel',$Parallel,'--stage',$Stage,'--cases',$Cases)
if ($AuditExisting) { $arguments+='--audit-existing' }
if ($Rerun) { $arguments+='--rerun' }
Push-Location $projectRoot
try {
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'P102 partition checks failed; see the case/step log paths above.' }
} finally { Pop-Location }
