@echo off
echo ================================================================================
echo           COPY ML-ENHANCED BOT TO MT5
echo ================================================================================
echo.

REM Find MT5 Common Data folder
set MT5_COMMON=%APPDATA%\MetaQuotes\Terminal\Common

REM Find MT5 Terminal folders
set MT5_BASE=%APPDATA%\MetaQuotes\Terminal

echo Looking for MT5 installation...
echo.

if not exist "%MT5_BASE%" (
    echo ERROR: MT5 not found at %MT5_BASE%
    echo.
    echo Please manually locate your MT5 folder and copy these files:
    echo   1. Adaptive_Bitcoin_ML_Enhanced.mq5 → MQL5\Experts\
    echo   2. Random Forest.mqh → MQL5\Include\
    echo   3. BTCUSD.PERIOD_D1.cluster-centroids.onnx → Common\Files\
    pause
    exit /b 1
)

echo Found MT5 folder: %MT5_BASE%
echo.

REM Copy ONNX model to Common\Files
echo Copying ONNX model to Common\Files...
if not exist "%MT5_COMMON%\Files" mkdir "%MT5_COMMON%\Files"
copy /Y "Common\Files\BTCUSD.PERIOD_D1.cluster-centroids.onnx" "%MT5_COMMON%\Files\" >nul
if errorlevel 1 (
    echo   ERROR: Failed to copy ONNX model
) else (
    echo   SUCCESS: ONNX model copied
)

REM Find all terminal instances (user might have multiple)
echo.
echo Copying bot and include files to all MT5 instances...
echo.

set COPIED=0

for /d %%G in ("%MT5_BASE%\*") do (
    if exist "%%G\MQL5" (
        echo Found MT5 instance: %%~nxG

        REM Copy Expert Advisor
        if not exist "%%G\MQL5\Experts" mkdir "%%G\MQL5\Experts"
        copy /Y "Adaptive_Bitcoin_ML_Enhanced.mq5" "%%G\MQL5\Experts\" >nul
        if errorlevel 1 (
            echo   ERROR: Failed to copy EA
        ) else (
            echo   SUCCESS: EA copied to %%G\MQL5\Experts\
        )

        REM Copy Include file
        if not exist "%%G\MQL5\Include" mkdir "%%G\MQL5\Include"
        copy /Y "Include\Random Forest.mqh" "%%G\MQL5\Include\" >nul
        if errorlevel 1 (
            echo   ERROR: Failed to copy include file
        ) else (
            echo   SUCCESS: Include file copied to %%G\MQL5\Include\
        )

        set /a COPIED+=1
        echo.
    )
)

if %COPIED%==0 (
    echo ERROR: No MT5 MQL5 folders found!
    echo.
    echo Please manually copy files:
    echo   From: %CD%
    echo   To: Your MT5 installation folder
    pause
    exit /b 1
)

echo ================================================================================
echo                         COPY COMPLETE!
echo ================================================================================
echo.
echo Files copied successfully to %COPIED% MT5 instance(s)
echo.
echo NEXT STEPS:
echo   1. Open MT5
echo   2. Press F4 (opens MetaEditor)
echo   3. Navigate to Experts → Adaptive_Bitcoin_ML_Enhanced.mq5
echo   4. Click "Compile" button (or F7)
echo   5. Should compile with no errors
echo.
echo Then the bot will appear in your Navigator under "Expert Advisors"
echo.
pause
