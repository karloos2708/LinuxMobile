#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  📱 MOBILE DESKTOP LAB - Safe Installer v3.0
#
#  Features:
#  - Overall progress percentage
#  - GPU acceleration auto-setup (Turnip/Zink)
#  - XFCE4 desktop + Termux-X11
#  - Audio support
#  - Firefox / VS Code / Git / Python
#  - Wine / Hangover support
#  - One-click desktop launch
#######################################################

set -u
set -o pipefail

# ============== CONFIGURATION ==============
TOTAL_STEPS=10
CURRENT_STEP=0
LOG_FILE="$HOME/mobile-desktop-lab-install.log"

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
BOLD='\033[1m'

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

# ============== PROGRESS FUNCTIONS ==============
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    local bar=""

    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  📊 OVERALL PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${GREEN}${bar}${NC} ${WHITE}${percent}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(((i + 1) % 10))
        printf "\r  ${YELLOW}⏳${NC} ${message} ${CYAN}${spin:$i:1}${NC}  "
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?

    if [ "$exit_code" -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} ${message}                                    \n"
    else
        printf "\r  ${RED}✗${NC} ${message} ${RED}(failed)${NC}                 \n"
    fi

    return "$exit_code"
}

run_cmd() {
    local message=$1
    shift
    (
        "$@" >> "$LOG_FILE" 2>&1
    ) &
    spinner $! "$message"
}

install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    run_cmd "Installing ${name}..." pkg install -y "$pkg"
}

install_pkg_optional() {
    local pkg=$1
    local name=${2:-$pkg}

    if run_cmd "Installing ${name}..." pkg install -y "$pkg"; then
        ok "${name} installed"
    else
        warn "No se pudo instalar ${name}. Se omitirá."
    fi
}

# ============== PRECHECKS ==============
check_termux() {
    if ! command -v pkg >/dev/null 2>&1; then
        err "Este script debe ejecutarse dentro de Termux."
        exit 1
    fi
}

check_storage() {
    local free_kb
    free_kb=$(df "$HOME" | awk 'NR==2 {print $4}')

    if [ -n "${free_kb:-}" ] && [ "$free_kb" -lt 1048576 ]; then
        warn "Tienes menos de 1 GB libre. La instalación podría fallar."
    fi
}

# ============== BANNER ==============
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔══════════════════════════════════════╗
    ║                                      ║
    ║   🚀  MOBILE DESKTOP LAB v3.0  🚀    ║
    ║                                      ║
    ║       Safe XFCE + Termux-X11         ║
    ║                                      ║
    ╚══════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE}         Secure desktop installer for Termux${NC}"
    echo ""
}

# ============== DEVICE DETECTION ==============
detect_device() {
    info "Detecting your device..."
    echo ""

    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    CPU_ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")
    GPU_VENDOR=$(getprop ro.hardware.egl 2>/dev/null || echo "")

    echo -e "  ${GREEN}📱${NC} Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}🤖${NC} Android: ${WHITE}${ANDROID_VERSION}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  CPU: ${WHITE}${CPU_ABI}${NC}"

    if echo "$GPU_VENDOR" | tr '[:upper:]' '[:lower:]' | grep -q "adreno"; then
        GPU_DRIVER="freedreno"
        echo -e "  ${GREEN}🎮${NC} GPU: ${WHITE}Adreno detected - Turnip/Freedreno${NC}"
    else
        GPU_DRIVER="swrast"
        echo -e "  ${GREEN}🎮${NC} GPU: ${WHITE}Software rendering fallback${NC}"
    fi

    log "Device=${DEVICE_BRAND} ${DEVICE_MODEL} Android=${ANDROID_VERSION} ABI=${CPU_ABI} GPU_DRIVER=${GPU_DRIVER}"
    echo ""
    sleep 1
}

# ============== STEP 1: UPDATE SYSTEM ==============
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""

    run_cmd "Updating package lists..." pkg update -y
    run_cmd "Upgrading installed packages..." pkg upgrade -y
}

# ============== STEP 2: INSTALL REPOSITORIES ==============
step_repos() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding package repositories...${NC}"
    echo ""

    install_pkg "x11-repo" "X11 Repository"
    install_pkg "tur-repo" "TUR Repository (Firefox, VS Code)"
}

# ============== STEP 3: INSTALL BASE TOOLS ==============
step_base_tools() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing base tools...${NC}"
    echo ""

    install_pkg "termux-tools" "Termux Tools"
    install_pkg "git" "Git Version Control"
    install_pkg "wget" "Wget Downloader"
    install_pkg "curl" "cURL"
    install_pkg "nano" "Nano Editor"
}

# ============== STEP 4: INSTALL TERMUX-X11 ==============
step_x11() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Termux-X11...${NC}"
    echo ""

    install_pkg "termux-x11-nightly" "Termux-X11 Display Server"
    install_pkg "xorg-xrandr" "XRandR (Display Settings)"
    install_pkg_optional "mesa-demos" "Mesa Demos / glxinfo"
}

# ============== STEP 5: INSTALL DESKTOP ==============
step_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing XFCE4 Desktop...${NC}"
    echo ""

    install_pkg "xfce4" "XFCE4 Desktop Environment"
    install_pkg "xfce4-terminal" "XFCE4 Terminal"
    install_pkg "thunar" "Thunar File Manager"
    install_pkg "mousepad" "Mousepad Text Editor"
    install_pkg_optional "dbus" "DBus"
}

# ============== STEP 6: INSTALL GPU DRIVERS ==============
step_gpu() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing GPU Acceleration (Turnip/Zink)...${NC}"
    echo ""

    install_pkg_optional "mesa-zink" "Mesa Zink (OpenGL over Vulkan)"

    if [ "$GPU_DRIVER" = "freedreno" ]; then
        install_pkg_optional "mesa-vulkan-icd-freedreno" "Turnip Adreno GPU Driver"
    else
        install_pkg_optional "mesa-vulkan-icd-swrast" "Software Vulkan Renderer"
    fi

    install_pkg_optional "vulkan-loader-android" "Vulkan Loader"

    echo -e "  ${GREEN}✓${NC} GPU acceleration configured!"
}

# ============== STEP 7: INSTALL AUDIO ==============
step_audio() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Audio Support...${NC}"
    echo ""

    install_pkg "pulseaudio" "PulseAudio Sound Server"
    install_pkg_optional "pavucontrol" "PulseAudio Volume Control"
}

# ============== STEP 8: INSTALL APPS ==============
step_apps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Applications...${NC}"
    echo ""

    install_pkg_optional "firefox" "Firefox Browser"
    install_pkg_optional "code-oss" "VS Code Editor"
}

# ============== STEP 9: INSTALL PYTHON ==============
step_python() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Python environment...${NC}"
    echo ""

    install_pkg "python" "Python"
    run_cmd "Upgrading pip..." python -m pip install --upgrade pip
    run_cmd "Installing Python libraries..." python -m pip install requests beautifulsoup4
}

# ============== STEP 10: INSTALL WINE ==============
step_wine() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Wine (Windows Support)...${NC}"
    echo ""

    run_cmd "Removing old Wine versions..." pkg remove -y wine-stable

    install_pkg_optional "hangover-wine" "Wine Compatibility Layer"
    install_pkg_optional "hangover-wowbox64" "Box64 Wrapper"

    if [ -f /data/data/com.termux/files/usr/opt/hangover-wine/bin/wine ]; then
        ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/wine /data/data/com.termux/files/usr/bin/wine
    fi

    if [ -f /data/data/com.termux/files/usr/opt/hangover-wine/bin/winecfg ]; then
        ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/winecfg /data/data/com.termux/files/usr/bin/winecfg
    fi

    if command -v wine >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⏳${NC} Applying Windows UI optimizations..."
        wine reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f > /dev/null 2>&1 || true
        echo -e "  ${GREEN}✓${NC} UI optimized"
    else
        warn "Wine no quedó disponible en PATH. Se omitieron optimizaciones."
    fi
}

# ============== CREATE LAUNCHER SCRIPTS ==============
create_launchers() {
    echo -e "${PURPLE}[*] Creating launcher scripts...${NC}"
    echo ""

    mkdir -p "$HOME/.config"

    cat > "$HOME/.config/mobile-desktop-gpu.sh" << 'GPUEOF'
# Mobile Desktop Lab - GPU Acceleration Config
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export ZINK_DESCRIPTORS=lazy
GPUEOF
    echo -e "  ${GREEN}✓${NC} GPU config created"

    cat > "$HOME/start-desktop.sh" << 'LAUNCHEREOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u

echo ""
echo "🚀 Starting Mobile Desktop Lab..."
echo ""

# Load GPU config
source "$HOME/.config/mobile-desktop-gpu.sh" 2>/dev/null || true

# Stop previous sessions gently
echo "🔄 Cleaning up old sessions..."
pkill -f "termux.x11" 2>/dev/null || true
pkill -f "xfce4-session" 2>/dev/null || true
pkill -f "xfce" 2>/dev/null || true
pkill -f "dbus-daemon" 2>/dev/null || true
pulseaudio --kill 2>/dev/null || true

sleep 1

# Audio setup
unset PULSE_SERVER
echo "🔊 Starting audio server..."
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 >/dev/null 2>&1 || true
export PULSE_SERVER=127.0.0.1

# Start Termux-X11 server
echo "📺 Starting X11 display server..."
termux-x11 :0 -ac >/dev/null 2>&1 &
sleep 3

# Set display
export DISPLAY=:0

# Start XFCE Desktop
echo "🖥️ Launching XFCE4 Desktop..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📱 Open the Termux-X11 app to see desktop!"
echo "  🔊 Audio is enabled!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exec startxfce4
LAUNCHEREOF
    chmod +x "$HOME/start-desktop.sh"
    echo -e "  ${GREEN}✓${NC} Created ~/start-desktop.sh"

    cat > "$HOME/stop-desktop.sh" << 'STOPEOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "Stopping Mobile Desktop Lab..."
pkill -f "termux.x11" 2>/dev/null || true
pkill -f "pulseaudio" 2>/dev/null || true
pkill -f "xfce4-session" 2>/dev/null || true
pkill -f "xfce" 2>/dev/null || true
pkill -f "dbus-daemon" 2>/dev/null || true
echo "Desktop stopped."
STOPEOF
    chmod +x "$HOME/stop-desktop.sh"
    echo -e "  ${GREEN}✓${NC} Created ~/stop-desktop.sh"

    cat > "$HOME/check-gpu.sh" << 'GPUCHECKEOF'
#!/data/data/com.termux/files/usr/bin/bash
source "$HOME/.config/mobile-desktop-gpu.sh" 2>/dev/null || true

if command -v glxinfo >/dev/null 2>&1; then
    glxinfo | grep -i "renderer"
else
    echo "glxinfo no está instalado."
fi
GPUCHECKEOF
    chmod +x "$HOME/check-gpu.sh"
    echo -e "  ${GREEN}✓${NC} Created ~/check-gpu.sh"
}

# ============== CREATE DESKTOP SHORTCUTS ==============
create_shortcuts() {
    echo -e "${PURPLE}[*] Creating Desktop Shortcuts...${NC}"
    echo ""

    mkdir -p "$HOME/Desktop"

    cat > "$HOME/Desktop/Firefox.desktop" << 'EOF'
[Desktop Entry]
Name=Firefox
Comment=Web Browser
Exec=firefox
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
EOF

    cat > "$HOME/Desktop/VSCode.desktop" << 'EOF'
[Desktop Entry]
Name=VS Code
Comment=Code Editor
Exec=code-oss --no-sandbox
Icon=code-oss
Type=Application
Categories=Development;
EOF

    cat > "$HOME/Desktop/Terminal.desktop" << 'EOF'
[Desktop Entry]
Name=Terminal
Comment=XFCE Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
Categories=System;TerminalEmulator;
EOF

    cat > "$HOME/Desktop/Windows_Explorer.desktop" << 'EOF'
[Desktop Entry]
Name=Windows Explorer
Comment=Windows File Manager
Exec=wine winefile
Icon=folder-windows
Type=Application
Categories=System;
EOF

    cat > "$HOME/Desktop/Wine_Config.desktop" << 'EOF'
[Desktop Entry]
Name=Wine Config
Comment=Windows Settings
Exec=wine winecfg
Icon=wine
Type=Application
Categories=Settings;
EOF

    chmod +x "$HOME"/Desktop/*.desktop 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Desktop shortcuts created"
}

# ============== COMPLETION ==============
show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'COMPLETE'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║         ✅  INSTALLATION COMPLETE!  ✅                        ║
    ║                                                               ║
    ║              🎉 100% - All Done! 🎉                           ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

COMPLETE
    echo -e "${NC}"

    echo -e "${WHITE}📱 Your Mobile Desktop Lab is ready!${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}🚀 TO START THE DESKTOP:${NC}"
    echo -e "   ${GREEN}bash ~/start-desktop.sh${NC}"
    echo ""
    echo -e "${WHITE}🛑 TO STOP THE DESKTOP:${NC}"
    echo -e "   ${GREEN}bash ~/stop-desktop.sh${NC}"
    echo ""
    echo -e "${WHITE}🔍 TO CHECK GPU RENDERER:${NC}"
    echo -e "   ${GREEN}bash ~/check-gpu.sh${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}📦 INSTALLED TOOLS:${NC}"
    echo -e "   • XFCE4 Desktop + Termux-X11"
    echo -e "   • PulseAudio"
    echo -e "   • Firefox, VS Code, Git, Wget, cURL"
    echo -e "   • Python + requests + beautifulsoup4"
    echo -e "   • Windows Compatibility (Wine/Hangover)"
    echo -e "   • GPU Acceleration (when supported)"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}📄 Installation log:${NC} ${LOG_FILE}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}⚡ TIP: Open the Termux-X11 app first, then run start-desktop.sh${NC}"
    echo ""
}

# ============== MAIN INSTALLATION ==============
main() {
    : > "$LOG_FILE"
    show_banner

    check_termux
    check_storage

    echo -e "${WHITE}  This script will install a complete Linux desktop with${NC}"
    echo -e "${WHITE}  productivity tools and GPU acceleration on your Android phone.${NC}"
    echo ""
    echo -e "${GRAY}  Estimated time: 15-30 minutes (depends on internet speed)${NC}"
    echo ""
    echo -e "${YELLOW}  Press Enter to start installation, or Ctrl+C to cancel...${NC}"
    read -r

    detect_device
    step_update
    step_repos
    step_base_tools
    step_x11
    step_desktop
    step_gpu
    step_audio
    step_apps
    step_python
    step_wine

    create_launchers
    create_shortcuts

    show_completion
}

# ============== RUN ==============
main "$@"