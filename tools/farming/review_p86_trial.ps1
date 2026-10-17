param(
    [string]$GodotExe = $env:GODOT_EXE_CONSOLE,
    [string[]]$Sizes = @('2560x1440','1920x1080','960x540')
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw 'Supply -GodotExe or GODOT_EXE_CONSOLE.' }
$logRoot = Join-Path $projectRoot '.art-work/p86-trial'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
foreach ($size in $Sizes) {
    if ($size -notmatch '^\d+x\d+$') { throw "Invalid viewport: $size" }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $engineLog = Join-Path $logRoot ($size+'.engine.log')
        $lines = & $GodotExe --path $projectRoot --log-file $engineLog --rendering-method gl_compatibility --script res://scripts/farming/validation/p86_visual_preview.gd -- "--p86-dir=res://.art-work/p86-trial/$size" "--shot-size=$size" --ui-scale=100 2>&1
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    $log = Join-Path $logRoot ($size+'.log')
    [IO.File]::WriteAllLines($log,[string[]]($lines | ForEach-Object { $_.ToString() }),[Text.UTF8Encoding]::new($false))
    $result = [IO.File]::ReadAllText($log)
    $checked = $result -replace 'ERROR: Failed to read the root certificate store\.[\r\n]+\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)[\r\n]+', ''
    if ($exitCode -ne 0 -or $checked -match 'SCRIPT ERROR:|ERROR:' -or $checked -notmatch 'P86 VISUAL PREVIEW OK: 24 frames') { throw "P8.6 trial failed: $log" }
    $expected = $size.Split('x')
    $folder = Join-Path $logRoot $size
    $dimensions = Get-Content -LiteralPath (Join-Path $folder 'dimensions.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $trial = Get-Content -LiteralPath (Join-Path $folder 'trial.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($trial.failures.Count -ne 0 -or $trial.frames.Count -ne 24 -or $dimensions.viewport[0] -ne [int]$expected[0] -or $dimensions.viewport[1] -ne [int]$expected[1]) { throw "Invalid trial matrix dimensions: $size" }
    foreach ($frame in $trial.frames) {
        if ($frame.size[0] -ne [int]$expected[0] -or $frame.size[1] -ne [int]$expected[1] -or -not (Test-Path -LiteralPath (Join-Path $folder $frame.file) -PathType Leaf)) { throw "Invalid trial frame: $($frame.file)" }
    }
    Write-Output "P86 GPU matrix OK: $size, 24 frames"
}
