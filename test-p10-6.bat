@echo off
rem P10.6 entry: Model by default; full chain with the replay, receipt audit
rem and tamper probes. -SkipPlaytest runs the seconds-level checks only,
rem -AuditExisting re-audits existing evidence without replaying.
setlocal
set GODOT_EXE_CONSOLE=%GODOT_EXE_CONSOLE%
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/test_p106.ps1 %*
endlocal
