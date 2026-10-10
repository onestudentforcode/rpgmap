@echo off
setlocal EnableExtensions
pushd "%~dp0" || exit /b 1
python tools/farming/bake_v1.py --check
if errorlevel 1 goto :failed
set "V1_GODOT=%GODOT_EXE_CONSOLE%"
if "%V1_GODOT%"=="" set "V1_GODOT=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%V1_GODOT%" goto :failed
"%V1_GODOT%" --headless --path . --script res://scripts/farming/tests/run_v1_foundation.gd
if errorlevel 1 goto :failed
popd
exit /b 0
:failed
echo V1 FOUNDATION SUITE FAILED
popd
exit /b 1
