@echo off
:: Do not run CHCP - it changes the caller’s code page.
title "%~nx0" "%~1"
cd /D "%~dp0"

rem distorted/reference file path with extension (.mkv, .mp4)
if "%~1"==""  exit /B 1
rem (option) output dir path ends without separator
::if "%~2"==""  exit /B 1
rem (option) output format
::if "%~3"==""  exit /B 1
rem (option) output suffix starts with dot
::if "%~4"==""  exit /B 1

set "TARGET=MediaInfo"
set "DEFAULT_FORMAT=JSON"
set "DEFAULT_SUFFIX=.%TARGET%.json"

set "TARGET_EXE=%TARGET%"
:: set your path of target application.
set "TARGET_PATH=%TARGET_EXE%"
where "%TARGET_EXE%" >nul 2>&1
if ERRORLEVEL 1 (
  if not exist "%TARGET_PATH%"  exit /B 1
)

call set "INPUT_FILE_PATH=%%~1"
call set "INPUT_FILENAME=%%~nx1"
call set "OUTPUT_DIR_PATH=%%~2"
if defined OUTPUT_DIR_PATH (
  call set "OUTPUT_DIR_PATH=%%OUTPUT_DIR_PATH%%\"
) else (
  call set "OUTPUT_DIR_PATH=%%~dp1"
)
set "OUTPUT_FORMAT=%~3"
if not defined OUTPUT_FORMAT (
  set "OUTPUT_FORMAT=%DEFAULT_FORMAT%"
)
set "OUTPUT_SUFFIX=%~4"
if not defined OUTPUT_SUFFIX (
  set "OUTPUT_SUFFIX=%DEFAULT_SUFFIX%"
)
call set "OUTPUT_FILENAME=%%INPUT_FILENAME%%%%OUTPUT_SUFFIX%%"
call set "OUTPUT_FILE_PATH=%%OUTPUT_DIR_PATH%%%%OUTPUT_FILENAME%%"
if "%OUTPUT_FILE_PATH%"=="%INPUT_FILE_PATH%" (
  echo [ERROR] Input and output paths are the same. Aborting to protect the input file.
  exit /B 1
)
set "OPTIONS="
set "OPTIONS=%OPTIONS% --Full"
set "OPTIONS=%OPTIONS% --Cover_Data=base64"
set "OPTIONS=%OPTIONS% --Output=%OUTPUT_FORMAT%"
set "OPTIONS=%OPTIONS% --LogFile="

setlocal EnableDelayedExpansion
set "COMMAND="!TARGET_PATH!" "!INPUT_FILE_PATH!" !OPTIONS!"!OUTPUT_FILE_PATH!""
!COMMAND!
endlocal

exit /B 0
goto :EOF
:: end of main