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
rem  组合示例:
rem    play.bat wilds --shots=C:\tmp\shots
rem
rem  说明：参数原样透传给游戏（含主题 id 识别，见 scripts/main.gd）；
rem        含空格的路径请加引号，或直接调用 godot 可执行文件。
rem ============================================================

set "GODOT=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64.exe"
set "GODOT_CONSOLE=C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe"
rem 追加 "." 规范化路径：%~dp0 结尾反斜杠会转义闭合引号
set "PROJECT=%~dp0."

if "%~1"=="/?" goto :usage
if /i "%~1"=="help" goto :usage

if not exist "%GODOT%" (
    echo [错误] 未找到 Godot: %GODOT%
    echo 请修改本脚本顶部的 GODOT 路径后重试。
    pause
    exit /b 1
)
if not exist "%PROJECT%\project.godot" (
    echo [错误] 未找到项目: %PROJECT%\project.godot
    pause
    exit /b 1
)

rem 自测需要看到输出 → 用 console 版
set "EXE=%GODOT%"
echo %* | findstr /C:"--selftest" >nul && set "EXE=%GODOT_CONSOLE%"

"%EXE%" --path "%PROJECT%" -- %*
exit /b 0

:usage
echo rpgmap 启动脚本
echo   play.bat                  默认主题启动
echo   play.bat ^<theme^>          placeholder ^| dusk ^| wilds
echo   play.bat --selftest       逻辑自测
echo   play.bat --shots=DIR      截图到指定目录
exit /b 0
