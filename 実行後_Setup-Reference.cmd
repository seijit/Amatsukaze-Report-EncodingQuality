@echo off
cd /D "%~dp0"
call set "SHARED_AMT=%%~dp0Shared-Subroutine_Amt.cmd"
call set "$SETUP_VARS_OF_AMT=call "%%SHARED_AMT%%" :SETUP_VARS_OF_AMT"

:: 出力ファイルの拡張子を特定(%OUT_PATH%には拡張子が含まれない) 
%$SETUP_VARS_OF_AMT%
:: OUT_EXTENSION OUT_PATH_WITHOUT_EXTENSION
if ERRORLEVEL 1  exit /B %ERRORLEVEL%
if not exist "%OUT_PATH_WITHOUT_EXTENSION%%OUT_EXTENSION%" (
  echo [ERROR] Distorted file NOT exists..
  exit /B 1
)

:: リファレンスのパスを導出 
set "REFERENCE_SUFFIX=.lossless"
call set "REFERENCE_PATH=%%IN_DIR%%\%%IN_FILENAME%%%%REFERENCE_SUFFIX%%%%OUT_EXTENSION%%"
if exist "%REFERENCE_PATH%" (
  echo [ERROR] Reference file already exists..
  exit /B 1
)

setlocal EnableDelayedExpansion
echo([DEBUG] OUT_PATH: !OUT_PATH!
echo([DEBUG] OUT_PATH_WITHOUT_EXTENSION: !OUT_PATH_WITHOUT_EXTENSION!
echo([DEBUG] OUT_EXT: !OUT_EXT!
echo([DEBUG] OUT_EXTENSION: !OUT_EXTENSION!
echo([DEBUG] IN_PATH: !IN_PATH!
echo([DEBUG] REFERENCE_PATH: !REFERENCE_PATH!
endlocal

:: ロスレスでエンコードしたファイルをリファレンスのパスに移動 
echo [INFO] Moving file...
setlocal EnableDelayedExpansion
move "!OUT_PATH_WITHOUT_EXTENSION!!OUT_EXTENSION!" "!REFERENCE_PATH!"
endlocal
if ERRORLEVEL 1 (
  echo [ERROR] Failed to move file.
  exit /B 1
)
if not exist "%REFERENCE_PATH%" (
  echo [ERROR] Reference file does not exist.
  exit /B 1
)
echo [INFO] Reference file setup completed.

exit /B 0
goto :EOF
:: end of main