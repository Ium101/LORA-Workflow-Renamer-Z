@echo off
setlocal enabledelayedexpansion
title LoRA Workflow Renamer Z — Build (Windows)

:: ============================================================
::  build.bat — Builds LoRA_Workflow_Renamer_Z.exe with PyInstaller
::
::  Single-file, GUI-only edition: lora_workflow_renamer_z.py contains
::  the renaming logic, the Tkinter GUI, and the built-in icon
::  (embedded as base64 inside the script — no external .ico asset
::  file is needed). Only one executable is produced (the GUI).
::
::  Icon embedding note: the icon is extracted at build time via
::  "lora_workflow_renamer_z.py --extract-icons" and fed to PyInstaller's
::  --icon flag. The embedded .ico MUST use classic BMP/DIB-encoded
::  entries, not PNG-compressed ones — PyInstaller's Windows icon step
::  copies the raw bytes straight into the .exe's icon resource with
::  no validation, and PNG-compressed entries silently produce an exe
::  (and therefore shortcuts) with a broken/invisible icon.
::
::  Shortcuts: Desktop and Start Menu shortcuts are created with a
::  display name that uses spaces ("LoRA Workflow Renamer Z"), not
::  underscores — only the .exe's own filename keeps underscores.
::  If shortcut (.lnk) creation isn't available on a given machine,
::  a plain .bat launcher is created instead as a fallback.
::
::  .venv cleanup: deletion is retried a few times with short pauses,
::  then handed off to a background script if still locked (e.g. by
::  antivirus scanning freshly-written files), so the build can never
::  hang waiting on a file lock.
::
::  Output: LoRA_Workflow_Renamer_Z.exe (same folder as this script)
:: ============================================================

echo.
echo  ============================================
echo   LoRA Workflow Renamer Z  ^|  Windows Build Script
echo  ============================================
echo.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: ── 1. Find Python and resolve its full absolute path ─────────
set PYTHON_EXE=
set _TMPFILE=%TEMP%\lwrz_python_path_%RANDOM%.txt

goto :skip_resolve_sub

:resolve_python
    %1 -c "import sys,os; f=open(r'%_TMPFILE%','w'); f.write(os.path.abspath(sys.executable)); f.close()" >nul 2>&1
    if errorlevel 1 goto :eof
    if not exist "%_TMPFILE%" goto :eof
    set /p PYTHON_EXE=<"%_TMPFILE%"
    del /q "%_TMPFILE%" >nul 2>&1
    for /f "tokens=* delims= " %%X in ("!PYTHON_EXE!") do set PYTHON_EXE=%%X
    goto :eof

:skip_resolve_sub

where py >nul 2>&1
if not errorlevel 1 (
    call :resolve_python py
    if defined PYTHON_EXE if exist "!PYTHON_EXE!" goto :found_python
    set PYTHON_EXE=
)

where python >nul 2>&1
if not errorlevel 1 (
    call :resolve_python python
    if defined PYTHON_EXE if exist "!PYTHON_EXE!" goto :found_python
    set PYTHON_EXE=
)

where python3 >nul 2>&1
if not errorlevel 1 (
    call :resolve_python python3
    if defined PYTHON_EXE if exist "!PYTHON_EXE!" goto :found_python
    set PYTHON_EXE=
)

for %%D in (
    "%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
    "C:\Python314\python.exe"
    "C:\Python313\python.exe"
    "C:\Python312\python.exe"
    "C:\Python311\python.exe"
    "C:\Python310\python.exe"
    "%ProgramFiles%\Python314\python.exe"
    "%ProgramFiles%\Python313\python.exe"
    "%ProgramFiles%\Python312\python.exe"
    "%ProgramFiles%\Python311\python.exe"
    "%ProgramFiles%\Python310\python.exe"
) do (
    if exist %%D (
        set PYTHON_EXE=%%~D
        goto :found_python
    )
)

echo  [ERROR] Python 3.10+ not found.
echo.
echo          Please install Python from https://python.org/downloads
echo          During install check "Add Python to PATH".
echo.
del /q "%_TMPFILE%" >nul 2>&1
pause & exit /b 1

:found_python
del /q "%_TMPFILE%" >nul 2>&1

if not defined PYTHON_EXE (
    echo  [ERROR] PYTHON_EXE is empty after resolution.
    pause & exit /b 1
)
if not exist "%PYTHON_EXE%" (
    echo  [ERROR] Resolved Python path does not exist: %PYTHON_EXE%
    pause & exit /b 1
)

"%PYTHON_EXE%" -c "print(1)" >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python executable found but fails to run: %PYTHON_EXE%
    pause & exit /b 1
)

for /f "tokens=*" %%v in ('"%PYTHON_EXE%" --version 2^>^&1') do set PY_VER=%%v
echo  [OK] %PY_VER%
echo  [OK] Executable: %PYTHON_EXE%
echo.

:: ── 2. Check source file ─────────────────────────────────────
if not exist "lora_workflow_renamer_z.py" (
    echo  [ERROR] lora_workflow_renamer_z.py not found in current directory.
    echo          Run this script from the folder containing your .py file.
    pause & exit /b 1
)
echo  [OK] Source file found.
echo.

:: ── 3. Virtual environment ────────────────────────────────────
echo  [STEP 1/6] Virtual environment...

if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -c "print(1)" >nul 2>&1
    if errorlevel 1 (
        echo  [!!] Existing .venv is broken ^(health-check failed^) — recreating...
        rmdir /s /q ".venv" >nul 2>&1
        goto :create_venv
    ) else (
        echo  [OK] Reusing healthy .venv
        goto :venv_ready
    )
)

:create_venv
echo  [..] Creating .venv with: %PYTHON_EXE%
"%PYTHON_EXE%" -m venv .venv
if errorlevel 1 (
    echo  [ERROR] venv creation failed.
    pause & exit /b 1
)

".venv\Scripts\python.exe" -c "print(1)" >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Newly created .venv\Scripts\python.exe fails to run.
    echo          Your Python installation may be incomplete.
    pause & exit /b 1
)
echo  [OK] Created .venv

:venv_ready
set VENV_PY=.venv\Scripts\python.exe
echo  [OK] Using: %VENV_PY%
echo.

:: ── 4. Install dependencies ───────────────────────────────────
echo  [STEP 2/6] Installing PyInstaller and dependencies...

"%VENV_PY%" -m pip install --quiet --upgrade pip
if errorlevel 1 (
    echo  [ERROR] pip upgrade failed.
    pause & exit /b 1
)

"%VENV_PY%" -m pip install --quiet --upgrade pyinstaller pillow
if errorlevel 1 (
    echo  [ERROR] Failed to install dependencies.
    pause & exit /b 1
)

set PYINST=.venv\Scripts\pyinstaller.exe
if not exist "%PYINST%" (
    echo  [ERROR] .venv\Scripts\pyinstaller.exe not found after install.
    pause & exit /b 1
)

for /f "tokens=*" %%v in ('"%PYINST%" --version 2^>^&1') do set PYINST_VER=%%v
echo  [OK] PyInstaller %PYINST_VER% ready.
echo.

:: ── 5. Extract built-in icon ───────────────────────────────────
echo  [STEP 3/6] Extracting built-in icon...

set "ICON_DIR=%TEMP%\lwrz_icon_%RANDOM%"
"%VENV_PY%" "lora_workflow_renamer_z.py" --extract-icons "%ICON_DIR%"
if errorlevel 1 (
    echo  [ERROR] Icon extraction failed.
    pause & exit /b 1
)
if not exist "%ICON_DIR%\lora_workflow_renamer_z.ico" (
    echo  [ERROR] Extracted .ico icon not found.
    pause & exit /b 1
)
echo  [OK] Icon extracted to: %ICON_DIR%
echo.

:: ── 6. Safe clean ─────────────────────────────────────────────
echo  [STEP 4/6] Cleaning previous build artefacts...
if exist "build"                              rmdir /s /q "build"
if exist "dist"                               rmdir /s /q "dist"
if exist "__pycache__"                        rmdir /s /q "__pycache__"
if exist "LoRA_Workflow_Renamer_Z.spec"       del /q "LoRA_Workflow_Renamer_Z.spec"
echo  [OK] Clean done. (source file untouched)
echo.

:: ── 7. Build executable ───────────────────────────────────────
echo  [STEP 5/6] Compiling executable...
echo.

"%PYINST%" ^
    --onefile ^
    --windowed ^
    --distpath . ^
    --name "LoRA_Workflow_Renamer_Z" ^
    --icon "%ICON_DIR%\lora_workflow_renamer_z.ico" ^
    --hidden-import "PIL" ^
    --hidden-import "PIL.Image" ^
    lora_workflow_renamer_z.py

if errorlevel 1 (
    echo.
    echo  [ERROR] PyInstaller failed. Check the output above.
    pause & exit /b 1
)

:: ── 8. Verify output ──────────────────────────────────────────
echo  [STEP 6/6] Verifying output...
if exist "LoRA_Workflow_Renamer_Z.exe" (
    echo  [OK] LoRA_Workflow_Renamer_Z.exe created.
) else (
    echo  [ERROR] LoRA_Workflow_Renamer_Z.exe not found after build.
    pause & exit /b 1
)
echo.

set "EXE_PATH=%SCRIPT_DIR%\LoRA_Workflow_Renamer_Z.exe"
:: Shortcuts point their icon at the .exe itself (icon index 0) — the exe
:: already has the icon compiled in from Step 5.

:: ── 9. Create shortcuts (Desktop + Start Menu) ─────────────────
echo  [..] Creating shortcuts...

set "DESKTOP_DIR=%USERPROFILE%\Desktop"
set "STARTMENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs"

call :make_shortcut "%DESKTOP_DIR%" "Desktop shortcut"
call :make_shortcut "%STARTMENU_DIR%" "Start Menu shortcut"
echo.

goto :after_shortcuts

:: ─────────────────────────────────────────────────────────────────────────
::  make_shortcut <destination folder> <label for messages>
::
::  Creates "LoRA Workflow Renamer Z.lnk" (display name uses spaces, not
::  underscores) inside the given destination folder. After running the
::  VBScript, the .lnk is verified to actually exist — cscript can return
::  errorlevel 0 even when nothing was written. If verification fails,
::  falls back to a plain .bat launcher in the same location, which needs
::  no COM/VBS support at all.
:: ─────────────────────────────────────────────────────────────────────────
:make_shortcut
setlocal enabledelayedexpansion
set "DEST_DIR=%~1"
set "LABEL=%~2"
set "SHORTCUT_NAME=LoRA Workflow Renamer Z"

if not exist "%DEST_DIR%" mkdir "%DEST_DIR%" >nul 2>&1

set "VBS=%TEMP%\lwrz_mkshortcut_%RANDOM%.vbs"
del /q "%VBS%" >nul 2>&1
echo Set oWS = WScript.CreateObject("WScript.Shell")>"%VBS%"
echo Set oLink = oWS.CreateShortcut("%DEST_DIR%\%SHORTCUT_NAME%.lnk")>>"%VBS%"
echo oLink.TargetPath = "%EXE_PATH%">>"%VBS%"
echo oLink.WorkingDirectory = "%SCRIPT_DIR%">>"%VBS%"
echo oLink.IconLocation = "%EXE_PATH%,0">>"%VBS%"
echo oLink.Description = "Rename ComfyUI workflow JSON files based on contained LoRAs">>"%VBS%"
echo oLink.Save>>"%VBS%"

cscript //nologo "%VBS%" >nul 2>&1
del /q "%VBS%" >nul 2>&1

if exist "%DEST_DIR%\%SHORTCUT_NAME%.lnk" (
    echo  [OK] %LABEL% created.
    endlocal
    exit /b 0
)

:: .lnk creation didn't actually produce a file (cscript may be blocked by
:: policy, or WSH's shell-link COM provider may be unavailable) — fall back
:: to a simple double-clickable .bat launcher in the same location.
set "FALLBACK_BAT=%DEST_DIR%\%SHORTCUT_NAME%.bat"
del /q "%FALLBACK_BAT%" >nul 2>&1
echo @echo off>"%FALLBACK_BAT%"
echo cd /d "%SCRIPT_DIR%">>"%FALLBACK_BAT%"
echo start "" "%EXE_PATH%">>"%FALLBACK_BAT%"

if exist "%FALLBACK_BAT%" (
    echo  [OK] %LABEL% created ^(as a launcher .bat — .lnk creation was
    echo       unavailable on this system^).
) else (
    echo  [!!] Could not create %LABEL% ^(non-fatal^). You can still run
    echo       "%EXE_PATH%" directly.
)
endlocal
exit /b 0

:after_shortcuts

:: ── 10. Remove .venv, build\, __pycache__\, and temp icon dir ──
:: The exe is fully self-contained now (icon included), so the build
:: environment and PyInstaller's intermediate caches are no longer
:: needed. Removing them keeps the project folder clean.
::
:: NOTE: right after PyInstaller exits, Windows (often Defender's
:: real-time scanner) can briefly keep a lock on files inside .venv\.
:: Deletion is attempted with a few short, bounded retries; if it still
:: hasn't finished after that, a final retry is kicked off in a separate
:: detached window so it can keep trying without holding this script up.

call :safe_rmdir ".venv" "Removed .venv"
call :safe_rmdir "build" "Removed build\"
call :safe_rmdir "__pycache__" "Removed __pycache__\"
call :safe_rmdir "%ICON_DIR%" "Removed temp icon folder"
echo.

goto :after_cleanup

:safe_rmdir
:: %1 = path to remove (quoted), %2 = success message (quoted)
setlocal
set "TARGET=%~1"
set "MSG=%~2"
set "REMOVED="
if not exist "%TARGET%" goto :safe_rmdir_done

echo  [..] Removing %TARGET% ...
for /l %%i in (1,1,5) do (
    if not defined REMOVED (
        rmdir /s /q "%TARGET%" >nul 2>&1
        if not exist "%TARGET%" (
            set "REMOVED=1"
        ) else (
            ping -n 2 127.0.0.1 >nul
        )
    )
)

if defined REMOVED (
    echo  [OK] %MSG%
    goto :safe_rmdir_done
)

echo  [!!] %TARGET% is still locked by another process ^(e.g. antivirus
echo       scanning it^) -- retrying it in the background for a bit.
echo       It is safe to delete it yourself later if it remains.
set "RETRY_BAT=%TEMP%\lwrz_rmretry_%RANDOM%.bat"
del /q "%RETRY_BAT%" >nul 2>&1
echo @echo off>"%RETRY_BAT%"
echo for /l %%%%i in (1,1,20) do (>>"%RETRY_BAT%"
echo     rmdir /s /q "%TARGET%" ^>nul 2^>^&1>>"%RETRY_BAT%"
echo     if not exist "%TARGET%" goto :rmretry_done>>"%RETRY_BAT%"
echo     ping -n 3 127.0.0.1 ^>nul>>"%RETRY_BAT%"
echo )>>"%RETRY_BAT%"
echo :rmretry_done>>"%RETRY_BAT%"
echo del /q "%%~f0">>"%RETRY_BAT%"
start "" /min cmd /c "%RETRY_BAT%"

:safe_rmdir_done
endlocal
exit /b 0

:after_cleanup

:: ── 11. Done ───────────────────────────────────────────────────
echo  ============================================
echo   BUILD SUCCESSFUL
echo  ============================================
echo.
echo   Executable: LoRA_Workflow_Renamer_Z.exe
echo   Shortcuts : Desktop and Start Menu (both linked to the
echo               .exe in this folder)
echo.
echo   Single self-contained .exe -- no extra folders needed.
echo   Copy "LoRA_Workflow_Renamer_Z.exe" anywhere and run it directly
echo   (re-run this script if you move it, so shortcuts stay in sync).
echo   No Python installation needed on the target machine.
echo.

pause
