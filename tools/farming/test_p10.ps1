param([string]$GodotExe = $env:GODOT_EXE_CONSOLE, [switch]$SkipPlaytest, [switch]$AuditExisting)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
$logRoot = Join-Path $projectRoot '.art-work/p10-tests'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Push-Location $projectRoot
try {
    & python tools/farming/bake_p8.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10 production bake stale.' }
    & python tools/farming/bake_encyclopedia.py --check
    if ($LASTEXITCODE -ne 0) { throw 'P10 encyclopedia bake stale.' }
    & python -m unittest discover -s tools/farming -p 'test_p10*.py'
    if ($LASTEXITCODE -ne 0) { throw 'P10 source contracts failed.' }
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
        if ($code -ne 0 -or $checkedText -match 'SCRIPT ERROR:|ERROR:' -or $checkedText -notmatch $marker) { throw "P10 check failed: $name" }
    }
    Check-Game 'model' @('--script','res://scripts/farming/tests/run_phase10.gd') 'PHASE10 TEST OK'
    Check-Game 'ui' @('--script','res://scripts/farming/tests/run_phase10_ui.gd') 'PHASE10 UI OK'
    Check-Game 'handbook' @('--script','res://tools/farming/export_p8_handbook.gd','--','--check') 'P8 HANDBOOK DOC OK'
    Check-Game 'encyclopedia' @('--script','res://tools/farming/export_encyclopedia.gd','--','--check') 'P8 ENCYCLOPEDIA DOC OK'
    if (-not $SkipPlaytest) {
        # Independent routes share no stores or books. Run them concurrently;
        # assembly retains the original raw summaries and checks provenance.
        $jobs = @()
        foreach ($group in @('control120','logistics120')) {
            $script = if ($group -eq 'control120') { 'res://scripts/farming/tests/run_p8_playtest.gd' } else { 'res://scripts/farming/tests/run_p10_playtest.gd' }
            foreach ($route in @('A','B')) {
                $name = "$group-$route"
                $stdout = Join-Path $logRoot ($name+'.stdout.log')
                $stderr = Join-Path $logRoot ($name+'.stderr.log')
                $arguments = @('--headless','--path',('"'+$projectRoot+'"'),'--log-file',('"'+(Join-Path $logRoot ($name+'.engine.log'))+'"'),'--script',$script,'--',('--route='+$route),('--audit-root=res://.art-work/p10-tests/'+$group+'-parts/'+$route))
                if ($AuditExisting) {
                    if (-not (Test-Path -LiteralPath $stdout) -or -not (Test-Path -LiteralPath $stderr)) { throw "Missing existing route logs: $name" }
                    $jobs += @{name=$name; process=$null; stdout=$stdout; stderr=$stderr}
                    Write-Output "Re-auditing existing original route books: $name"
                } else {
                    $process = Start-Process -FilePath $GodotExe -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
                    # Retain the native process handle before a short-lived
                    # launcher exits; never interpret a null ExitCode as zero.
                    $null = $process.Handle
                    $jobs += @{name=$name; process=$process; stdout=$stdout; stderr=$stderr}
                    Write-Output "Started $name, PID $($process.Id)"
                }
            }
        }
        foreach ($job in $jobs) {
            if ($null -ne $job.process) {
                $job.process.WaitForExit()
                $job.process.Refresh()
                $code = $job.process.ExitCode
                if ($null -eq $code -or $code -ne 0) { throw "P10 route process exit failed: $($job.name), code=<$code>" }
            }
            $result = [IO.File]::ReadAllText($job.stdout)+[IO.File]::ReadAllText($job.stderr)
            Write-Output $result
            $checked = $result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+',''
            if ($checked -match 'SCRIPT ERROR:|ERROR:' -or $result -notmatch 'P8 OPERATIONS PLAYTEST OK') { throw "P10 business route failed: $($job.name)" }
        }
        foreach ($route in @('control120','logistics120')) {
            & python tools/farming/assemble_p10_playtest.py (Join-Path $logRoot ($route+'-parts')) (Join-Path $logRoot $route)
            if ($LASTEXITCODE -ne 0) { throw "Route assembly failed: $route" }
            & python tools/farming/audit_p8_playtest.py (Join-Path $logRoot $route)
            if ($LASTEXITCODE -ne 0) { throw "P8 strict audit failed: $route" }
        }
        & python tools/farming/audit_p10_playtest.py (Join-Path $logRoot 'logistics120')
        if ($LASTEXITCODE -ne 0) { throw 'P10 logistics strict audit failed.' }
        & python tools/farming/test_p10_playtest_audit.py (Join-Path $logRoot 'logistics120')
        if ($LASTEXITCODE -ne 0) { throw 'P10 auditor corruption probes failed.' }
    }
    Write-Output 'P10 DEVELOPMENT SUITE OK'
} finally { Pop-Location }
