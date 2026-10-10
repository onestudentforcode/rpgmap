@echo off
chcp 65001 >nul
setlocal EnableExtensions
pushd "%~dp0" || exit /b 1
echo [test 1/4] Current farming asset QC
python tools/farming/qc_assets.py --target all
if errorlevel 1 goto :failed
echo [test 2/4] Current farming tools and V1 config
python -m unittest discover -s tools/farming -p test_*.py -v
if errorlevel 1 goto :failed
echo [test 3/4] Current farming game flow
call play.bat farm --farmtest
if errorlevel 1 goto :failed
echo [test 4/4] Independent V1 foundation
call test-v1.bat
if errorlevel 1 goto :failed
echo FARMING TEST SUITE OK
popd
exit /b 0
:failed
echo FARMING TEST SUITE FAILED
popd
exit /b 1
