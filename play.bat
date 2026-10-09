@echo off
chcp 65001 >nul
setlocal EnableExtensions
rem Default entry and --selftest belong to the current farming module.
rem Legacy content requires explicit demo or farm0 selection.
if "%~1"=="/?" goto :usage
if /i "%~1"=="help" goto :usage
set "PROJECT=%~dp0."
set "MODE=farm"
set "SCENE=scenes/farming/farm_demo.tscn"
if /i "%~1"=="demo" goto :select_demo
if /i "%~1"=="farm0" goto :select_farm0
if /i "%~1"=="farm" goto :select_farm
if "%~1"=="" goto :args
set "FIRST=%~1"
if "%FIRST:~0,2%"=="--" goto :args
echo [error] Unknown entry: %~1. Use play.bat demo %~1 for a legacy theme.
exit /b 2
:select_farm
set "SCENE=scenes/farming/farm_main.tscn"
goto :consume_mode
:select_demo
set "MODE=demo"
set "SCENE=scenes/main.tscn"
goto :consume_mode
:select_farm0
set "MODE=farm0"
set "SCENE=scenes/farming/phase00_check.tscn"
:consume_mode
shift
:args
set "FARGS="
set "CONSOLE="
set "HEADLESS="
:next_arg
if "%~1"=="" goto :launch
set "ARG=%~1"
if /i "%ARG%"=="--selftest" if not "%MODE%"=="demo" set "ARG=--farmtest"
if /i "%ARG%"=="--farmtest" if "%MODE%"=="farm" set "SCENE=scenes/farming/farm_main.tscn"
if /i "%ARG:~0,8%"=="--shots=" if "%MODE%"=="farm" set "SCENE=scenes/farming/farm_main.tscn"
if /i "%ARG:~0,13%"=="--farm-shots=" if "%MODE%"=="farm" set "SCENE=scenes/farming/farm_main.tscn"
if /i "%ARG%"=="--shots" if "%MODE%"=="farm" set "SCENE=scenes/farming/farm_main.tscn"
if /i "%ARG%"=="--farm-shots" if "%MODE%"=="farm" set "SCENE=scenes/farming/farm_main.tscn"
if /i "%ARG%"=="--fresh" if "%MODE%"=="farm" set "SCENE=scenes/farming/farm_main.tscn"
if /i "%ARG%"=="--selftest" set "CONSOLE=1"
if /i "%ARG%"=="--selftest" set "HEADLESS=--headless"
if /i "%ARG%"=="--farmtest" set "CONSOLE=1"
if /i "%ARG%"=="--farmtest" set "HEADLESS=--headless"
if /i "%ARG:~0,8%"=="--shots=" set "CONSOLE=1"
if /i "%ARG:~0,13%"=="--farm-shots=" set "CONSOLE=1"
if /i "%ARG%"=="--shots" set "CONSOLE=1"
if /i "%ARG%"=="--farm-shots" set "CONSOLE=1"
set "FARGS=%FARGS% "%ARG%""
shift
goto :next_arg
:launch
set "GODOT=%GODOT_EXE%"
set "GODOT_CONSOLE=%GODOT_EXE_CONSOLE%"
if "%GODOT%"=="" set "GODOT=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64.exe"
if "%GODOT_CONSOLE%"=="" set "GODOT_CONSOLE=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe"
set "EXE=%GODOT%"
if defined CONSOLE set "EXE=%GODOT_CONSOLE%"
if not exist "%EXE%" (
    echo [error] Godot not found: %EXE%. Set GODOT_EXE / GODOT_EXE_CONSOLE.
    exit /b 1
)
if not exist "%PROJECT%\project.godot" exit /b 1
if "%MODE%"=="demo" goto :run
if not exist "%PROJECT%\content\farming\baked\index.json" (
    python "%PROJECT%\tools\farming\bake_farm.py" || exit /b 1
)
if not exist "%PROJECT%\assets\farming\ground\ground_grass.png" (
    echo [error] Farming assets missing. Restore delivered assets before running.
    exit /b 1
)
:run
"%EXE%" %HEADLESS% --path "%PROJECT%" %SCENE% -- %FARGS%
exit /b %errorlevel%
:usage
echo play.bat                         Farming Demo menu with three slots
echo play.bat --selftest               Current farm logic test, headless
echo play.bat --shots=DIR              Current farm screenshots
echo play.bat farm --farmtest          Same current farm logic test
echo play.bat farm --fresh             Unsaved developer preview only
echo play.bat farm --farm-shots=DIR    Same current farm screenshots
echo play.bat demo wilds              Legacy demo, explicit opt-in
echo play.bat demo --selftest          Legacy demo tests only
echo play.bat farm0 --farmtest         Historical Phase 0 tests only
echo test.bat                         Farming QC + tool tests + game flow
exit /b 0
