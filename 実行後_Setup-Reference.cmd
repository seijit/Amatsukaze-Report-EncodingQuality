@echo off
cd /D "%~dp0"
call set "SHARED_AMT=%%~dp0Shared-Subroutine_Amt.cmd"
call set "$SETUP_VARS_OF_AMT=call "%%SHARED_AMT%%" :SETUP_VARS_OF_AMT"
call set "$DEBUG_PRINT=call "%%SHARED_AMT%%" :DEBUG_PRINT"
call set "$VALIDATE_ITEM_MODE=call "%%SHARED_AMT%%" :VALIDATE_ITEM_MODE"

:: 出力ファイルの拡張子を特定(%OUT_PATH%には拡張子が含まれない) 
%$SETUP_VARS_OF_AMT%
:: OUT_EXTENSION OUT_PATH_WITHOUT_EXTENSION REFERENCE_PATH
if ERRORLEVEL 1  exit /B %ERRORLEVEL%

call %$DEBUG_PRINT%
call %$VALIDATE_ITEM_MODE%
if ERRORLEVEL 1  exit /B %ERRORLEVEL%

:: ロスレスでエンコードされたファイルをリファレンスのパスに移動 
if exist "%REFERENCE_PATH%" (
  echo [ERROR] Reference path already exists..
  exit /B 1
)
echo [INFO] Moving file...
setlocal EnableDelayedExpansion
move "!OUT_PATH_WITHOUT_EXTENSION!!OUT_EXTENSION!" "!REFERENCE_PATH!"
if ERRORLEVEL 1 (
  echo [ERROR] Failed to move file.
  exit /B 1
)
endlocal
if not exist "%REFERENCE_PATH%" (
  echo [ERROR] Reference file does not exist.
  exit /B 1
)
echo [INFO] Reference file setup completed.

exit /B 0
goto :EOF
:: end of main