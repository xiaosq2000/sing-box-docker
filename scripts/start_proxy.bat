@echo off
set "SING_BOX_PATH=%cd%\sing-box.exe"
set "CONFIG_FILE=%cd%\trojan-client.json"

REM Configuration for restart
set "MAX_RESTART_TIME=5"
set "DELAY_SEC_RESTART=5"
set "RESTART_COUNT=0"

:RESTART
%SING_BOX_PATH% -c %CONFIG_FILE% run
REM Check if the maximum restart attempts have been reached
if %RESTART_COUNT% gtr %MAX_RESTART_TIME% (
    echo Maximum restart attempts reached. Exiting.
    exit /b 1
)

REM Check the exit code
if %ERRORLEVEL% neq 0 (
    echo Command failed. Restarting after %DELAY_SEC_RESTART% seconds...
    timeout /t %DELAY_SEC_RESTART% /nobreak >nul
    set /a "RESTART_COUNT+=1"
    goto RESTART
) else (
    echo Command executed successfully.
    exit /b 0
)

