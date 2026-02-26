:: for Amatsukaze
@echo off
:: Do not remove the chcp command.
chcp 932 > nul

set "OUT_EXTENSIONS=.mkv .mp4 .m2ts .ts"
set "PREFIX_OF_BATCH_AMT=追加時_ 実行前_ エンコード前_ 実行後_ キュー完了後_"
set "CODEPAGE_FOR_ECHO_IN_CONSOLE_OF_AMT=932"

call %%*
exit /B %ERRORLEVEL%
goto :EOF
:: end of main


:SETUP_VARS_OF_AMT
  :: OUT_EXTENSION に出力ファイルの拡張子をセット 
  :: OUT_PATH_WITHOUT_EXTENSION に拡張子抜きの出力ファイルのパスをセット 
  :: REFERENCE_PATH にリファレンスファイルのパスをセット 
  :: 既存の変数は変更しない 

  if "%IN_PATH%"==""  echo [ERROR] IN_PATH variable missing. & exit /B 1
  if "%OUT_PATH%"==""  echo [ERROR] OUT_PATH variable missing. & exit /B 1

  set "REFERENCE_SUFFIX=.lossless"
  if defined OUT_EXT if exist "%OUT_PATH%%OUT_EXT%" (
    call set "OUT_EXTENSION=%%OUT_EXT%%"
    call set "OUT_PATH_WITHOUT_EXTENSION=%%OUT_PATH%%"
    call set "REFERENCE_PATH=%%IN_DIR%%\%%IN_FILENAME%%%%REFERENCE_SUFFIX%%%%OUT_EXTENSION%%"
    exit /B 0
  )
  for %%e in (%OUT_EXTENSIONS%) do (
    if exist "%OUT_PATH%%%e" (
      if "%OUT_PATH%%%e"=="%IN_PATH%"  exit /B 1
      call set "OUT_EXTENSION=%%%e"
      call set "OUT_PATH_WITHOUT_EXTENSION=%%OUT_PATH%%"
      call set "REFERENCE_PATH=%%IN_DIR%%\%%IN_FILENAME%%%%REFERENCE_SUFFIX%%%%OUT_EXTENSION%%"
      exit /B 0
    )
  )
  if exist "%OUT_PATH_WITHOUT_EXTENSION%%OUT_EXTENSION%" (
    exit /B 0
  )

  echo [ERROR] Output file not found.
  exit /B 1

:DEBUG_PRINT
  setlocal EnableDelayedExpansion

  echo([DEBUG] OUT_PATH: !OUT_PATH!
  echo([DEBUG] OUT_PATH_WITHOUT_EXTENSION: !OUT_PATH_WITHOUT_EXTENSION!
  echo([DEBUG] OUT_EXT: !OUT_EXT!
  echo([DEBUG] OUT_EXTENSION: !OUT_EXTENSION!
  echo([DEBUG] IN_PATH: !IN_PATH!
  echo([DEBUG] REFERENCE_PATH: !REFERENCE_PATH!
  echo([DEBUG] PS_PATH: !PS_PATH!

  endlocal & exit /B 0

:VALIDATE_ITEM_MODE
  setlocal EnableDelayedExpansion

  if "%ITEM_MODE%"==""  echo [ERROR] Amatsukaze batch is not running. & exit /B 1
  if "%ITEM_MODE%"=="DrcsCheck"  echo [ERROR] Drcs Check mode is running. & exit /B 1
  if "%ITEM_MODE%"=="CMCheck"  echo [ERROR] CM Check mode is running. & exit /B 1

  endlocal & exit /B 0

:get_powershell_script_path
  :: 例: 実行後_Report-EncodingQuality.cmd -> Report-EncodingQuality.ps1 
  setlocal EnableDelayedExpansion

    if "%~1"==""  exit /B 1
    if "%~2"==""  exit /B 1
    set "exit_code=0"

    set "ps_path=%~n1"
    call :get_prefix_of_batch "%%ps_path%%" "prefix_of_batch"
    call set "ps_path=%%ps_path:%prefix_of_batch%=%%"
    set "ps_path=%~dp0%ps_path%.ps1"
    if not exist "%ps_path%" (
      echo/[ERROR] PowerShell script not found: %ps_path%
      exit /B 1
    )

  endlocal & set "%~2=%ps_path%" & exit /B %exit_code%

:get_prefix_of_batch
  setlocal EnableDelayedExpansion

    if "%~1"==""  exit /B 1
    if "%~2"==""  exit /B 1
    set "exit_code=0"

    for %%a in (%PREFIX_OF_BATCH_AMT%) do (
      set "prefix_of_batch="
      call :get_longest_common_prefix "%%~1" "%%a" "prefix_of_batch"
      if defined prefix_of_batch (
        call set "last_char=%%prefix_of_batch:~-1,1%%"
        if "!last_char!"=="_" goto :endlocal
      )
    )
    set "prefix_of_batch="
    set "exit_code=1"

    :endlocal
  endlocal & set "%~2=%prefix_of_batch%" & exit /B %exit_code%

:get_longest_common_prefix
  setlocal EnableDelayedExpansion

    if "%~1"==""  exit /B 1
    if "%~2"==""  exit /B 1
    if "%~3"==""  exit /B 1
    set "exit_code=0"

    set "string1=%~1"
    set "string2=%~2"
    set "prefix="

    :loop__get_longest_common_prefix
      if "%string1%"=="" goto :endlocal
      if "%string2%"=="" goto :endlocal

      set "char1=%string1:~0,1%"
      set "char2=%string2:~0,1%"

      if not "%char1%"=="%char2%" goto :endlocal

      set "prefix=%prefix%%char1%"
      set "string1=%string1:~1%"
      set "string2=%string2:~1%"
      goto :loop__get_longest_common_prefix

    :endlocal
  endlocal & set "%~3=%prefix%" & exit /B %exit_code%

:echo_in_sjis
  setlocal EnableDelayedExpansion

    set "exit_code=0"
    set "codepage_for_echo=932"
    call :get_codepage_original "codepage_original"
    chcp %codepage_for_echo% > nul
    call echo(%%*
    chcp %codepage_original% > nul

  endlocal & exit /B %exit_code%

:get_codepage_original
  setlocal EnableDelayedExpansion

    if "%~1"==""  exit /B 1
    set "exit_code=0"

    for /f "tokens=2 delims=:" %%a in ('chcp') do (
      set "codepage_original=%%a"
    )
    set "codepage_original=%codepage_original: =%"

  endlocal & set "%~1=%codepage_original%" & exit /B %exit_code%