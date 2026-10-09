@echo off
chcp 65001 >nul
setlocal EnableExtensions
rem ============================================================
rem  rpgmap 启动脚本
rem  用法:
rem    play.bat                  默认主题(placeholder)启动游戏
rem    play.bat wilds            指定主题启动 (placeholder|dusk|wilds)
rem    play.bat --theme=wilds    等价写法
rem    play.bat --selftest       逻辑自测（自动用 console 版显示输出）
rem    play.bat --shots=DIR      截图验收
rem    play.bat farm             种植模块 Phase 0 拼接验证场景 (缺纹理自动生成)
rem  组合示例:
rem    play.bat wilds --shots=C:\tmp\shots
rem    play.bat farm --farm-shots=C:\tmp\farm_shots
rem
rem  说明：参数原样透传给游戏（含主题 id 识别，见 scripts/main.gd）；
rem        含空格的路径请加引号，或直接调用 godot 可执行文件。
rem ============================================================

rem 新机器可用环境变量覆盖引擎路径（或在下方直接改默认值）：
if not "%GODOT_EXE%"=="" set "GODOT=%GODOT_EXE%"
if not "%GODOT_EXE_CONSOLE%"=="" set "GODOT_CONSOLE=%GODOT_EXE_CONSOLE%"
if "%GODOT%"=="" set "GODOT=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64.exe"
if "%GODOT_CONSOLE%"=="" set "GODOT_CONSOLE=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe"
rem 追加 "." 规范化路径：%~dp0 结尾反斜杠会转义闭合引号
set "PROJECT=%~dp0."

if "%~1"=="/?" goto :usage
if /i "%~1"=="help" goto :usage

if not exist "%GODOT%" (
    echo [错误] 未找到 Godot: %GODOT%
    echo 请设置环境变量 GODOT_EXE / GODOT_EXE_CONSOLE，或修改本脚本默认路径。
    pause
    exit /b 1
)
if not exist "%PROJECT%\project.godot" (
    echo [错误] 未找到项目: %PROJECT%\project.godot
    pause
    exit /b 1
)

rem —— farming 模块（farm=当前主农场场景, farm0=Phase 0 历史验证场景）——
set "FSCENE="
if /i "%~1"=="farm" set "FSCENE=scenes/farming/farm_main.tscn"
if /i "%~1"=="farm0" set "FSCENE=scenes/farming/phase00_check.tscn"
if defined FSCENE goto :farm

rem 自测需要看到输出 → 用 console 版
set "EXE=%GODOT%"
echo %* | findstr /C:"--selftest" >nul && set "EXE=%GODOT_CONSOLE%"

"%EXE%" --path "%PROJECT%" -- %*
exit /b 0

:farm
rem   play.bat farm                    启动主农场场景（Phase 1：开垦/存档）
rem   play.bat farm0                   Phase 0 拼接验证场景（历史回归）
rem   play.bat farm --farmtest         逻辑自测
rem   play.bat farm --farm-shots=DIR   截图留档
rem   play.bat farm --fresh            忽略已有存档启动
set "FEXE=%GODOT%"
echo %* | findstr /C:"--farmtest" >nul && set "FEXE=%GODOT_CONSOLE%"
if not exist "%PROJECT%\assets\farming\ground\ground_grass.png" (
    echo [farm] 占位纹理缺失，先运行生成器...
    python "%PROJECT%\tools\farming\gen_farm_terrains.py" || (
        echo [错误] 纹理生成失败（需要 Python3 + Pillow）。
        exit /b 1
    )
)
if not exist "%PROJECT%\content\farming\baked\index.json" (
    echo [farm] 烘焙产物缺失，先运行 bake...
    python "%PROJECT%\tools\farming\bake_farm.py" || (
        echo [错误] 烘焙失败（检查 content/farming/ 源数据）。
        exit /b 1
    )
)
set "FARGS="
:farm_args
shift
if "%~1"=="" goto :farm_run
set "FARGS=%FARGS% "%~1""
goto :farm_args
:farm_run
"%FEXE%" --path "%PROJECT%" %FSCENE% -- %FARGS%
exit /b 0

:usage
echo rpgmap 启动脚本
echo   play.bat                  默认主题启动
echo   play.bat ^<theme^>          placeholder ^| dusk ^| wilds
echo   play.bat --selftest       逻辑自测
echo   play.bat --shots=DIR      截图到指定目录
echo   play.bat farm             种植模块主农场场景 (Phase 1: 开垦/存档)
echo   play.bat farm0            种植模块 Phase 0 拼接验证场景
echo   play.bat farm --farmtest  种植模块逻辑自测
exit /b 0
