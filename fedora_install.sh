#!/bin/bash
set -euo pipefail

LOG_FILE="install.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "FEDORA MINIMALIST INSTALLER"

# 1. DNF 
sudo sed -i -E '/^(max_parallel_downloads|max_downloads_per_mirror|fastestmirror|minrate|timeout)=/d' \
    /etc/dnf/dnf.conf

printf 'max_parallel_downloads=10\nfastestmirror=True\nminrate=1M\ntimeout=30\n' \
    | sudo tee -a /etc/dnf/dnf.conf

sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo dnf makecache --refresh
sudo dnf upgrade -y

# 2. GNOME BASE
sudo dnf install -y \
    gnome-shell \
    gdm \
    nautilus \
    gnome-control-center \
    gnome-session \
    mutter \
    adwaita-icon-theme \
    adwaita-cursor-theme \
    gnome-menus \
    gnome-desktop3 \
    gnome-desktop4 \
    gnome-settings-daemon \
    gsettings-desktop-schemas \
    gvfs \
    gvfs-mtp \
    gvfs-archive \
    gvfs-smb \
    gvfs-nfs \
    gnome-disk-utility \
    xdg-user-dirs-gtk \
    xdg-utils \
    desktop-backgrounds-gnome \
    polkit \
    polkit-gnome \
    dconf \
    NetworkManager \
    nm-connection-editor \
    glib-networking \
    libsecret \
    gnome-keyring \
    libnotify \
    xorg-x11-server-Xwayland \
    colord \
    colord-gtk \
    --skip-unavailable

sudo systemctl enable --now NetworkManager

# 3. AUDIO & CODECS
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y \
    pipewire \
    pipewire-alsa \
    pipewire-codec-aptx \
    pipewire-gstreamer \
    pipewire-pulseaudio \
    pipewire-utils \
    wireplumber \
    libldac \
    gstreamer1-libav \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    --setopt=install_weak_deps=False

# 4. CORE TOOLS
sudo dnf install -y \
    btop \
    flatpak \
    gnome-tweaks \
    kitty \
    gnome-disk-utility \
    --setopt=install_weak_deps=False

# 5. SYSTEM INTEGRATION
sudo dnf install -y \
    bluez \
    gnome-bluetooth \
    fastfetch \
    upower \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    --setopt=install_weak_deps=False --skip-unavailable

sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now tuned.service

# 6. FILESYSTEMS & COMPRESSION
sudo dnf install -y \
    fuse-exfat \
    ntfs-3g \
    p7zip \
    p7zip-plugins \
    unrar \
    unzip \
    zip \
    --setopt=install_weak_deps=False

# 7. VISUAL & FONTS
sudo dnf install -y \
    ffmpegthumbnailer \
    gdk-pixbuf2-modules-extra \
    google-noto-sans-fonts \
    google-roboto-fonts \
    librsvg2-tools \
    --setopt=install_weak_deps=False

# 8. HARDWARE, PRINTING & SECURITY
sudo dnf install -y \
    avahi \
    cups \
    cups-filters \
    firewalld \
    lm_sensors \
    nss-mdns \
    openssl \
    ca-certificates \
    amd-ucode-firmware \
    fwupd \
    --allowerasing --setopt=install_weak_deps=False

sudo systemctl enable --now firewalld

sudo firewall-cmd --set-default-zone=public

sudo firewall-cmd --permanent --zone=home --add-service=mdns

sudo cupsctl --no-remote-any --no-remote-admin --no-share-printers

sudo firewall-cmd --reload

sudo systemctl enable avahi-daemon
sudo systemctl enable cups
sudo systemctl enable --now fwupd.service
sudo systemctl enable --now fstrim.timer

# 9. AMD iGPU (Ryzen 5 4600H — Radeon Vega)
sudo dnf install -y \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    libva-mesa-driver \
    mesa-va-drivers \
    --setopt=install_weak_deps=False

# 10. DISPLAY & INTERFACE
sudo systemctl enable gdm
sudo systemctl set-default graphical.target

# 11. NVIDIA
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
        switcheroo-control \
        vulkan-loader \
        vulkan-tools \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-power \
        --skip-unavailable

    sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1 nvidia-drm.fbdev=1"

    echo "options nvidia-drm modeset=1 fbdev=1" \
        | sudo tee /etc/modprobe.d/nvidia-drm.conf

    echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_DynamicPowerManagement=0x02" \
        | sudo tee /etc/modprobe.d/nvidia-power-management.conf

    sudo systemctl enable nvidia-suspend.service
    sudo systemctl enable nvidia-hibernate.service
    sudo systemctl enable nvidia-resume.service

    sudo systemctl enable --now nvidia-powerd.service

    sudo systemctl enable --now switcheroo-control.service

    echo "Attempting NVIDIA module compilation (may take 5-10 min)..."
    sudo akmods --akmod nvidia || \
        echo "akmods compilation deferred to first boot."
}

# 12. PLYMOUTH
configure_plymouth_splash() {
    sudo dnf install -y \
        plymouth \
        plymouth-system-theme \
        plymouth-graphics-libs \
        --setopt=install_weak_deps=False

    sudo grubby --update-kernel=ALL --args="rhgb quiet"

    if ! sudo plymouth-set-default-theme bgrt -R; then
        sudo dracut -f --regenerate-all
    fi
}

if lspci -nn | grep -qi nvidia; then
    install_nvidia
else
    echo "No NVIDIA GPU detected."
    read -p "Force NVIDIA driver install? (y/n): " force_nv
    [[ "$force_nv" =~ ^[Yy]$ ]] && install_nvidia
fi

configure_plymouth_splash

# 13. TABLET & GRAPHICS LIBS
sudo dnf install -y \
    libwacom \
    libX11 \
    libXcursor \
    libXi \
    libXrandr \
    mesa-libGLU \
    libxkbcommon \
    libxkbcommon-x11 \
    --setopt=install_weak_deps=False --skip-unavailable

# 14. 32-BIT COMPAT (GAMING)
install_32bit_compat() {
    sudo dnf install -y \
        mesa-dri-drivers.i686 \
        mesa-libGL.i686 \
        libglvnd.i686 \
        libglvnd-glx.i686 \
        libglvnd-egl.i686 \
        vulkan-loader.i686 \
        pipewire-alsa.i686 \
        gamemode \
        gamescope \
        steam-devices \
        --setopt=install_weak_deps=False --skip-unavailable || \
        echo "WARN: partial failure on 32-bit libs"

    if lspci -nn | grep -qi nvidia; then
        sudo dnf install -y \
            xorg-x11-drv-nvidia-libs.i686 \
            --skip-unavailable || \
            echo "WARN: NVIDIA 32-bit libs install failed"
    fi
}

read -p "Install 32-bit gaming compat (Steam/Wine/Vulkan/GameMode/Gamescope)? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    install_32bit_compat
else
    echo "32-bit compat skipped."
fi

# 15. FLATPAK
flatpak remote-add --user --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo

flatpak install --user flathub -y \
    com.brave.Browser \
    org.gnome.Showtime \
    org.gnome.Loupe \
    org.gnome.Calculator \
    org.gnome.TextEditor \
    org.gnome.Decibels \
    com.mattjakeman.ExtensionManager \
    net.nokyan.Resources

flatpak override --user --filesystem=xdg-config/gtk-4.0:ro
flatpak override --user --filesystem=xdg-config/gtk-3.0:ro

flatpak update --user -y

# 16. CLEANUP
sudo dnf remove -y tigervnc-server tigervnc-license 2>/dev/null || true
sudo dnf autoremove -y

echo "INSTALLATION COMPLETE"

read -p "Reboot now? (y/n): " choice
[[ "$choice" =~ ^[Yy]$ ]] && reboot
