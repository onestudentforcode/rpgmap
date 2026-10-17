@echo off
setlocal EnableExtensions
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\farming\test_p10.ps1" %*
exit /b %errorlevel%
