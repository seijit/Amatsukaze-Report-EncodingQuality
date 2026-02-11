@echo off
chcp 65001 > nul

call set "PS_PATH=%%~n0"
call title "%%PS_PATH%%"
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0%PS_PATH%.ps1" %*

pause