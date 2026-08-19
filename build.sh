#!/usr/bin/env bash
# =============================================================
#  build.sh — Linux/BigLinux/KDE setup for LoRA Workflow Renamer Z
#
#  This does NOT compile a PyInstaller binary and does NOT copy
#  lora_workflow_renamer_z.py anywhere (not into ~/.local/bin, not
#  into ~/bin, nowhere). The app always runs directly from the .py
#  file sitting in this same folder — the Desktop shortcut and the
#  application-menu / sidebar entry both point straight at it.
#  (The Windows build, via build.bat, still produces a PyInstaller
#  .exe separately — that part is unaffected by this script.)
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
DESKTOP_FILE_NAME="LoRA_Workflow_Renamer_Z.desktop"

# Resolve the REAL folder this script lives in, following symlinks, so the
# shortcuts we generate always point at the actual .py file next to
# build.sh — never at a stale copy that might exist elsewhere on $PATH.
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
MAIN="$SCRIPT_DIR/lora_workflow_renamer_z.py"

APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")

banner "LoRA Workflow Renamer Z | Linux Setup"

# ── 1. Check source file ──────────────────────────────────────────────────
[[ -f "$MAIN" ]] || err "lora_workflow_renamer_z.py not found in $SCRIPT_DIR"
ok "Source file found: $MAIN"

# ── 2. Find Python 3.10+ ────────────────────────────────────────────────────
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

# ── 3. Check tkinter ─────────────────────────────────────────────────────────
banner "Checking tkinter"
if ! "$PYTHON" -c "import tkinter" 2>/dev/null; then
    warn "tkinter not found — installing..."
    if   command -v pacman  &>/dev/null; then sudo pacman -S --noconfirm tk
    elif command -v apt-get &>/dev/null; then sudo apt-get install -y python3-tk
    elif command -v dnf     &>/dev/null; then sudo dnf install -y python3-tkinter
    else err "Cannot install tkinter automatically."; fi
fi
ok "tkinter available"

# ── 4. Make the script directly executable in place ─────────────────────────
chmod +x "$MAIN"
ok "$MAIN is now executable"

# ── 5. Clean up any stale copy from an older build ───────────────────────────
#    This setup never copies lora_workflow_renamer_z.py anywhere; it always
#    runs in place from $SCRIPT_DIR. Remove any leftover copy from a
#    previous version of this build script so nothing on $PATH can shadow
#    the real file.
for stale in \
    "$HOME/.local/bin/lora_workflow_renamer_z.py" \
    "$HOME/bin/lora_workflow_renamer_z.py" \
    "$HOME/.local/share/lora_workflow_renamer_z/lora_workflow_renamer_z.py" \
    "$HOME/.local/bin/LoRA_Workflow_Renamer_Z" \
    "$HOME/bin/LoRA_Workflow_Renamer_Z"
do
    if [[ -e "$stale" ]] && { [[ ! -f "$MAIN" ]] || [[ "$(realpath "$stale" 2>/dev/null)" != "$MAIN" ]]; }; then
        echo " Removing stale copy: $stale"
        rm -f "$stale"
    fi
done
# Also drop any old compiled PyInstaller binary left in this folder from a
# previous version of this build script — it's no longer produced or used.
[[ -f "$SCRIPT_DIR/LoRA_Workflow_Renamer_Z" ]] && rm -f "$SCRIPT_DIR/LoRA_Workflow_Renamer_Z" && info "Removed old compiled binary in $SCRIPT_DIR"

# ── 6. Extract built-in icon (embedded in the script, no Pillow needed) ─────
banner "Installing icon"
mkdir -p "$APP_DIR" "$DESKTOP_DIR" "$ICON_DIR"
"$PYTHON" "$MAIN" --extract-icons "$ICON_DIR" \
    || err "Icon extraction failed (lora_workflow_renamer_z.py --extract-icons)."
mv -f "$ICON_DIR/lora_workflow_renamer_z.svg" "$ICON_DIR/LoRA_Workflow_Renamer_Z.svg"
rm -f "$ICON_DIR/lora_workflow_renamer_z.ico" "$ICON_DIR/lora_workflow_renamer_z.png"
ICON_FILE="$ICON_DIR/LoRA_Workflow_Renamer_Z.svg"
ok "Icon installed to $ICON_FILE"

# ── 7. Desktop + application-menu entry ──────────────────────────────────────
#    Exec runs the .py file directly, in place, via the same interpreter
#    found above — never a copy, never a compiled binary.
banner "Creating shortcuts"
cat > "$APP_DIR/$DESKTOP_FILE_NAME" << DESKTOPEOF
[Desktop Entry]
Name=$EXEC_DISPLAY
Comment=Rename ComfyUI workflow JSON files based on contained LoRAs
Exec=$PYTHON "$MAIN"
Icon=$ICON_FILE
Terminal=false
Type=Application
Categories=Utility;FileTools;
DESKTOPEOF
chmod +x "$APP_DIR/$DESKTOP_FILE_NAME"

# Desktop shortcut (user's Desktop folder) — same file, same Exec target
cp "$APP_DIR/$DESKTOP_FILE_NAME" "$DESKTOP_DIR/$DESKTOP_FILE_NAME"
chmod 755 "$DESKTOP_DIR/$DESKTOP_FILE_NAME"

command -v gio &>/dev/null && { gio set "$DESKTOP_DIR/$DESKTOP_FILE_NAME" metadata::trusted true 2>/dev/null || true; }
command -v update-desktop-database &>/dev/null && { update-desktop-database "$APP_DIR" &>/dev/null || true; }

# Refresh the application-menu / sidebar-menu cache so the new entry shows
# up immediately under most desktop environments (GNOME, KDE, XFCE, etc.)
if   command -v kbuildsycoca6 &>/dev/null; then kbuildsycoca6 &>/dev/null || true
elif command -v kbuildsycoca5 &>/dev/null; then kbuildsycoca5 &>/dev/null || true
fi
ok "Desktop and application-menu shortcuts created (linked to: $MAIN)"

echo ""
echo -e "${GREEN}${BOLD} ============================================"
echo "  SETUP COMPLETE"
echo -e " ============================================${RESET}"
echo ""
echo -e "  Script  : ${CYAN}$MAIN${RESET}"
echo -e "  Run     : ${BOLD}\"$MAIN\"${RESET}   (or via the Desktop / menu shortcut)"
echo -e "  Menu    : $APP_DIR/$DESKTOP_FILE_NAME"
echo -e "  Desktop : $DESKTOP_DIR/$DESKTOP_FILE_NAME"
echo ""
