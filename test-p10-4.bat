@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\farming\test_p104.ps1" %*
exit /b %errorlevel%
