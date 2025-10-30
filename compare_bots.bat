@echo off
echo ================================================================================
echo               ADAPTIVE BITCOIN BOT COMPARISON TOOL
echo ================================================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python from https://www.python.org/downloads/
    pause
    exit /b 1
)

REM Check if required packages are installed
python -c "import pandas" >nul 2>&1
if errorlevel 1 (
    echo Installing required packages...
    pip install pandas openpyxl
)

echo.
echo Please place both Excel files in this folder:
echo   1. Original bot results (e.g., original_Q4_2024.xlsx)
echo   2. ML-enhanced bot results (e.g., ml_enhanced_Q4_2024.xlsx)
echo.
echo Then drag and drop them onto this batch file, or:
echo.

REM If no arguments, ask for file names
if "%~1"=="" (
    echo Enter original bot Excel file name:
    set /p ORIGINAL_FILE="> "
    echo.
    echo Enter ML-enhanced bot Excel file name:
    set /p ML_FILE="> "
) else (
    set ORIGINAL_FILE=%~1
    set ML_FILE=%~2
)

REM Check if files exist
if not exist "%ORIGINAL_FILE%" (
    echo ERROR: Original file not found: %ORIGINAL_FILE%
    pause
    exit /b 1
)

if not exist "%ML_FILE%" (
    echo ERROR: ML-enhanced file not found: %ML_FILE%
    pause
    exit /b 1
)

echo.
echo Running comparison...
echo.

REM Run the Python comparison script
python compare_bots.py "%ORIGINAL_FILE%" "%ML_FILE%"

echo.
echo ================================================================================
echo.
pause
