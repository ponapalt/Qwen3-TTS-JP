@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title Qwen3-TTS-JP Setup

echo ============================================================
echo   Qwen3-TTS-JP  -  Windows Auto Setup
echo ============================================================
echo.

cd /d "%~dp0"

REM ============================================================
REM  1. Python check
REM ============================================================
echo [1/5] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python was not found.
    echo         Please install Python 3.10 or higher and retry.
    echo         https://www.python.org/downloads/
    goto :error
)

for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
for /f "tokens=1,2 delims=." %%a in ("!PY_VER!") do (
    set PY_MAJOR=%%a
    set PY_MINOR=%%b
)

if !PY_MAJOR! LSS 3 (
    echo [ERROR] Python 3.10 or higher is required. Found: !PY_VER!
    goto :error
)
if !PY_MAJOR! EQU 3 if !PY_MINOR! LSS 10 (
    echo [ERROR] Python 3.10 or higher is required. Found: !PY_VER!
    goto :error
)
echo [OK] Python !PY_VER!

REM ============================================================
REM  2. Virtual environment
REM ============================================================
echo.
echo [2/5] Setting up virtual environment...
if not exist ".venv\Scripts\activate.bat" (
    echo       Creating .venv ...
    python -m venv .venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        goto :error
    )
    echo [OK] .venv created.
) else (
    echo [OK] .venv already exists. Skipping creation.
)

call .venv\Scripts\activate.bat
python -m pip install --upgrade pip --quiet

REM ============================================================
REM  3. GPU detection (RTX 50 series = Blackwell / sm_120)
REM ============================================================
echo.
echo [3/5] Detecting GPU...
set IS_RTX50=0

nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo [WARN] nvidia-smi not found. Will use stable CUDA 12.4 build.
    echo        If you have a GPU, make sure the NVIDIA driver is installed.
) else (
    REM Check if --query-gpu is supported (requires CUDA 7+ driver)
    nvidia-smi --query-gpu=name --format=csv,noheader >nul 2>&1
    if not errorlevel 1 (
        REM Modern nvidia-smi: use --query-gpu
        for /f "usebackq delims=" %%g in (`nvidia-smi --query-gpu=name --format=csv,noheader 2^>nul`) do (
            echo       Detected: %%g
            echo %%g | findstr /i "5090\|5080\|5070\|5060\|5050" >nul 2>&1
            if not errorlevel 1 set IS_RTX50=1
        )
    ) else (
        REM Older nvidia-smi: fall back to nvidia-smi -L
        REM Output format: "GPU 0: <name> (UUID: GPU-...)"
        for /f "usebackq tokens=1,* delims=:" %%a in (`nvidia-smi -L 2^>nul`) do (
            for /f "usebackq tokens=1 delims=(" %%c in ("%%b") do (
                echo       Detected:%%c
                echo %%c | findstr /i "5090\|5080\|5070\|5060\|5050" >nul 2>&1
                if not errorlevel 1 set IS_RTX50=1
            )
        )
    )
)

if "!IS_RTX50!"=="1" (
    echo [OK] RTX 50 series ^(Blackwell^) detected.
    echo      PyTorch nightly ^(cu128^) will be installed for sm_120 support.
) else (
    echo [OK] Using stable PyTorch ^(CUDA 12.4^).
)

REM ============================================================
REM  4. Install project dependencies
REM ============================================================
echo.
echo [4/5] Installing dependencies...

echo       pip install -e . ...
pip install -e . --quiet
if errorlevel 1 (
    echo [ERROR] pip install -e . failed.
    goto :error
)

echo       pip install faster-whisper ...
pip install faster-whisper --quiet
if errorlevel 1 (
    echo [ERROR] Failed to install faster-whisper.
    goto :error
)

if "!IS_RTX50!"=="1" (
    echo       Installing PyTorch nightly ^(cu128^) for RTX 50 series...
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
) else (
    echo       Installing PyTorch stable ^(cu124^)...
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
)
if errorlevel 1 (
    echo [ERROR] Failed to install PyTorch.
    goto :error
)

echo [OK] All dependencies installed.

REM ============================================================
REM  5. Verify environment
REM ============================================================
echo.
echo [5/5] Verifying environment...
python -c ^
"import torch; ^
print('  PyTorch :', torch.__version__); ^
print('  CUDA    :', torch.version.cuda); ^
avail = torch.cuda.is_available(); ^
print('  CUDA OK :', avail); ^
[print('  GPU     :', torch.cuda.get_device_name(i)) for i in range(torch.cuda.device_count())] if avail else None"

if errorlevel 1 (
    echo [WARN] Verification script failed. Setup may still be usable.
)

echo.
echo ============================================================
echo   Setup complete!
echo ============================================================
echo.
echo   You can start the application anytime by double-clicking:
echo     Qwen3-TTS-JP.bat
echo.

set /p LAUNCH="Launch Qwen3-TTS-JP now? [Y/n]: "
if /i "!LAUNCH!"=="n" goto :end
if /i "!LAUNCH!"=="no" goto :end

echo.
call "%~dp0Qwen3-TTS-JP.bat"
goto :end

:error
echo.
echo ============================================================
echo   Setup failed. Please check the error messages above.
echo ============================================================
echo.
pause
exit /b 1

:end
endlocal
