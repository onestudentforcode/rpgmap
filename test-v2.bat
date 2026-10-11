@echo off
setlocal EnableExtensions
pushd "%~dp0" || exit /b 1
python tools/farming/bake_v2.py --check
if errorlevel 1 goto :failed
python tools/farming/test_v2_foundation.py
if errorlevel 1 goto :failed
set "V2_GODOT=%GODOT_EXE_CONSOLE%"
if "%V2_GODOT%"=="" set "V2_GODOT=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%V2_GODOT%" goto :failed
if not exist ".art-work" mkdir .art-work
"%V2_GODOT%" --headless --path . --script res://scripts/farming/tests/run_phase07a.gd
if errorlevel 1 goto :failed
"%V2_GODOT%" --headless --path . --script res://scripts/farming/tests/run_v2_startup_ledger.gd
if errorlevel 1 goto :failed
"%V2_GODOT%" --headless --path . res://scenes/farming/farm_v2.tscn -- --v2-smoke
if errorlevel 1 goto :failed
echo V2 P7.a SUITE OK
popd
exit /b 0
:failed
popd
exit /b 1
