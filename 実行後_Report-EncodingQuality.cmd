@echo off
cd /D "%~dp0"
call set "SHARED_AMT=%%~dp0Shared-Subroutine_Amt.cmd"
call set "$SETUP_VARS_OF_AMT=call "%%SHARED_AMT%%" :SETUP_VARS_OF_AMT"
call set "$DEBUG_PRINT=call "%%SHARED_AMT%%" :DEBUG_PRINT"
call set "$VALIDATE_ITEM_MODE=call "%%SHARED_AMT%%" :VALIDATE_ITEM_MODE"
call set "$get_powershell_script_path=call "%%SHARED_AMT%%" :get_powershell_script_path"

:: 出力ファイルの拡張子を特定(%OUT_PATH%には拡張子が含まれない) 
%$SETUP_VARS_OF_AMT%
:: OUT_EXTENSION OUT_PATH_WITHOUT_EXTENSION REFERENCE_PATH
if ERRORLEVEL 1  exit /B %ERRORLEVEL%

:: PowerShell Core (pwsh) の存在確認 
call :NEED_POWERSHELL_CORE_7
if ERRORLEVEL 1  exit /B %ERRORLEVEL%

:: PowerShellスクリプトのパスを導出 
%$get_powershell_script_path% "%%~0" "PS_PATH"
:: PS_PATH
if ERRORLEVEL 1  exit /B %ERRORLEVEL%

call %$DEBUG_PRINT%
call %$VALIDATE_ITEM_MODE%
if ERRORLEVEL 1  exit /B %ERRORLEVEL%

setlocal EnableDelayedExpansion

:: extra
call ".\Get-MediaInfo.cmd" "%%OUT_PATH_WITHOUT_EXTENSION%%%%OUT_EXTENSION%%" >nul
call ".\Get-MediaInfo.cmd" "%%IN_PATH%%" "%%OUT_DIR%%" >nul
::call ".\Get-MediaInfo.cmd" "%%OUT_PATH_WITHOUT_EXTENSION%%%%OUT_EXTENSION%%" "%%OUT_DIR%%" "HTML" ".MediaInfo.html" >nul
::call ".\Get-MediaInfo.cmd" "%%IN_PATH%%" "%%OUT_DIR%%" "HTML" ".MediaInfo.html" >nul

:: PowerShellの起動 （-NoExit を pwsh の引数に追加すれば、コマンドプロンプトが閉じない） 
:: -OutputDirPath : レポート出力先フォルダを変更する。未指定時は評価対象と同じフォルダ 
:: -SaveSsimu2Json : FFVshipのJSONをファイル出力する 
:: -SaveReportJson : レポートのJSONをファイル出力する 
:: -UniqueOutputName : 出力ファイル名にタイムスタンプを付与する 
start "Encoding Quality Report" /MIN pwsh -NoProfile -ExecutionPolicy Bypass -File "!PS_PATH!" -DistortedFilePathBase "!OUT_PATH_WITHOUT_EXTENSION!!OUT_EXTENSION!" -SourceFilePath "!IN_PATH!" -SaveSsimu2Json:$false -SaveReportJson:$false
echo [INFO] Invoked Encoding Quality Report script...

endlocal

exit /B 0
goto :EOF
:: end of main


:NEED_POWERSHELL_CORE_7

  where pwsh >nul 2>&1
  if ERRORLEVEL 1 (
    echo [ERROR] PowerShell Core pwsh command not found in PATH.
    exit /B 1
  )

  exit /B 0