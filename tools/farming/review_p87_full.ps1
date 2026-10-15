param([string]$GodotExe=$env:GODOT_EXE_CONSOLE)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) {$GodotExe='C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe'}
$out=Join-Path $projectRoot '.art-work/p87-final-visual'
New-Item -ItemType Directory -Force -Path $out | Out-Null
foreach($size in @('2560x1440','1920x1080','960x540')) {
    $log=Join-Path $out ($size+'.log')
    & $GodotExe --path $projectRoot --rendering-method gl_compatibility --log-file $log --script res://scripts/farming/validation/p87_full_visual_preview.gd -- "--p87-full-dir=res://.art-work/p87-final-visual/$size" "--shot-size=$size" --ui-scale=100 *> (Join-Path $out ($size+'.stdout.log'))
    $result=Get-Content -LiteralPath $log -Raw -Encoding UTF8
    if($LASTEXITCODE -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:' -or $result -notmatch 'P87 FULL VISUAL PREVIEW OK') {throw "GPU matrix failed: $log"}
    $report=Get-Content -LiteralPath (Join-Path $out "$size/frames.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $parts=$size.Split('x')
    if ($report.frames.Count -ne 20) {throw "Incomplete P87 matrix: $size"}
    foreach ($frame in $report.frames) {
        if ($frame.size[0] -ne [int]$parts[0] -or $frame.size[1] -ne [int]$parts[1]) {throw "Invalid actual frame size: $size / $($frame.file)"}
    }
    Write-Output "P87 FULL GPU OK: $size, 20 frames"
}
