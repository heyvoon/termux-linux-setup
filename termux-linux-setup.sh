#!/usr/bin/env bash
#######################################################
#  Termux Linux Setup Script (Enhanced)
#  Features:
#  - Choice of Desktop Environment (XFCE, LXQt, MATE, KDE)
#  - Smart GPU acceleration detection (Turnip/Zink)
#  - Productivity & Media tools (Firefox, VLC, Pipewire/PA)
#  - Python & Web Dev environment pre-installed
#  - Windows App Support (Wine/Box64 with fallbacks)
#  - CLI flags: --skip-wine, --skip-gpu, --dry-run, --help
#######################################################

# ============== CONFIGURATION & PATHS ==============
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
LOGFILE="$HOME/termux-setup-$(date +%Y%m%d_%H%M%S).log"

# CLI Flags
SKIP_WINE=false
SKIP_GPU=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --skip-wine) SKIP_WINE=true ;;
        --skip-gpu) SKIP_GPU=true ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-wine    Skip Wine/Box64 installation"
            echo "  --skip-gpu     Skip GPU driver installation"
            echo "  --dry-run      Show commands without executing"
            echo "  --help, -h     Show this help message"
            exit 0
            ;;
        *) echo -e "\033[0;31mUnknown option: $arg\033[0m"; exit 1 ;;
    esac
done

# ============== LOGGING ==============
# Log everything, but keep terminal output clean
exec > >(tee -a "$LOGFILE") 2>&1

TOTAL_STEPS=12
CURRENT_STEP=0
DE_CHOICE="1"
DE_NAME="XFCE4"

# ============== COLORS ==============
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

# ============== PROGRESS & UX FUNCTIONS ==============
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    FILLED=$((PERCENT / 5))
    EMPTY=$((20 - FILLED))
    
    BAR="${GREEN}"
    for ((i=0; i<FILLED; i++)); do BAR+="*"; done
    BAR+="${GRAY}"
    for ((i=0; i<EMPTY; i++)); do BAR+="-"; done
    BAR+="${NC}"
    
    echo -e "\n${WHITE}------------------------------------------------------------${NC}"
    echo -e "${CYAN}  PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}------------------------------------------------------------${NC}\n"
}

spinner() {
    local pid=$1; local message=$2
    local spin='-\|/'; local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r  [*] ${message} ${CYAN}${spin:$i:1}${NC}  "
        sleep 0.1
    done
    wait $pid; local exit_code=$?
    printf "\r  %s %s                    \n" "[-]" "$message" > /dev/null
    if [ $exit_code -eq 0 ]; then
        printf "\r  [+] ${message}                    \n"
    else
        printf "\r  [-] ${message} ${RED}(failed)${NC}     \n"
    fi
    return $exit_code
}

safe_pkill() {
    local pattern=$1
    pkill -TERM -f "$pattern" 2>/dev/null || true
    sleep 1.5
    pkill -KILL -f "$pattern" 2>/dev/null || true
}

install_pkg() {
    local pkg=$1; local name=${2:-$pkg}
    echo "[PKG] Checking $name..."
    if $DRY_RUN; then echo "[DRY-RUN] Would install: $pkg"; return 0; fi
    if pkg list-installed 2>/dev/null | grep -q "^${pkg} "; then
        echo "[PKG] $name already installed. Skipping."
        return 0
    fi
    echo "[PKG] Installing $name..."
    (DEBIAN_FRONTEND=noninteractive pkg install -y "$pkg" > /dev/null 2>&1) &
    spinner $! "Installing ${name}..."
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}[-] Failed to install ${name}. See ${LOGFILE} for details.${NC}" >&2
        read -r -p "Continue anyway? (y/N) " cont
        [[ "$cont" =~ ^[Yy]$ ]] || exit 1
    fi
}

# ============== BANNER & ENV SETUP ==============
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    -------------------------------------------
       Termux Linux Desktop Setup Script
    -------------------------------------------
BANNER
    echo -e "${NC}"
}

setup_environment() {
    echo -e "${PURPLE}[*] Detecting device & hardware...${NC}"
    
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    PLATFORM=$(getprop ro.board.platform 2>/dev/null)
    EGL=$(getprop ro.hardware.egl 2>/dev/null)
    
    echo -e "  [*] Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  [*] Android: ${WHITE}${ANDROID_VERSION}${NC}"
    
    # Robust GPU Detection
    if [[ "$PLATFORM" == *"msm"* || "$PLATFORM" == *"qcom"* || "$EGL" == *"adreno"* ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  [*] GPU: ${WHITE}Adreno (Qualcomm) - Turnip Support${NC}"
    elif pkg search mesa-zink 2>/dev/null | grep -q mesa-zink; then
        GPU_DRIVER="zink"
        echo -e "  [*] GPU: ${WHITE}Generic/Vulkan - Zink OpenGL Driver${NC}"
        echo -e "${YELLOW}      [!] Tip: LXQt/XFCE recommended for smoother performance.${NC}"
    else
        GPU_DRIVER="llvmpipe"
        echo -e "  [*] GPU: ${WHITE}Software Rendering (LLVMpipe)${NC}"
        echo -e "${YELLOW}      [!] Hardware acceleration unavailable.${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}Please choose your Desktop Environment:${NC}"
    echo -e "  ${WHITE}1) XFCE4${NC}       (Recommended - Fast, Customizable, macOS style dock)"
    echo -e "  ${WHITE}2) LXQt${NC}        (Ultra lightweight - Best for low-end devices)"
    echo -e "  ${WHITE}3) MATE${NC}        (Classic UI, moderately heavy)"
    echo -e "  ${WHITE}4) KDE Plasma${NC}  (Heavy - Modern, requires strong GPU/RAM)"
    echo ""
    while true; do
        read -r -p "Enter number (1-4) [default: 1]: " DE_INPUT
        DE_INPUT=${DE_INPUT:-1}
        if [[ "$DE_INPUT" =~ ^[1-4]$ ]]; then
            DE_CHOICE="$DE_INPUT"
            break
        fi
        echo "Invalid input. Please enter 1, 2, 3, or 4."
    done
    
    case $DE_CHOICE in
        1) DE_NAME="XFCE4";;
        2) DE_NAME="LXQt";;
        3) DE_NAME="MATE";;
        4) DE_NAME="KDE Plasma";;
    esac
    echo -e "\n${GREEN}[+] Selected: ${DE_NAME}.${NC}"
    sleep 1
}

# ============== INSTALLATION STEPS ==============
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating package lists...${NC}"
    (DEBIAN_FRONTEND=noninteractive pkg update -y > /dev/null 2>&1) &
    spinner $! "Updating package lists..."
}

step_repos() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding required repositories...${NC}"
    install_pkg "x11-repo" "X11 Repository"
    install_pkg "tur-repo" "TUR Repository (Firefox)"
    install_pkg "game-repo" "Game/Emulation Repository (Box64, etc.)"
}

step_x11() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Termux-X11 Display Server...${NC}"
    install_pkg "termux-x11-nightly" "Termux-X11"
    install_pkg "xorg-xrandr" "XRandR"
}

step_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing ${DE_NAME} Desktop Environment...${NC}"
    
    case $DE_CHOICE in
        1)
            install_pkg "xfce4" "XFCE4"
            install_pkg "xfce4-terminal" "XFCE4 Terminal"
            install_pkg "xfce4-whiskermenu-plugin" "Whisker Menu"
            install_pkg "thunar" "Thunar"
            # Plank is deprecated in Termux. Fallback to Cairo-Dock or skip.
            if pkg search "^cairo-dock$" 2>/dev/null | grep -q cairo-dock; then
                install_pkg "cairo-dock" "Cairo-Dock (Plank Alternative)"
            else
                echo -e "${YELLOW}[!] Plank unavailable. Using built-in XFCE panel.${NC}"
            fi
            ;;
        2)
            install_pkg "lxqt" "LXQt"
            install_pkg "qterminal" "QTerminal"
            install_pkg "pcmanfm-qt" "PCManFM-Qt"
            ;;
        3)
            install_pkg "mate" "MATE"
            install_pkg "mate-tweak" "MATE Tweak"
            install_pkg "mate-terminal" "MATE Terminal"
            if pkg search "^cairo-dock$" 2>/dev/null | grep -q cairo-dock; then
                install_pkg "cairo-dock" "Cairo-Dock (Plank Alternative)"
            fi
            ;;
        4)
            install_pkg "plasma-desktop" "KDE Plasma"
            install_pkg "konsole" "Konsole"
            install_pkg "dolphin" "Dolphin"
            ;;
    esac
}

step_gpu() {
    $SKIP_GPU && return 0
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring GPU Acceleration...${NC}"
    
    install_pkg "mesa-zink" "Mesa Zink"
    install_pkg "mesa-vulkan-drivers" "Vulkan ICDs"
    # Termux bundles the Vulkan loader with mesa-vulkan-drivers now
    if pkg search "^vulkan-tools$" 2>/dev/null | grep -q vulkan-tools; then
        install_pkg "vulkan-tools" "Vulkan Tools (Loader+Validation)"
    else
        echo -e "${YELLOW}[!] vulkan-tools not found. Using Mesa-bundled loader.${NC}"
    fi
    [[ "$GPU_DRIVER" == "freedreno" ]] && install_pkg "mesa-vulkan-icd-freedreno" "Turnip Driver"
}

step_audio() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Audio Server...${NC}"
    install_pkg "pulseaudio" "PulseAudio"
}

step_apps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Productivity & Dev Apps...${NC}"
    install_pkg "firefox" "Firefox"
    install_pkg "vlc" "VLC"
    install_pkg "git" "Git"
    install_pkg "curl" "cURL"
}

step_python() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Setting up Python Environment...${NC}"
    install_pkg "python" "Python 3"
    
    echo "[PY] Installing Flask via pip..."
    python3 -m pip install --upgrade pip > /dev/null 2>&1
    python3 -m pip install flask > /dev/null 2>&1
    
    mkdir -p ~/demo_python
    cat > ~/demo_python/app.py << 'EOF'
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return """
    <html>
        <body style="background:#1e1e1e;color:#00ff00;font-family:monospace;text-align:center;padding:50px">
            <h1>Hardware Accelerated Linux</h1>
            <h3>Python Flask server running natively on Android!</h3>
        </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
    echo -e "  [+] Demo server created in ~/demo_python"
}

step_wine() {
    $SKIP_WINE && return 0
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Windows Compatibility Layer...${NC}"
    
    if pkg search "^hangover$" 2>/dev/null | grep -q hangover; then
        install_pkg "hangover" "Hangover Wine"
        echo -e "${GREEN}[+] Hangover includes built-in Box64/Box84 wrappers.${NC}"
        echo "export PATH=$PREFIX/opt/hangover/bin:\$PATH" > "$PREFIX/etc/profile.d/wine.sh"
        chmod +x "$PREFIX/etc/profile.d/wine.sh"
    else
        echo -e "${YELLOW}[!] Hangover not available. Installing standard Wine + Box64...${NC}"
        install_pkg "wine" "Wine Stable"
        if pkg search "^box64$" 2>/dev/null | grep -q box64; then
            install_pkg "box64" "Box64 Emulator"
        else
            echo -e "${YELLOW}[!] Box64 not in repo. Running 32-bit Wine only.${NC}"
        fi
    fi
}

step_remote() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring Remote Access (SSH & VNC)...${NC}"
    install_pkg "openssh" "OpenSSH Server"
    install_pkg "tigervnc" "TigerVNC Server"

    # Generate SSH host keys if missing
    ssh-keygen -A 2>/dev/null || true

    # Create VNC startup configuration
    mkdir -p ~/.vnc
    cat > ~/.vnc/xstartup << 'VNC_EOF'
#!/usr/bin/env bash
export XDG_SESSION_TYPE=x11
export XDG_SESSION_CLASS=user
export XDG_RUNTIME_DIR="$PREFIX/tmp"
eval $(dbus-daemon --session --fork --print-address 2>/dev/null)
exec startxfce4
VNC_EOF
    chmod +x ~/.vnc/xstartup

    # Prompt for VNC password if not set
    if [ ! -f ~/.vnc/passwd ]; then
        echo -e "\n${YELLOW}[!] VNC password not set. Please run:${NC} vncpasswd"
    else
        echo -e "${GREEN}[+] VNC password already configured.${NC}"
    fi
    echo -e "${GREEN}[+] Remote access configured. Will auto-start with desktop.${NC}\n"
}

step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Startup/Stop Scripts...${NC}"
    mkdir -p ~/.config

    # Clean old autostarts & cached sessions
    rm -f ~/.config/autostart/plank.desktop ~/.config/autostart/cairo-dock.desktop 2>/dev/null
    rm -rf ~/.cache/sessions/* 2>/dev/null

    # GPU/Env Config
    cat > ~/.config/linux-gpu.sh << 'GPU_EOF'
export XDG_RUNTIME_DIR="$PREFIX/tmp"
export PULSE_RUNTIME_DIR="$PREFIX/tmp/pulse"
export XDG_SESSION_TYPE=x11
export XDG_SESSION_CLASS=user
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=fifo
GPU_EOF

    if [ "$DE_CHOICE" == "4" ]; then
        echo 'export KWIN_USE_SW_COMPOSITION=0' >> ~/.config/linux-gpu.sh
        echo 'export PLASMA_USE_QT_SCALING=1' >> ~/.config/linux-gpu.sh
    fi

    # DE commands
    case "$DE_CHOICE" in
        1) EXEC_CMD="exec startxfce4"; KILL_PAT="xfce4-session|xfdesktop" ;;
        2) EXEC_CMD="exec startlxqt"; KILL_PAT="lxqt-session|lxqt-panel" ;;
        3) EXEC_CMD="exec mate-session"; KILL_PAT="mate-session|matedesktop" ;;
        4) EXEC_CMD="exec startplasma-x11"; KILL_PAT="startplasma-x11|kwin_x11|plasmashell" ;;
    esac

    # 🟢 STARTER SCRIPT (Starts SSHD + VNC + X11 + DE)
    cat > ~/start-linux.sh << STARTER_EOF
#!/usr/bin/env bash
echo "[*] Starting ${DE_NAME} on Android..."
source ~/.config/linux-gpu.sh 2>/dev/null

echo "[*] Cleaning old sessions..."
pkill -9 -f "termux.x11" 2>/dev/null || true
pkill -9 -f "${KILL_PAT}" 2>/dev/null || true
pkill -9 -f "pulseaudio|pipewire" 2>/dev/null || true
sleep 2

rm -rf "\$PULSE_RUNTIME_DIR" 2>/dev/null
mkdir -p "\$PULSE_RUNTIME_DIR" "\$PREFIX/tmp/dbus"

echo "[*] Starting SSH server (port 8022)..."
if ! pgrep -f "sshd" > /dev/null 2>&1; then
    sshd 2>/dev/null || echo "[!] SSHD failed"
else
    echo "[*] SSHD already running."
fi

echo "[*] Starting VNC server (display :1, port 5901)..."
if ! pgrep -f "Xvnc" > /dev/null 2>&1; then
    vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes VncAuth 2>/dev/null || echo "[!] VNC failed"
else
    echo "[*] VNC already running."
fi

echo "[*] Starting audio..."
pulseaudio --start --exit-idle-time=-1 --disallow-exit 2>/dev/null
export PULSE_SERVER="\$PULSE_RUNTIME_DIR/native"

echo "[*] Launching Termux-X11..."
termux-x11 :0 -legacy-input &
sleep 4
export DISPLAY=:0

echo "-----------------------------------------------"
echo "  [*] Open Termux-X11 app for local display!"
echo "  [*] Connect via VNC to <IP>:5901 for remote!"
echo "  [*] SSH via: ssh \$USER@<IP> -p 8022"
echo "-----------------------------------------------"

xfconf-query -c xfce4-session -p /startup/ssh-agent/enabled -n -t bool -s false 2>/dev/null || true
${EXEC_CMD}
STARTER_EOF
    chmod +x ~/start-linux.sh

    # 🔴 STOPPER SCRIPT (Stops VNC + DE, leaves SSHD running)
    cat > ~/stop-linux.sh << STOPPER_EOF
#!/usr/bin/env bash
echo "[*] Stopping Desktop & VNC..."
pkill -9 -f "termux.x11" 2>/dev/null || true
pkill -9 -f "${KILL_PAT}" 2>/dev/null || true
pkill -9 -f "pulseaudio|pipewire" 2>/dev/null || true

# Stop VNC cleanly
vncserver -kill :1 2>/dev/null || true

# Note: SSHD left running for background remote access.
# To stop SSHD manually: pkill sshd
echo "[*] Desktop stopped. SSH remains active."
STOPPER_EOF
    chmod +x ~/stop-linux.sh
    echo -e "  [+] Created ~/start-linux.sh & ~/stop-linux.sh"
}

step_shortcuts() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Desktop Shortcuts...${NC}"
    mkdir -p ~/Desktop
    
    for app in firefox vlc; do
        cat > ~/Desktop/${app^}.desktop << EOF
[Desktop Entry]
Name=${app^}
Exec=${app}
Icon=${app}
Type=Application
EOF
    done

    cat > ~/Desktop/Wine_Config.desktop << 'EOF'
[Desktop Entry]
Name=Wine Configuration
Exec=winecfg
Icon=wine
Type=Application
EOF

    # Dynamic Terminal
    TERM_CMD=$(case $DE_CHOICE in 1) echo xfce4-terminal;; 2) echo qterminal;; 3) echo mate-terminal;; 4) echo konsole;; esac)
    cat > ~/Desktop/Terminal.desktop << EOF
[Desktop Entry]
Name=Terminal
Exec=${TERM_CMD}
Icon=utilities-terminal
Type=Application
EOF
    chmod +x ~/Desktop/*.desktop 2>/dev/null
    echo -e "  [+] Added desktop shortcuts."
}

show_completion() {
    echo -e "\n${GREEN}"
    cat << 'COMPLETE'
    ---------------------------------------------------------------
             [*]  INSTALLATION COMPLETE!  [*]
    ---------------------------------------------------------------
COMPLETE
    echo -e "${NC}"
    echo -e "${WHITE}[*] Your ${DE_NAME} environment is ready.${NC}"
    echo -e "${CYAN}[*] Key Components:${NC}"
    echo "    • Python (Flask demo: ~/demo_python/app.py)"
    echo "    • Firefox & VLC Media Player"
    $SKIP_WINE || echo "    • Wine/Box64 Windows Compatibility"
    $SKIP_GPU || echo "    • GPU Acceleration (Zink/Turnip)"
    echo ""
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo -e "${WHITE}▶ TO START:${NC}  ${GREEN}bash ~/start-linux.sh${NC}"
    echo -e "${WHITE}▶ TO STOP:${NC}   ${GREEN}bash ~/stop-linux.sh${NC}"
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo -e "\n${GRAY}📝 Log saved to: ${LOGFILE}${NC}\n"
}

# ============== MAIN EXECUTION ==============
main() {
    show_banner
    setup_environment
    
    step_update
    step_repos
    step_x11
    step_desktop
    step_gpu
    step_audio
    step_apps
    step_python
    step_wine
    step_remote      # ← NEW: Installs & configures SSH/VNC
    step_launchers   # ← Generates scripts that start/stop them
    step_shortcuts
    
    show_completion
}

main "$@"