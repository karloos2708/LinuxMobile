#!/data/data/com.termux/files/usr/bin/bash
#########################################################
# 🗑️ MOBILE DESKTOP LAB - Uninstaller v3.0
# Removes components installed by the safe installer
#########################################################

set -u
set -o pipefail

LOG_FILE="$HOME/mobile-desktop-lab-uninstall.log"

# ============== COLORS ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============== LOGGING ==============
log() {
    printf "[%s] %s\n" "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

info() {
    echo -e "${CYAN}[*]${NC} $*"
    log "INFO: $*"
}

ok() {
    echo -e "${GREEN}[✓]${NC} $*"
    log "OK: $*"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $*"
    log "WARN: $*"
}

err() {
    echo -e "${RED}[✗]${NC} $*"
    log "ERROR: $*"
}

# ============== ERROR HANDLER ==============
on_error() {
    local exit_code=$?
    err "Ocurrió un error en la línea $1. Revisa el log: $LOG_FILE"
    exit "$exit_code"
}
trap 'on_error $LINENO' ERR

# ============== HELPERS ==============
pkg_remove_if_installed() {
    local pkg="$1"
    if pkg list-installed 2>/dev/null | awk '{print $1}' | grep -qx "$pkg"; then
        info "Removing package: $pkg"
        pkg uninstall -y "$pkg" >> "$LOG_FILE" 2>&1 || warn "No se pudo eliminar $pkg"
    else
        log "SKIP package not installed: $pkg"
    fi
}

remove_file_if_exists() {
    local path="$1"
    if [ -e "$path" ] || [ -L "$path" ]; then
        rm -rf "$path" >> "$LOG_FILE" 2>&1 || warn "No se pudo eliminar $path"
        ok "Removed: $path"
    else
        log "SKIP path not found: $path"
    fi
}

# ============== BANNER ==============
show_banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
╔══════════════════════════════════════════════╗
║                                              ║
║   🗑️ MOBILE DESKTOP LAB UNINSTALLER v3.0    ║
║                                              ║
║         Remove Installed Components          ║
║                                              ║
╚══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE} This will remove the desktop environment installed by the safe installer.${NC}"
    echo ""
}

# ============== CONFIRMATION ==============
confirm_uninstall() {
    echo -e "${YELLOW}⚠️  WARNING: This will remove:${NC}"
    echo -e "  • XFCE4 desktop environment"
    echo -e "  • Termux-X11 related packages"
    echo -e "  • Audio support (PulseAudio)"
    echo -e "  • GPU config created by installer"
    echo -e "  • Wine / Hangover support"
    echo -e "  • Desktop shortcuts and launcher scripts"
    echo -e "  • Python libraries installed by the script"
    echo ""
    echo -e "${RED}This action cannot be undone!${NC}"
    echo ""
    read -r -p "$(echo -e "${WHITE}Type 'UNINSTALL' to confirm: ${NC}")" confirm

    if [ "$confirm" != "UNINSTALL" ]; then
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        exit 0
    fi
}

# ============== STOP RUNNING PROCESSES ==============
stop_processes() {
    echo ""
    info "Stopping running processes..."

    pkill -f "termux.x11" 2>/dev/null || true
    pkill -f "xfce4-session" 2>/dev/null || true
    pkill -f "xfce" 2>/dev/null || true
    pkill -f "pulseaudio" 2>/dev/null || true
    pkill -f "dbus-daemon" 2>/dev/null || true
    pkill -f "wine" 2>/dev/null || true

    ok "Processes stopped"
}

# ============== REMOVE CUSTOM SCRIPTS ==============
remove_scripts() {
    echo ""
    info "Removing custom scripts..."

    remove_file_if_exists "$HOME/start-desktop.sh"
    remove_file_if_exists "$HOME/stop-desktop.sh"
    remove_file_if_exists "$HOME/check-gpu.sh"
    remove_file_if_exists "$HOME/.config/mobile-desktop-gpu.sh"

    ok "Custom scripts removed"
}

# ============== REMOVE SHORTCUTS ==============
remove_shortcuts() {
    echo ""
    info "Removing desktop shortcuts..."

    remove_file_if_exists "$HOME/Desktop/Firefox.desktop"
    remove_file_if_exists "$HOME/Desktop/VSCode.desktop"
    remove_file_if_exists "$HOME/Desktop/Terminal.desktop"
    remove_file_if_exists "$HOME/Desktop/Windows_Explorer.desktop"
    remove_file_if_exists "$HOME/Desktop/Wine_Config.desktop"

    if [ -d "$HOME/Desktop" ] && [ -z "$(ls -A "$HOME/Desktop" 2>/dev/null)" ]; then
        rmdir "$HOME/Desktop" 2>/dev/null || true
        ok "Empty Desktop folder removed"
    fi

    ok "Shortcuts removed"
}

# ============== REMOVE WINE ==============
remove_wine() {
    echo ""
    info "Removing Wine / Hangover components..."

    remove_file_if_exists "/data/data/com.termux/files/usr/bin/wine"
    remove_file_if_exists "/data/data/com.termux/files/usr/bin/winecfg"
    remove_file_if_exists "$HOME/.wine"

    pkg_remove_if_installed "hangover-wine"
    pkg_remove_if_installed "hangover-wowbox64"

    ok "Wine components removed"
}

# ============== REMOVE PYTHON ENV ==============
remove_python_extras() {
    echo ""
    info "Removing Python libraries installed by script..."

    if command -v python >/dev/null 2>&1; then
        python -m pip uninstall -y requests beautifulsoup4 >> "$LOG_FILE" 2>&1 || warn "No se pudieron eliminar una o más librerías Python"
    fi

    ok "Python extra libraries removed"
}

# ============== REMOVE APPLICATIONS ==============
remove_apps() {
    echo ""
    info "Removing applications..."

    pkg_remove_if_installed "firefox"
    pkg_remove_if_installed "code-oss"
    pkg_remove_if_installed "git"
    pkg_remove_if_installed "wget"
    pkg_remove_if_installed "curl"
    pkg_remove_if_installed "nano"
    pkg_remove_if_installed "python"

    ok "Applications removed"
}

# ============== REMOVE AUDIO ==============
remove_audio() {
    echo ""
    info "Removing audio support..."

    pulseaudio --kill 2>/dev/null || true
    pkg_remove_if_installed "pavucontrol"
    pkg_remove_if_installed "pulseaudio"

    ok "Audio removed"
}

# ============== REMOVE GPU ==============
remove_gpu() {
    echo ""
    info "Removing GPU acceleration packages..."

    pkg_remove_if_installed "mesa-demos"
    pkg_remove_if_installed "mesa-zink"
    pkg_remove_if_installed "mesa-vulkan-icd-freedreno"
    pkg_remove_if_installed "mesa-vulkan-icd-swrast"
    pkg_remove_if_installed "vulkan-loader-android"

    ok "GPU packages removed"
}

# ============== REMOVE DESKTOP ==============
remove_desktop() {
    echo ""
    info "Removing XFCE4 desktop..."

    pkg_remove_if_installed "dbus"
    pkg_remove_if_installed "mousepad"
    pkg_remove_if_installed "thunar"
    pkg_remove_if_installed "xfce4-terminal"
    pkg_remove_if_installed "xfce4"

    remove_file_if_exists "$HOME/.config/xfce4"
    remove_file_if_exists "$HOME/.cache/xfce4"
    remove_file_if_exists "$HOME/.local/share/xfce4"
    remove_file_if_exists "$HOME/.xsessions"
    remove_file_if_exists "$HOME/.xsession-errors"

    ok "Desktop removed"
}

# ============== REMOVE X11 ==============
remove_x11() {
    echo ""
    info "Removing Termux-X11..."

    pkg_remove_if_installed "xorg-xrandr"
    pkg_remove_if_installed "termux-x11-nightly"

    ok "X11 removed"
}

# ============== REMOVE BASE TOOLS ==============
remove_base_tools() {
    echo ""
    info "Removing extra base tools installed by script..."

    pkg_remove_if_installed "termux-tools"

    ok "Base tools cleanup finished"
}

# ============== REMOVE REPOS ==============
remove_repos() {
    echo ""
    info "Removing extra repositories..."

    pkg_remove_if_installed "tur-repo"
    pkg_remove_if_installed "x11-repo"

    ok "Repositories removed"
}

# ============== CLEANUP ==============
cleanup() {
    echo ""
    info "Cleaning up..."

    remove_file_if_exists "$HOME/mobile-desktop-lab-install.log"
    remove_file_if_exists "$HOME/.config/mobile-desktop-lab*"

    pkg clean >> "$LOG_FILE" 2>&1 || true

    ok "Cleanup complete"
}

# ============== COMPLETION ==============
show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           ✅ UNINSTALLATION COMPLETE! ✅                      ║
║                                                               ║
║        Mobile Desktop Lab components removed.                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE}📱 Mobile Desktop Lab has been removed.${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Termux itself is still installed."
    echo -e "${YELLOW}Uninstall log:${NC} ${LOG_FILE}"
    echo ""
}

# ============== MAIN ==============
main() {
    : > "$LOG_FILE"
    show_banner
    confirm_uninstall

    stop_processes
    remove_scripts
    remove_shortcuts
    remove_wine
    remove_python_extras
    remove_apps
    remove_audio
    remove_gpu
    remove_desktop
    remove_x11
    remove_base_tools
    remove_repos
    cleanup

    show_completion
}

# ============== RUN ==============
main "$@"