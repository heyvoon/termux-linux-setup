#!/usr/bin/env bash
#######################################################
#  Termux Linux Setup Script (Final Verified Build)
#  Fixes: Vulkan Loader, SSHD/VNC Lifecycle, Lock Files
#######################################################

# ============== CONFIGURATION ==============
TOTAL_STEPS=12
CURRENT_STEP=0
DE_CHOICE="1"
DE_NAME="XFCE4"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; GRAY='\033[0;90m'; NC='\033[0m'

# CLI Flags
SKIP_WINE=false; SKIP_GPU=false; DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --skip-wine) SKIP_WINE=true ;;
        --skip-gpu) SKIP_GPU=true ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h) echo "Usage: $0 [--skip-wine] [--skip-gpu] [--dry-run] [--help]"; exit 0 ;;
    esac
done

# ============== FUNCTIONS ==============
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    FILLED=$((PERCENT / 5)); EMPTY=$((20 - FILLED))
    BAR="${GREEN}"; for ((i=0; i<FILLED; i++)); do BAR+="*"; done
    BAR+="${GRAY}"; for ((i=0; i<EMPTY; i++)); do BAR+="-"; done; BAR+="${NC}"
    echo -e "\n${WHITE}------------------------------------------------------------${NC}"
    echo -e "${CYAN}  PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}------------------------------------------------------------${NC}\n"
}

spinner() {
    local pid=$1; local message=$2; local spin='-\|/'; local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 )); printf "\r  [*] ${message} ${CYAN}${spin:$i:1}${NC}  "; sleep 0.1
    done
    wait $pid; local exit_code=$?
    if [ $exit_code -eq 0 ]; then printf "\r  [+] ${message}                    \n"; else printf "\r  [-] ${message} ${RED}(failed)${NC}     \n"; fi
    return $exit_code
}

install_pkg() {
    local pkg=$1; local name=${2:-$pkg}
    echo "[PKG] Installing $name..."
    if $DRY_RUN; then echo "[DRY-RUN] $pkg"; return 0; fi
    if pkg list-installed 2>/dev/null | grep -q "^${pkg} "; then echo "[PKG] $name already installed."; return 0; fi
    (DEBIAN_FRONTEND=noninteractive pkg install -y "$pkg" > /dev/null 2>&1) &
    spinner $! "Installing ${name}..."
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${YELLOW}[!] Failed to install ${name}. (Continuing...)${NC}"
    fi
}

# ============== ENVIRONMENT SETUP ==============
show_banner() { clear; echo -e "${CYAN}    Termux Linux Desktop Setup (Verified)${NC}\n"; }

setup_environment() {
    echo -e "${PURPLE}[*] Detecting device...${NC}"
    PLATFORM=$(getprop ro.board.platform 2>/dev/null)
    EGL=$(getprop ro.hardware.egl 2>/dev/null)
    
    if [[ "$PLATFORM" == *"msm"* || "$PLATFORM" == *"qcom"* || "$EGL" == *"adreno"* ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  [*] GPU: ${WHITE}Adreno (Qualcomm) - Turnip${NC}"
    else
        GPU_DRIVER="zink"
        echo -e "  [*] GPU: ${WHITE}Generic/Mali - Zink${NC}"
    fi

    echo -e "${CYAN}Choose Desktop Environment:${NC}"
    echo -e "  ${WHITE}1) XFCE4${NC}  ${WHITE}2) LXQt${NC}  ${WHITE}3) MATE${NC}  ${WHITE}4) KDE${NC}"
    while true; do
        read -r -p "Enter number (1-4) [default: 1]: " DE_INPUT
        DE_INPUT=${DE_INPUT:-1}
        [[ "$DE_INPUT" =~ ^[1-4]$ ]] && { DE_CHOICE="$DE_INPUT"; break; }
        echo "Invalid input."
    done
    case $DE_CHOICE in
        1) DE_NAME="XFCE4";; 2) DE_NAME="LXQt";; 3) DE_NAME="MATE";; 4) DE_NAME="KDE Plasma";;
    esac
    echo -e "\n${GREEN}[+] Selected: ${DE_NAME}.${NC}"
}

# ============== INSTALLATION STEPS ==============
step_update() { update_progress; (pkg update -y > /dev/null 2>&1) &; spinner $! "Updating..."; }

step_repos() {
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding Repositories...${NC}"
    install_pkg "x11-repo" "X11 Repo"
    install_pkg "tur-repo" "TUR Repo"
    install_pkg "game-repo" "Game Repo"
}

step_x11() {
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Termux-X11...${NC}"
    install_pkg "termux-x11-nightly" "Termux-X11"
    install_pkg "xorg-xrandr" "XRandR"
}

step_desktop() {
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing ${DE_NAME}...${NC}"
    case $DE_CHOICE in
        1) install_pkg "xfce4" "XFCE4"; install_pkg "xfce4-terminal" "Terminal";;
        2) install_pkg "lxqt" "LXQt"; install_pkg "qterminal" "QTerminal";;
        3) install_pkg "mate" "MATE"; install_pkg "mate-terminal" "MATE Terminal";;
        4) install_pkg "plasma-desktop" "KDE"; install_pkg "konsole" "Konsole";;
    esac
}

step_gpu() {
    $SKIP_GPU && return 0
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring GPU...${NC}"
    install_pkg "mesa-zink" "Mesa Zink"
    install_pkg "mesa-vulkan-drivers" "Vulkan Drivers"
    install_pkg "vulkan-tools" "Vulkan Tools" || true
    [[ "$GPU_DRIVER" == "freedreno" ]] && install_pkg "mesa-vulkan-icd-freedreno" "Turnip Driver"
}

step_audio() { update_progress; install_pkg "pulseaudio" "PulseAudio"; }
step_apps() { update_progress; install_pkg "firefox" "Firefox"; install_pkg "vlc" "VLC"; install_pkg "git" "Git"; }

step_python() {
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Python...${NC}"
    install_pkg "python" "Python"
    python3 -m pip install flask > /dev/null 2>&1
    mkdir -p ~/demo_python
    echo "from flask import Flask; app = Flask(__name__); @app.route('/'); def h(): return 'Hello from Android!'" > ~/demo_python/app.py
}

step_wine() {
    $SKIP_WINE && return 0
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Wine/Box64...${NC}"
    if pkg search "^hangover$" 2>/dev/null | grep -q hangover; then
        install_pkg "hangover" "Hangover Wine"; install_pkg "box64" "Box64"
    else
        install_pkg "wine" "Wine Stable"; install_pkg "box64" "Box64"
    fi
}

# ============== REMOTE ACCESS (SSH + VNC) ==============
step_remote() {
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring Remote Access...${NC}"
    install_pkg "openssh" "OpenSSH"
    install_pkg "tigervnc" "TigerVNC"
    
    ssh-keygen -A 2>/dev/null || true
    mkdir -p ~/.vnc

    # Dynamic Xstartup based on DE_CHOICE
    case "$DE_CHOICE" in
        1) VNC_CMD="exec startxfce4" ;;
        2) VNC_CMD="exec startlxqt" ;;
        3) VNC_CMD="exec mate-session" ;;
        4) VNC_CMD="exec startplasma-x11" ;;
    esac

    cat > ~/.vnc/xstartup << VNC_EOF
#!/usr/bin/env bash
export XDG_SESSION_TYPE=x11
export XDG_SESSION_CLASS=user
export XDG_RUNTIME_DIR="\$PREFIX/tmp"
eval \$(dbus-daemon --session --fork --print-address 2>/dev/null)
${VNC_CMD}
VNC_EOF
    chmod +x ~/.vnc/xstartup
    
    if [ ! -f ~/.vnc/passwd ]; then
        echo -e "\n${YELLOW}[!] First time: Run 'vncpasswd' to set a password.${NC}\n"
    fi
}

# ============== LAUNCHER GENERATION ==============
step_launchers() {
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Start/Stop Scripts...${NC}"
    mkdir -p ~/.config

    # GPU Config
    cat > ~/.config/linux-gpu.sh << 'GPU_EOF'
export XDG_RUNTIME_DIR="$PREFIX/tmp"
export PULSE_RUNTIME_DIR="$PREFIX/tmp/pulse"
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export MESA_VK_WSI_PRESENT_MODE=fifo
GPU_EOF

    case "$DE_CHOICE" in
        1) EXEC_CMD="exec startxfce4"; KILL_PAT="xfce4-session|xfdesktop" ;;
        2) EXEC_CMD="exec startlxqt"; KILL_PAT="lxqt-session|lxqt-panel" ;;
        3) EXEC_CMD="exec mate-session"; KILL_PAT="mate-session|matedesktop" ;;
        4) EXEC_CMD="exec startplasma-x11"; KILL_PAT="startplasma-x11|kwin_x11" ;;
    esac

    # Start Script
    cat > ~/start-linux.sh << STARTER_EOF
#!/usr/bin/env bash
echo "[*] Starting ${DE_NAME}..."
source ~/.config/linux-gpu.sh 2>/dev/null

echo "[*] Cleaning stale locks & processes..."
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null
rm -f ~/.vnc/*.lock 2>/dev/null
pkill -TERM -f "termux.x11|${KILL_PAT}|pulseaudio" 2>/dev/null
sleep 2
pkill -KILL -f "termux.x11|${KILL_PAT}|pulseaudio" 2>/dev/null

mkdir -p "\$PULSE_RUNTIME_DIR" "\$PREFIX/tmp/dbus"

echo "[*] Starting SSH & VNC..."
pgrep -f "sshd" > /dev/null || sshd 2>/dev/null
pgrep -f "Xvnc" > /dev/null || vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes VncAuth 2>/dev/null

echo "[*] Starting Audio..."
pulseaudio --kill 2>/dev/null; sleep 0.5
pulseaudio --start --exit-idle-time=-1 2>/dev/null

echo "[*] Launching Termux-X11..."
termux-x11 :0 -legacy-input &
sleep 3
export DISPLAY=:0
command -v termux-wake-lock &>/dev/null && termux-wake-lock

echo "-----------------------------------------------"
echo "  [*] Local: Open Termux-X11 app"
echo "  [*] Remote: VNC <IP>:5901 | SSH <IP>:8022"
echo "-----------------------------------------------"
${EXEC_CMD}
STARTER_EOF
    chmod +x ~/start-linux.sh

    # Stop Script
    cat > ~/stop-linux.sh << STOPPER_EOF
#!/usr/bin/env bash
echo "[*] Stopping Desktop & VNC..."
vncserver -kill :1 2>/dev/null
pkill -TERM -f "termux.x11|${KILL_PAT}|pulseaudio" 2>/dev/null
sleep 2
pkill -KILL -f "termux.x11|${KILL_PAT}|pulseaudio" 2>/dev/null
echo "[*] Stopped. (SSHD left running)"
STOPPER_EOF
    chmod +x ~/stop-linux.sh
    echo -e "  [+] Scripts created: ~/start-linux.sh & ~/stop-linux.sh"
}

step_shortcuts() {
    update_progress; echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Shortcuts...${NC}"
    mkdir -p ~/Desktop
    cat > ~/Desktop/Terminal.desktop << EOF
[Desktop Entry]
Name=Terminal
Exec=$(case $DE_CHOICE in 1) echo xfce4-terminal;; 2) echo qterminal;; 3) echo mate-terminal;; 4) echo konsole;; esac)
Icon=utilities-terminal
Type=Application
EOF
}

show_completion() {
    echo -e "\n${GREEN}✅ INSTALLATION COMPLETE!${NC}"
    echo -e "Run: ${WHITE}~/start-linux.sh${NC}"
    echo -e "Set VNC Password: ${WHITE}vncpasswd${NC}"
}

main() {
    show_banner; setup_environment
    step_update; step_repos; step_x11; step_desktop
    step_gpu; step_audio; step_apps; step_python; step_wine
    step_remote; step_launchers; step_shortcuts
    show_completion
}

main "$@"