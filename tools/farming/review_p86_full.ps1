param([string]$GodotExe=$env:GODOT_EXE_CONSOLE)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) {$GodotExe='C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe'}
$out=Join-Path $projectRoot '.art-work/p86-final-visual'
New-Item -ItemType Directory -Force -Path $out | Out-Null
foreach($size in @('2560x1440','1920x1080','960x540')) {
    $log=Join-Path $out ($size+'.log')
    & $GodotExe --path $projectRoot --log-file $log --script res://scripts/farming/validation/p86_full_visual_preview.gd -- "--p86-full-dir=res://.art-work/p86-final-visual/$size" "--shot-size=$size" --ui-scale=100 *> (Join-Path $out ($size+'.stdout.log'))
    $result=Get-Content -LiteralPath $log -Raw -Encoding UTF8
    if($LASTEXITCODE -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:' -or $result -notmatch 'P86 FULL VISUAL PREVIEW OK') {throw "GPU matrix failed: $log"}
    Write-Output "P86 FULL GPU OK: $size"
}
