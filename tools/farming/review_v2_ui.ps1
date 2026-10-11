param([string]$GodotExe = $env:GODOT_EXE_CONSOLE)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GodotExe) { $GodotExe = 'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe' }
foreach ($resolution in @('2560x1440','1920x1080','1280x720','960x540')) {
    foreach ($scale in @(100,125,150)) {
        $name = "$resolution-$scale"
        $log = Join-Path $projectRoot ".art-work/ui-$name.log"
        & $GodotExe --path $projectRoot --resolution $resolution --log-file $log --script res://scripts/farming/tests/run_v2_ui_review.gd -- "--shots=res://.shots/phase07f/$name" "--shot-size=$resolution" "--ui-scale=$scale" *> "$log.stdout"
        $result = Get-Content -LiteralPath "$log.stdout" -Raw -Encoding UTF8
        if ($LASTEXITCODE -ne 0 -or $result -match 'SCRIPT ERROR:|ERROR:' -or $result -notmatch 'V2 UI REVIEW SHOTS OK') { throw "UI review failed: $name ($log)" }
        Write-Output "V2 UI MATRIX OK: $name"
    }
}
