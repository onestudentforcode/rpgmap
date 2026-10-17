param([string]$GodotExe = $env:GODOT_EXE_CONSOLE,
      [string]$EvidenceRoot = '.art-work/p102-playtest/business-v5',
      [switch]$AuditExisting, [ValidateRange(1,8)][int]$Parallel = 4)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
$evidencePath = [IO.Path]::GetFullPath((Join-Path $projectRoot $EvidenceRoot))
if (-not $evidencePath.StartsWith($projectRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'EvidenceRoot must be inside the workspace.' }
New-Item -ItemType Directory -Force -Path $evidencePath | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
Push-Location $projectRoot
try {
    & python tools/farming/bake_p8.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Business source bake stale.' }
    $pending=[Collections.Generic.Queue[object]]::new()
    foreach ($mode in @('compound','ordinary','seed','material')) {
        foreach ($route in @('A','B')) {
            $folder=Join-Path (Join-Path $evidencePath ($mode+'-parts')) $route
            $record=Join-Path $folder 'run-process.json'
            $prior=$null
            if (Test-Path -LiteralPath $record) {
                $prior=Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
                $live=Get-Process -Id $prior.pid -ErrorAction SilentlyContinue
                if ($live -and $live.StartTime.ToUniversalTime().Ticks.ToString() -eq $prior.start_ticks) { throw "Route still has a live process: $mode/$route PID $($prior.pid). Observe that process; do not replay." }
            }
            if (Test-Path -LiteralPath (Join-Path $folder 'summary.json')) {
                if (-not $prior -or $prior.status -ne 'exited' -or $prior.exit_code -ne 0) { throw "Existing $mode/$route lacks a recorded successful process exit. Preserve it and inspect the original process/logs." }
                $priorLog=Join-Path $evidencePath ($mode+'-'+$route)
                $priorResult=[IO.File]::ReadAllText($priorLog+'.stdout.log')+[IO.File]::ReadAllText($priorLog+'.stderr.log')
                $priorChecked=$priorResult -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
                if ($priorChecked -match 'SCRIPT ERROR:|ERROR:' -or $priorChecked -notmatch 'P8 OPERATIONS PLAYTEST OK') { throw "Existing $mode/$route has failed or incomplete process logs." }
                & python tools/farming/audit_p8_playtest.py $folder --allow-gaps
                if ($LASTEXITCODE -ne 0) { throw "Existing $mode/$route evidence is invalid for the current source. Preserve it and choose a fresh -EvidenceRoot." }
                Write-Output "Reusing verified terminal route: $mode/$route"
                continue
            }
            if ($AuditExisting) { throw "Missing terminal evidence: $mode/$route" }
            if (Test-Path -LiteralPath (Join-Path $folder ($route+'-rooms.jsonl'))) { throw "Unfinished evidence exists at $folder. Inspect its process before replaying; preserve failed books." }
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            $pending.Enqueue([pscustomobject]@{Mode=$mode;Route=$route;Folder=$folder;Record=$record;Log=(Join-Path $evidencePath ($mode+'-'+$route))})
        }
    }
    $running=[Collections.Generic.List[object]]::new()
    $failed=[Collections.Generic.List[string]]::new()
    while ($running.Count -gt 0 -or ($pending.Count -gt 0 -and $failed.Count -eq 0)) {
        while ($pending.Count -gt 0 -and $running.Count -lt $Parallel -and $failed.Count -eq 0) {
            $job=$pending.Dequeue()
            $relative=$job.Folder.Substring($projectRoot.Length+1).Replace('\','/')
            $arguments=@('--headless','--path',('"'+$projectRoot+'"'),'--log-file',('"'+$job.Log+'.engine.log"'),
                '--script','res://scripts/farming/tests/run_p102_playtest.gd','--',('--route='+$job.Route),('--room-mode='+$job.Mode),'--days=120',('--audit-root=res://'+$relative))
            Write-Output "Running normal-economy route: $($job.Mode)/$($job.Route), 120 days"
            $process=Start-Process -FilePath $GodotExe -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput ($job.Log+'.stdout.log') -RedirectStandardError ($job.Log+'.stderr.log')
            $job | Add-Member Process $process
            $job | Add-Member Handle $process.Handle
            $job | Add-Member Started (Get-Date)
            [IO.File]::WriteAllText($job.Record,(@{pid=$process.Id;start_ticks=$process.StartTime.ToUniversalTime().Ticks.ToString();status='running'} | ConvertTo-Json),$utf8)
            [void]$running.Add($job)
        }
        foreach ($job in $running.ToArray()) {
            if (-not $job.Process.WaitForExit(0)) {
                if (((Get-Date)-$job.Started).TotalMinutes -le 15) { continue }
                & taskkill.exe /PID $job.Process.Id /T /F | Out-Null
                [void]$failed.Add("Timed out: $($job.Mode)/$($job.Route)")
                [void]$running.Remove($job)
                continue
            }
            $job.Process.Refresh()
            $code=$job.Process.ExitCode
            [IO.File]::WriteAllText($job.Record,(@{pid=$job.Process.Id;start_ticks=$job.Process.StartTime.ToUniversalTime().Ticks.ToString();status='exited';exit_code=$code} | ConvertTo-Json),$utf8)
            $result=[IO.File]::ReadAllText($job.Log+'.stdout.log')+[IO.File]::ReadAllText($job.Log+'.stderr.log')
            Write-Output $result.Trim()
            $checked=$result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
            if ($code -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch 'P8 OPERATIONS PLAYTEST OK') {
                [void]$failed.Add("Business route failed: $($job.Mode)/$($job.Route)")
            } else {
                & python tools/farming/audit_p8_playtest.py $job.Folder --allow-gaps
                if ($LASTEXITCODE -ne 0) { [void]$failed.Add("Single-route audit failed: $($job.Mode)/$($job.Route)") }
            }
            [void]$running.Remove($job)
        }
        if ($running.Count -gt 0) { Start-Sleep -Milliseconds 200 }
    }
    if ($failed.Count) { throw ($failed -join '; ') }
    foreach ($mode in @('compound','ordinary','seed','material')) {
        $assembled=Join-Path $evidencePath $mode
        & python tools/farming/assemble_p10_playtest.py (Join-Path $evidencePath ($mode+'-parts')) $assembled
        if ($LASTEXITCODE -ne 0) { throw "Room route assembly failed: $mode" }
        & python tools/farming/audit_p8_playtest.py $assembled
        if ($LASTEXITCODE -ne 0) { throw "Complete industry and room audit failed: $mode" }
    }
    & python tools/farming/test_p102_audit.py --evidence (Join-Path $evidencePath 'compound')
    if ($LASTEXITCODE -ne 0) { throw 'Room audit tamper probes failed.' }
    Write-Output 'P102 BUSINESS ACCEPTANCE OK: four configurations, independent A/B, 8 x 120 days'
} finally { Pop-Location }
