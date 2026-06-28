#!/usr/bin/env bash
# =============================================================
#  build.sh — Builds LoRA Workflow Renamer Z with PyInstaller
#  AND installs desktop / menu shortcuts on Linux
#
#  Single-file, GUI-only edition: lora_workflow_renamer_z.py contains
#  the renaming logic, the Tkinter GUI, and the built-in icon (embedded
#  as base64 inside the script — no external asset file is needed).
#  Only one executable is produced (the GUI). A --folder CLI fallback
#  still exists inside the script for scripting/automation, but this
#  build script does not produce a separate CLI binary for it.
# =============================================================

set -euo pipefail

BOLD="\033[1m"; GREEN="\033[32m"; CYAN="\033[36m"
YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"

banner() { echo -e "\n${CYAN}${BOLD} $* ${RESET}"; }
ok()     { echo -e " ${GREEN}[OK]${RESET}  $*"; }
info()   { echo -e " ${CYAN}[..]${RESET}  $*"; }
warn()   { echo -e " ${YELLOW}[!!]${RESET}  $*"; }
err()    { echo -e " ${RED}[ERR]${RESET} $*" >&2; exit 1; }

EXEC_DISPLAY="LoRA Workflow Renamer Z"
EXEC_NAME="LoRA_Workflow_Renamer_Z"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")
DESKTOP_FILE_NAME="LoRA_Workflow_Renamer_Z.desktop"

banner "LoRA Workflow Renamer Z | Linux Build Script"

# ── 1. Find Python 3.10+ ──────────────────────────────────────────────────────
PYTHON=""
try_python() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        local major minor
        major=$("$cmd" -c "import sys; print(sys.version_info.major)" 2>/dev/null) || return 1
        minor=$("$cmd" -c "import sys; print(sys.version_info.minor)" 2>/dev/null) || return 1
        if [[ "$major" -eq 3 && "$minor" -ge 10 ]]; then
            PYTHON="$cmd"; return 0
        fi
    fi
    return 1
}
for cmd in python3 python python3.14 python3.13 python3.12 python3.11 python3.10; do
    if try_python "$cmd"; then
        ok "Found $("$PYTHON" --version) → $PYTHON"; break
    fi
done
[[ -z "$PYTHON" ]] && err "Python 3.10+ not found."

PY_VER=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_PREFIX=$("$PYTHON" -c "import sys; print(sys.prefix)")

# ── 2. Find libpython ─────────────────────────────────────────────────────────
banner "Checking libpython shared library"
LIBPYTHON=""
LIBPY_NAMES=("libpython${PY_VER}.so.1.0" "libpython${PY_VER}.so")
LIBPY_DIRS=("$PY_PREFIX/lib" "/usr/lib" "/usr/lib64" "/usr/local/lib"
            "/usr/lib/x86_64-linux-gnu" "/usr/lib/aarch64-linux-gnu")
for name in "${LIBPY_NAMES[@]}"; do
    for dir in "${LIBPY_DIRS[@]}"; do
        [[ -f "$dir/$name" ]] && LIBPYTHON="$dir/$name" && ok "Found: $LIBPYTHON" && break 2
    done
done
if [[ -z "$LIBPYTHON" ]] && command -v ldconfig &>/dev/null; then
    for name in "${LIBPY_NAMES[@]}"; do
        found=$(ldconfig -p 2>/dev/null | grep "$name" | awk '{print $NF}' | head -1)
        [[ -n "$found" && -f "$found" ]] && LIBPYTHON="$found" && ok "Found via ldconfig: $LIBPYTHON" && break
    done
fi
SPEC_BINARIES="[]"
[[ -n "$LIBPYTHON" ]] && SPEC_BINARIES="[('$LIBPYTHON', '.')]"

# ── 3. Check tkinter ──────────────────────────────────────────────────────────
banner "Checking tkinter"
if ! "$PYTHON" -c "import tkinter" 2>/dev/null; then
    warn "tkinter not found — installing..."
    if   command -v pacman  &>/dev/null; then sudo pacman -S --noconfirm tk
    elif command -v apt-get &>/dev/null; then sudo apt-get install -y python3-tk
    elif command -v dnf     &>/dev/null; then sudo dnf install -y python3-tkinter
    else err "Cannot install tkinter automatically."; fi
fi
ok "tkinter available"

# ── 4. Check source file ──────────────────────────────────────────────────────
[[ -f "lora_workflow_renamer_z.py" ]] || err "lora_workflow_renamer_z.py not found."
ok "Source file found"

# ── 5. Virtual environment ────────────────────────────────────────────────────
banner "Step 1/6 — Virtual environment"
if [[ ! -d ".venv" ]]; then
    "$PYTHON" -m venv .venv && ok "Created .venv"
else
    .venv/bin/python -c "print(1)" &>/dev/null && info "Reusing .venv" || {
        warn "Broken .venv — recreating..."; rm -rf .venv; "$PYTHON" -m venv .venv; ok "Recreated .venv"
    }
fi
source .venv/bin/activate
ok "Virtual environment activated"

# ── 6. Install dependencies ───────────────────────────────────────────────────
banner "Step 2/6 — Installing dependencies"
pip install --quiet --upgrade pip
pip install --quiet --upgrade pyinstaller pillow
ok "PyInstaller $(pyinstaller --version) + Pillow ready"

# ── 7. Extract built-in icon ───────────────────────────────────────────────────
banner "Step 3/6 — Extracting built-in icon"
ICON_TMP_DIR="$(mktemp -d)"
python "lora_workflow_renamer_z.py" --extract-icons "$ICON_TMP_DIR" \
    || err "Icon extraction failed (lora_workflow_renamer_z.py --extract-icons)."
[[ -f "$ICON_TMP_DIR/lora_workflow_renamer_z.svg" ]] || err "Extracted SVG icon missing."
ok "Icon extracted to temp dir: $ICON_TMP_DIR"

# ── 8. Clean previous build ───────────────────────────────────────────────────
banner "Step 4/6 — Cleaning previous build artefacts"
[[ -d "build" ]]                   && rm -rf "build"                   && info "Removed build/"
[[ -d "__pycache__" ]]              && rm -rf "__pycache__"            && info "Removed __pycache__/"
[[ -f "$EXEC_NAME" ]]              && rm -f  "$EXEC_NAME"              && info "Removed old executable"
[[ -f "$EXEC_NAME.spec" ]]         && rm -f  "$EXEC_NAME.spec"         && info "Removed spec"
ok "Clean done"

# ── 9. Spec + compile ────────────────────────────────────────────────────────
banner "Step 5/6 — Generating spec and compiling"
cat > "$EXEC_NAME.spec" << SPEC
# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_submodules
block_cipher = None
a = Analysis(
    ['lora_workflow_renamer_z.py'],
    pathex=['.'],
    binaries=${SPEC_BINARIES},
    datas=[],
    hiddenimports=(
        collect_submodules('tkinter') +
        ['PIL', 'PIL.Image']
    ),
    hookspath=[], hooksconfig={}, runtime_hooks=[], excludes=[],
    cipher=block_cipher, noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)
exe = EXE(
    pyz, a.scripts, a.binaries, a.zipfiles, a.datas,
    name='${EXEC_NAME}',
    debug=False, bootloader_ignore_signals=False, strip=False,
    upx=False, upx_exclude=[], runtime_tmpdir=None, console=False,
    disable_windowed_traceback=False, target_arch=None,
    codesign_identity=None, entitlements_file=None,
    icon='${ICON_TMP_DIR}/lora_workflow_renamer_z.ico',
)
SPEC

pyinstaller --distpath . "$EXEC_NAME.spec" || err "PyInstaller failed."

# ── 10. Verify output ──────────────────────────────────────────────────────────
banner "Step 6/6 — Verifying output"
[[ -f "$EXEC_NAME" ]] && chmod +x "$EXEC_NAME" && ok "$EXEC_NAME created" || err "Binary not found."

# ── 11. Install icon + desktop/menu shortcut ──────────────────────────────────
banner "Installing icon and shortcuts"

mkdir -p "$APP_DIR" "$DESKTOP_DIR" "$ICON_DIR"

EXE_PATH="$SCRIPT_DIR/$EXEC_NAME"

# Icon — vector SVG, extracted from the script's own embedded data (Step 3/6)
cp "$ICON_TMP_DIR/lora_workflow_renamer_z.svg" "$ICON_DIR/$EXEC_NAME.svg"
ok "Icon installed to $ICON_DIR/$EXEC_NAME.svg"
rm -rf "$ICON_TMP_DIR"

# Desktop + menu entry (heredoc — no variable quoting issues). Exec points
# at the executable in THIS folder (where it was just built). Name= uses
# spaces (no underscores) since that's the label shown in menus/Desktop —
# the .desktop filename itself and the binary keep their underscores.
cat > "$APP_DIR/$DESKTOP_FILE_NAME" << DESKTOPEOF
[Desktop Entry]
Name=$EXEC_DISPLAY
Comment=Rename ComfyUI workflow JSON files based on contained LoRAs
Exec=$EXE_PATH
Icon=$ICON_DIR/$EXEC_NAME.svg
Terminal=false
Type=Application
Categories=Utility;FileTools;
DESKTOPEOF
chmod +x "$APP_DIR/$DESKTOP_FILE_NAME"

# Desktop shortcut (user's Desktop folder)
cp "$APP_DIR/$DESKTOP_FILE_NAME" "$DESKTOP_DIR/$DESKTOP_FILE_NAME"
chmod 755 "$DESKTOP_DIR/$DESKTOP_FILE_NAME"

command -v gio &>/dev/null && { gio set "$DESKTOP_DIR/$DESKTOP_FILE_NAME" metadata::trusted true 2>/dev/null || true; }
command -v update-desktop-database &>/dev/null && { update-desktop-database "$APP_DIR" &>/dev/null || true; }

# Refresh the application-menu / sidebar-menu cache so the new entry shows
# up immediately under most desktop environments (GNOME, KDE, XFCE, etc.)
if   command -v kbuildsycoca6 &>/dev/null; then kbuildsycoca6 &>/dev/null || true
elif command -v kbuildsycoca5 &>/dev/null; then kbuildsycoca5 &>/dev/null || true
fi
ok "Desktop and application-menu shortcuts created (linked to: $EXE_PATH)"

deactivate
rm -rf .venv                   && ok "Removed .venv"
rm -rf build                   && ok "Removed build/"
rm -rf __pycache__             && ok "Removed __pycache__/"
rm -f  "$EXEC_NAME.spec"       && ok "Removed $EXEC_NAME.spec"

echo ""
echo -e "${GREEN}${BOLD} ============================================"
echo "  BUILD SUCCESSFUL"
echo -e " ============================================${RESET}"
echo ""
echo -e "  Executable : ${CYAN}$EXE_PATH${RESET}"
echo -e "  Run        : ${BOLD}\"$EXE_PATH\"${RESET}"
echo ""
