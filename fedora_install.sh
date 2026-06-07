#!/bin/bash
# =============================================================================
# FEDORA MINIMALIST INSTALLER
# Tested on: Fedora Everything 44
# Supports: AMD / Intel CPU — NVIDIA / AMD / Intel GPU — Laptop & Desktop
# =============================================================================
set -euo pipefail


# ARGUMENT PARSING (--dry-run)
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    echo "============================================="
    echo " ⚠️ DRY RUN MODE ACTIVATED ⚠️"
    echo " No system changes will be made."
    echo "============================================="
fi

# LOGGING
LOG_FILE="install.log"
if [[ "$DRY_RUN" -eq 0 ]]; then
    exec > >(tee -i "$LOG_FILE")
    exec 2>&1
fi

echo "============================================="
echo " FEDORA MINIMALIST INSTALLER"
echo "============================================="

# HARDWARE DETECTION
# Deterministic hardware mapping via sysfs and cached PCI bus output.
detect_hardware() {
    # CPU vendor
    if grep -qi "AuthenticAMD" /proc/cpuinfo; then
        CPU_VENDOR="amd"
    elif grep -qi "GenuineIntel" /proc/cpuinfo; then
        CPU_VENDOR="intel"
    else
        CPU_VENDOR="unknown"
    fi

    # Form factor detection using DMI chassis type
    CHASSIS_TYPE=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "3")
    if [[ "$CHASSIS_TYPE" =~ ^(8|9|10|11|14|31|32)$ ]]; then
        FORM_FACTOR="laptop"
    else
        FORM_FACTOR="desktop"
    fi

    # Cache lspci output once to reduce I/O overhead and prevent pipefail crashes
    LSPCI_OUTPUT=$(lspci -nn 2>/dev/null || true)

    # iGPU detection: explicitly seeking Intel Display/VGA controllers
    if echo "$LSPCI_OUTPUT" | grep -iE 'VGA|Display' | grep -qi "Intel"; then
        IGPU_VENDOR="intel"
    else
        IGPU_VENDOR="none"
    fi

    # dGPU detection: explicitly seeking NVIDIA 3D/VGA controllers
    if echo "$LSPCI_OUTPUT" | grep -iE '3D|VGA' | grep -qi "NVIDIA"; then
        DGPU_VENDOR="nvidia"
    else
        DGPU_VENDOR="none"
    fi

    # AMD GPU evaluation (counting controllers to avoid desktop vs laptop ambiguity)
    AMD_GPU_COUNT=$(echo "$LSPCI_OUTPUT" | grep -iE 'VGA|Display|3D' | grep -ciE "AMD|Advanced Micro Devices" || true)

    if [[ "$AMD_GPU_COUNT" -ge 2 ]]; then
        IGPU_VENDOR="amd"
        DGPU_VENDOR="amd"
    elif [[ "$AMD_GPU_COUNT" -eq 1 ]]; then
        if [[ "$IGPU_VENDOR" == "intel" ]]; then
            DGPU_VENDOR="amd" # Intel iGPU is present, so AMD is discrete
        else
            # Edge case: Laptop with discrete AMD GPU and disabled APU will be mapped as iGPU.
            # Driver installation remains correct despite semantic mismatch.
            IGPU_VENDOR="amd"
        fi
    fi

    echo ""
    echo "--- Detected Hardware ---"
    echo "CPU vendor    : $CPU_VENDOR"
    echo "dGPU vendor   : $DGPU_VENDOR"
    echo "iGPU vendor   : $IGPU_VENDOR"
    echo "Form factor   : $FORM_FACTOR (Chassis ID: $CHASSIS_TYPE)"
    echo "-------------------------"
    echo ""
}

detect_hardware

# Stop execution if dry-run is active
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "--- Planned Execution ---"
    echo "1. Configure DNF with parallel downloads."
    echo "2. Install RPM Fusion Free/Non-Free."
    echo "3. Install minimal GNOME desktop environment."
    echo "4. Install microcode for $CPU_VENDOR."
    echo "5. Install audio stack, codecs, and Pipewire."
    echo "6. Install core tools (btop, kitty, flatpak, etc)."
    echo "7. Enable system services (tuned, firewalld, cups, fwupd)."
    echo "8. Install GPU drivers (Mesa/Vulkan/NVIDIA based on detection)."
    echo "9. Configure Plymouth boot splash."
    echo "10. Setup memory pressure management (zram = 50% RAM)."
    echo "11. Install Flatpak applications (Brave, ExtensionManager)."
    echo "============================================="
    echo " Dry run completed. Execute without flags to install."
    exit 0
fi

# 1. DNF — SPEED OPTIMIZATIONS
echo "[1/17] Configuring DNF..."

sudo sed -i -E '/^(max_parallel_downloads|max_downloads_per_mirror|fastestmirror|minrate|timeout)=/d' \
    /etc/dnf/dnf.conf

printf 'max_parallel_downloads=10\nfastestmirror=True\nminrate=1M\ntimeout=30\n' \
    | sudo tee -a /etc/dnf/dnf.conf > /dev/null

# 2. RPM FUSION
echo "[2/17] Adding RPM Fusion repositories..."

sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

sudo dnf makecache --refresh
sudo dnf upgrade -y


# 3. GNOME BASE
echo "[3/17] Installing GNOME desktop environment..."

sudo dnf install -y \
    @gnome-desktop \

sudo systemctl enable --now NetworkManager


# 4. CPU MICROCODE
echo "[4/17] Installing CPU microcode for: $CPU_VENDOR..."

case "$CPU_VENDOR" in
    amd)
        sudo dnf install -y amd-ucode-firmware --setopt=install_weak_deps=False
        ;;
    intel)
        sudo dnf install -y microcode_ctl --setopt=install_weak_deps=False
        ;;
    *)
        echo "WARN: Unknown CPU vendor. Skipping microcode installation."
        ;;
esac


# 5. AUDIO & CODECS
echo "[5/17] Installing audio stack and codecs..."

sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y \
    alsa-utils \
    gstreamer1-libav \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-good \
    gstreamer1-plugins-ugly \
    libldac \
    pipewire-codec-aptx \
    pipewire-jack-audio-connection-kit \
    pipewire-utils \
    --setopt=install_weak_deps=False


# 6. CORE TOOLS
echo "[6/17] Installing core tools..."

sudo dnf install -y \
    btop \
    fastfetch \
    flatpak \
    xdg-desktop-portal-gnome \
    kitty \
    --setopt=install_weak_deps=False


# 7. SYSTEM SERVICES
echo "[7/17] Installing and enabling system services..."

# Primero aseguramos la instalación del demonio de energía de GNOME
sudo dnf install -y power-profiles-daemon --setopt=install_weak_deps=False

# Ahora sí, habilitamos el servicio nativo
sudo systemctl enable --now power-profiles-daemon.service

if [[ "$FORM_FACTOR" == "laptop" ]]; then
    sudo systemctl enable --now bluetooth.service
else
    read -rp "Enable Bluetooth service? (y/n): " bt_choice
    [[ "$bt_choice" =~ ^[Yy]$ ]] && sudo systemctl enable --now bluetooth.service \
        || echo "Bluetooth skipped."
fi


# 8. FILESYSTEMS & COMPRESSION
echo "[8/17] Installing filesystem support and compression tools..."

sudo dnf install -y \
    fuse-exfat \
    ntfs-3g \
    p7zip \
    p7zip-plugins \
    unrar \
    unzip \
    zip \
    --setopt=install_weak_deps=False


# 9. VISUAL & FONTS
echo "[9/17] Installing fonts and visual libraries..."

sudo dnf install -y \
    ffmpegthumbnailer \
    gdk-pixbuf2-modules-extra \
    google-noto-sans-fonts \
    google-roboto-fonts \
    librsvg2-tools \
    --setopt=install_weak_deps=False


# 10. HARDWARE, PRINTING & SECURITY
echo "[10/17] Installing hardware support, printing stack, and security tools..."

sudo dnf install -y \
    avahi \
    ca-certificates \
    cups \
    cups-filters \
    firewalld \
    fwupd \
    lm_sensors \
    nss-mdns \
    openssl \
    --allowerasing --setopt=install_weak_deps=False

sudo systemctl enable --now firewalld
sudo firewall-cmd --set-default-zone=public
sudo firewall-cmd --permanent --zone=public --add-service=mdns
sudo firewall-cmd --reload

sudo systemctl enable --now cups
sudo cupsctl --no-remote-any --no-remote-admin --no-share-printers
sudo systemctl enable --now avahi-daemon.socket
sudo systemctl enable --now fwupd.service
sudo systemctl enable --now fstrim.timer


# 11. GPU DRIVERS
echo "[11/17] Installing GPU drivers for iGPU=$IGPU_VENDOR / dGPU=$DGPU_VENDOR..."

if [[ "$IGPU_VENDOR" == "amd" || "$DGPU_VENDOR" == "amd" ]]; then
    sudo dnf install -y \
        mesa-va-drivers \
        mesa-vulkan-drivers \
        xorg-x11-drv-amdgpu \
        --setopt=install_weak_deps=False
fi

if [[ "$IGPU_VENDOR" == "intel" ]]; then
    sudo dnf install -y \
        intel-media-driver \
        mesa-vulkan-drivers \
        --setopt=install_weak_deps=False
fi

install_nvidia() {
    sudo dnf makecache
    sudo dnf install -y \
        akmod-nvidia \
        kernel-devel \
        kernel-headers \
        libva-nvidia-driver \
        nvidia-modprobe \
        nvidia-settings \
        nvidia-vaapi-driver \
        vulkan-loader \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-power \

    if [[ "$FORM_FACTOR" == "laptop" && "$IGPU_VENDOR" != "none" ]]; then
        sudo dnf install -y switcheroo-control --setopt=install_weak_deps=False
        sudo systemctl enable --now switcheroo-control.service
    fi

    sudo grubby --update-kernel=ALL \
        --args="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

    echo "options nvidia-drm modeset=1 fbdev=1" \
        | sudo tee /etc/modprobe.d/nvidia-drm.conf > /dev/null

    echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_DynamicPowerManagement=0x02" \
        | sudo tee /etc/modprobe.d/nvidia-power-management.conf > /dev/null

    sudo systemctl enable nvidia-suspend.service
    sudo systemctl enable nvidia-hibernate.service
    sudo systemctl enable nvidia-resume.service
    sudo systemctl enable --now nvidia-powerd.service

    echo "Compiling NVIDIA kernel module (may take 5–10 min)..."
    if ! sudo akmods --akmod nvidia; then
        echo "WARN: akmods compilation deferred to first boot."
    fi
}

case "$DGPU_VENDOR" in
    nvidia)
        install_nvidia
        ;;
    amd)
        # AMD discrete drivers handled via unified mesa block above. No extra actions required.
        echo "Discrete AMD GPU configured successfully."
        ;;
    none)
        echo "No discrete GPU detected."
        read -rp "Force NVIDIA driver install anyway? (y/n): " force_nv
        [[ "$force_nv" =~ ^[Yy]$ ]] && install_nvidia
        ;;
esac


# 12. DISPLAY & INTERFACE
echo "[12/17] Setting graphical target and enabling GDM..."

sudo systemctl enable gdm
sudo systemctl set-default graphical.target


# 13. PLYMOUTH
echo "[13/17] Configuring Plymouth boot splash..."

configure_plymouth_splash() {
    sudo dnf install -y \
        plymouth \
        plymouth-system-theme \
        plymouth-graphics-libs \
        --setopt=install_weak_deps=False

    sudo grubby --update-kernel=ALL --args="rhgb quiet"

    if ! sudo plymouth-set-default-theme bgrt -R 2>/dev/null; then
        echo "plymouth-set-default-theme failed. Falling back to dracut..."
        if ! sudo dracut -f --regenerate-all; then
            echo "ERROR: dracut failed. Boot splash may not display correctly."
        fi
    fi
}

configure_plymouth_splash


# 14. TABLET & GRAPHICS LIBS
echo "[14/17] Installing tablet and graphics libraries..."

sudo dnf install -y \
    libwacom \
    mesa-libGLU \
    --setopt=install_weak_deps=False

# Verifying package availability explicitly resolving network/cache states with standard I/O redirection
if dnf list available digimend-kernel-drivers > /dev/null 2>&1; then
    sudo dnf install -y digimend-kernel-drivers --setopt=install_weak_deps=False
else
    echo "INFO: digimend-kernel-drivers not available in configured repos."
    echo "      If your drawing tablet lacks pressure support natively, manually enable the COPR:"
    echo "      sudo dnf copr enable luya/digimend && sudo dnf install -y digimend-kernel-drivers"
fi


# 15. 32-BIT COMPAT
install_32bit_compat() {
    sudo dnf install -y \
        gamemode \
        gamescope \
        libglvnd-egl.i686 \
        libglvnd-glx.i686 \
        libglvnd.i686 \
        mesa-dri-drivers.i686 \
        mesa-libGL.i686 \
        pipewire-alsa.i686 \
        steam-devices \
        vulkan-loader.i686 \
        --setopt=install_weak_deps=False --skip-unavailable \
        || echo "WARN: Partial failure on 32-bit libs."

    if [[ "$DGPU_VENDOR" == "nvidia" ]]; then
        sudo dnf install -y \
            xorg-x11-drv-nvidia-libs.i686 \
            --skip-unavailable \
            || echo "WARN: NVIDIA 32-bit libs install failed."
    fi
}

echo "[15/17] 32-bit gaming compatibility..."
read -rp "Install 32-bit gaming compat (Steam/Wine/Vulkan/GameMode/Gamescope)? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    install_32bit_compat
else
    echo "32-bit compat skipped."
fi


# 16. MEMORY PRESSURE MANAGEMENT
echo "[16/17] Configuring zram and memory pressure management..."

sudo dnf install -y zram-generator --setopt=install_weak_deps=False

sudo tee /etc/systemd/zram-generator.conf > /dev/null << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

sudo systemctl daemon-reload

if ! sudo systemctl start systemd-zram-setup@zram0.service; then
    echo "WARN: zram activation failed. It will activate on next boot."
fi

sudo systemctl enable --now systemd-oomd.service
sudo systemctl daemon-reexec


# 17. FLATPAK
echo "[17/17] Installing Flatpak applications..."

sudo flatpak remote-add --system --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo

APPS=(
    "com.brave.Browser"
)

MAX_RETRIES=3

for app in "${APPS[@]}"; do
    echo "Installing $app..."
    installed=0
    for attempt in $(seq 1 "$MAX_RETRIES"); do
        if sudo flatpak install --system -y flathub "$app"; then
            installed=1
            break
        fi
        echo "Attempt $attempt/$MAX_RETRIES failed for $app."
        [[ $attempt -lt $MAX_RETRIES ]] && sleep 5
    done

    if [[ "$installed" -eq 0 ]]; then
        echo "ERROR: $app could not be installed after $MAX_RETRIES attempts. Aborting."
        exit 1
    fi
done

sudo flatpak override --system --filesystem=xdg-config/gtk-4.0:ro
sudo flatpak override --system --filesystem=xdg-config/gtk-3.0:ro
sudo flatpak update --system -y


# CLEANUP
echo "Running cleanup..."
sudo dnf remove -y tigervnc-server tigervnc-license 2>/dev/null || true
sudo dnf autoremove -y


# DONE
echo ""
echo "============================================="
echo " INSTALLATION COMPLETE"
echo " Full log saved to: $LOG_FILE"
echo "============================================="
echo ""
echo "Hardware summary:"
echo "  CPU    : $CPU_VENDOR"
echo "  iGPU   : $IGPU_VENDOR"
echo "  dGPU   : $DGPU_VENDOR"
echo "  Type   : $FORM_FACTOR"
echo ""

read -rp "Reboot now? (y/n): " choice
[[ "$choice" =~ ^[Yy]$ ]] && reboot