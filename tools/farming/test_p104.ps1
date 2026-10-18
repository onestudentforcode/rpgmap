param(
    [ValidateSet('Plan','Model','Run','Audit','Probes','Smoke','UI','Accept')][string]$Stage='Model',
    [string]$Root='.art-work/p104-playtest/current',
    [string[]]$Cases=@('structure','hosts','toy','breeding','work','compound','breeding-base','work-base'),
    [string]$GodotExe=$env:GODOT_EXE_CONSOLE,
    [switch]$Rerun
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe='C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
Push-Location $projectRoot
try {
    $evidence=[IO.Path]::GetFullPath((Join-Path $projectRoot $Root))
    $allowed=[IO.Path]::GetFullPath((Join-Path $projectRoot '.art-work'))+[IO.Path]::DirectorySeparatorChar
    if (-not $evidence.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence root must stay under this project .art-work.' }
    New-Item -ItemType Directory -Force -Path $evidence | Out-Null
    $logs=Join-Path $evidence 'logs'
    New-Item -ItemType Directory -Force -Path $logs | Out-Null
    $planFile=Join-Path $evidence 'plan.json'
    function Source-Manifest {
        $paths=@(Get-ChildItem scripts/farming/p8 -Filter '*.gd' -File | Where-Object Name -NotMatch '(_ui|_scene|_handbook|_encyclopedia)\.gd$')
        $paths+=Get-Item 'content/farming/baked/p8/production.json','scripts/farming/tests/run_phase103.gd','scripts/farming/tests/run_phase104.gd','scripts/farming/tests/run_p104_playtest.gd'
        $result=[ordered]@{}
        foreach ($file in ($paths | Sort-Object FullName -Unique)) { $result[$file.FullName.Substring($projectRoot.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
        return $result
    }
    function Check-Plan {
        if (-not (Test-Path -LiteralPath $planFile)) { throw 'Run -Stage Plan first.' }
        $plan=Get-Content -LiteralPath $planFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $now=Source-Manifest
        foreach ($item in $now.GetEnumerator()) {
            if ($plan.sources.($item.Key) -ne $item.Value) { throw ('Shared source changed; create a new evidence root and plan: '+$item.Key) }
        }
        # Smoke driver is independent of module receipts. Older plans included
        # it too broadly; retain those plans, compare only actual shared inputs.
        $properties=@($plan.sources.PSObject.Properties | Where-Object Name -NotMatch '(_ui|_scene|_handbook|_encyclopedia)\.gd$|run_p104_smoke\.gd$')
        if ($properties.Count -ne $now.Count) { throw 'Shared source inventory changed.' }
    }
    function Check-Python([string[]]$Arguments) {
        & python @Arguments
        if ($LASTEXITCODE -ne 0) { throw ('Python check failed: '+($Arguments -join ' ')) }
    }
    function Check-Game([string]$Name,[string]$Script,[string]$Marker,[string[]]$Extra=@(),[int]$Timeout=300000) {
        $stdout=Join-Path $logs ($Name+'.stdout.log')
        $stderr=Join-Path $logs ($Name+'.stderr.log')
        $gameLog=Join-Path $logs ($Name+'.godot.log')
        $arguments=@('--headless','--path',('"'+$projectRoot+'"'),'--log-file',('"'+$gameLog+'"'),'--script',$Script)+$Extra
        $process=Start-Process -FilePath $GodotExe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $handle=$process.Handle
        if (-not $process.WaitForExit($Timeout)) { $process.Kill();throw ('Check timeout: '+$Name) }
        $process.Refresh()
        $result=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
        Write-Output $result.Trim()
        $checked=$result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
        if ($process.ExitCode -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch $Marker) { throw ('Check failed: '+$Name) }
    }
    switch ($Stage) {
        Plan {
            if (Test-Path -LiteralPath $planFile) { throw 'Plan exists; select a new root.' }
            [ordered]@{kind='p104-layered-plan';created=(Get-Date).ToString('o');sources=(Source-Manifest);cases=$Cases;smoke_days=60} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $planFile -Encoding UTF8
        }
        Model {
            Check-Python @('tools/farming/bake_p8.py','--check')
            Check-Python @('tools/farming/bake_encyclopedia.py','--check')
            Check-Python @('-m','unittest','discover','-s','tools/farming','-p','test_p104_contract.py')
            Check-Game 'model' 'res://scripts/farming/tests/run_phase104.gd' 'P104 MODEL OK'
            Check-Game 'capacity' 'res://scripts/farming/tests/run_p104_capacity.gd' 'P104 CAPACITY OK'
            Check-Game 'agriculture' 'res://scripts/farming/tests/run_phase102.gd' 'P102 MODEL OK'
            Check-Game 'ranch' 'res://scripts/farming/tests/run_phase103.gd' 'P103 MODEL OK'
        }
        Run {
            Check-Plan
            foreach ($case in $Cases) {
                if ($case -notin @('structure','hosts','toy','breeding','work','compound','breeding-base','work-base')) { throw ('Unknown partition: '+$case) }
                $target=[IO.Path]::GetFullPath((Join-Path $evidence $case))
                if (-not $target.StartsWith($evidence+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe partition path.' }
                if (Test-Path -LiteralPath $target) {
                    if (-not $Rerun) { throw ('Partition exists; use -Rerun to archive only this partition: '+$case) }
                    $archive=Join-Path $evidence ('archive-'+$case+'-'+(Get-Date -Format 'yyyyMMddHHmmssfff'))
                    Move-Item -LiteralPath $target -Destination $archive
                    foreach ($suffix in @('.stdout.log','.stderr.log','.godot.log')) {
                        $oldLog=Join-Path $logs ($case+$suffix)
                        if (Test-Path -LiteralPath $oldLog) { Copy-Item -LiteralPath $oldLog -Destination (Join-Path $archive ($case+$suffix)) }
                    }
                }
                Check-Game $case 'res://scripts/farming/tests/run_p104_playtest.gd' 'P104 PLAYTEST OK' @('--',('--root='+$evidence.Replace('\','/')),('--cases='+$case))
            }
        }
        Audit {
            Check-Plan
            foreach ($case in $Cases) {
                if ($case -notin @('structure','hosts','toy','breeding','work','compound','breeding-base','work-base')) { throw ('Unknown partition: '+$case) }
                Check-Python @('tools/farming/audit_p104_playtest.py',(Join-Path $evidence ($case+'/scenario.json')))
            }
        }
        Probes {
            $env:P104_EVIDENCE=$evidence
            Check-Python @('-m','unittest','discover','-s','tools/farming','-p','test_p104_audit.py')
        }
        Smoke {
            Check-Plan
            Check-Game 'smoke' 'res://scripts/farming/tests/run_p104_smoke.gd' 'P104 SMOKE OK' @('--',('--output='+$evidence.Replace('\','/')+'/smoke.json')) 1200000
            Check-Python @('tools/farming/audit_p104_playtest.py',(Join-Path $evidence 'smoke.json'))
        }
        UI { Check-Game 'ui' 'res://scripts/farming/tests/run_phase104_ui.gd' 'P104 UI OK' }
        Accept {
            Check-Plan
            foreach ($case in @('structure','hosts','toy','breeding','work','compound')) {
                if (-not (Test-Path -LiteralPath (Join-Path $evidence ($case+'/scenario.json')))) { throw ('Missing required partition: '+$case) }
            }
            Check-Python @('tools/farming/audit_p104_playtest.py',$evidence)
            Write-Output 'Partition acceptance passed; model, UI and milestone smoke evidence are recorded separately.'
        }
    }
    Write-Output ('P104 '+$Stage+' OK')
} finally { Pop-Location }
