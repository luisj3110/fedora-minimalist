#!/bin/bash
set -euo pipefail

# LOGGING
LOG_FILE="install.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "=================================================="
echo "FEDORA MINIMALIST INSTALLER  (By KKmole69)"
echo "=================================================="

# 1. DNF OPTIMIZATION
echo "[INFO] -> Optimizando configuración de DNF..."
sudo sed -i '/max_parallel_downloads/d' /etc/dnf/dnf.conf
sudo sed -i '/fastestmirror/d' /etc/dnf/dnf.conf
echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf

echo "[INFO] -> Configurando repositorios RPM Fusion..."
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo dnf makecache --refresh

sudo dnf upgrade -y

# 2. SISTEMA BASE
echo "[INFO] -> Instalando base de GNOME..."
sudo dnf install -y \
    gnome-shell gdm nautilus gnome-control-center \
    gnome-session mutter adwaita-icon-theme gnome-menus gnome-desktop3 \
    gnome-settings-daemon gvfs-mtp gvfs-archive \
    xdg-user-dirs-gtk desktop-backgrounds-gnome \
    polkit dconf NetworkManager \
    --setopt=install_weak_deps=False --skip-unavailable


# 3. MULTIMEDIA & UX
echo "[INFO] -> Instalando motores de software y audio..."
# AUDIO & CODECS
echo "[INFO] -> Configurando motor de audio y codecs..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y \
    libldac \
    pipewire \
    pipewire-alsa \
    pipewire-codec-aptx \
    pipewire-gstreamer \
    pipewire-pulseaudio \
    pipewire-utils \
    wireplumber \
    --setopt=install_weak_deps=False

# --- MULTIMEDIA FRAMEWORK ---
echo "[INFO] -> Instalando plugins de video y compatibilidad web..."
sudo dnf install -y \
    gstreamer1-libav \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    --setopt=install_weak_deps=False

# --- CORE SOFTWARE & TERMINAL ---
echo "[INFO] -> Instalando herramientas de productividad y sistema..."
sudo dnf install -y \
    btop \
    flatpak \
    gnome-disk-utility \
    gnome-terminal \
    gnome-tweaks \
    kitty \
    --setopt=install_weak_deps=False

# --- SYSTEM & UX INTEGRATION ---
echo "[INFO] -> Configurando integracion de escritorio y servicios..."
sudo dnf install -y \
    bluez \
    gnome-keyring \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    --setopt=install_weak_deps=False

# --- FILESYSTEMS & COMPRESSION ---
echo "[INFO] -> Soporte para discos externos y archivos comprimidos..."
sudo dnf install -y \
    fuse-exfat \
    ntfs-3g \
    p7zip \
    p7zip-plugins \
    unrar \
    unzip \
    zip \
    --setopt=install_weak_deps=False

# --- VISUAL EXPERIENCE (THUMBNAILS & FONTS) ---
echo "[INFO] -> Renderizado de miniaturas y fuentes base..."
sudo dnf install -y \
    ffmpegthumbnailer \
    gdk-pixbuf2-modules-extra \
    google-noto-sans-fonts \
    google-roboto-fonts \
    librsvg2-tools \
    --setopt=install_weak_deps=False

# --- LAPTOP HARDWARE & PRINTING ---
echo "[INFO] -> Optimizacion de energia y servicios de red..."
sudo dnf install -y \
    avahi \
    cups \
    cups-filters \
    firewalld \
    lm_sensors \
    nss-mdns \
    power-profiles-daemon \
    --setopt=install_weak_deps=False

echo "[INFO] -> Configurando seguridad y servicios de red..."
sudo dnf install -y \
    openssl \
    ca-certificates \
    --setopt=install_weak_deps=False

sudo firewall-cmd --permanent --add-service=cups
sudo firewall-cmd --permanent --add-service=mdns
sudo firewall-cmd --reload
sudo firewall-cmd --set-default-zone=public
sudo systemctl enable avahi-daemon
sudo systemctl enable cups
sudo systemctl enable firewalld


# 4. HARDWARE & ESTABILIDAD
echo "[INFO] -> Microcódigo y soporte de energía..."
sudo dnf install -y amd-ucode-firmware fwupd --setopt=install_weak_deps=False

sudo systemctl enable --now fwupd.service fstrim.timer
sudo systemctl enable --now bluetooth.service

# 5. ACTIVAR INTERFAZ
sudo systemctl enable gdm
sudo systemctl set-default graphical.target

# 6. STACK GRÁFICO (NVIDIA)
install_nvidia() {
    echo "[INFO] -> Refrescando metadatos..."
    sudo dnf makecache

    echo "[INFO] -> Instalando drivers NVIDIA..."
    sudo dnf install -y \
        akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings \
        libva-nvidia-driver kernel-devel kernel-headers xorg-x11-server-Xwayland \
        mesa-dri-drivers vulkan-loader vulkan-tools \
        --skip-unavailable

    echo "[INFO] -> Iniciando compilación de módulos..."
    sudo akmods --akmod nvidia
    
    echo "[INFO] -> Sincronizando kernel (Initramfs)..."
    sudo dracut --force --verbose
}

if lspci -nn | grep -qi nvidia; then
    install_nvidia
else
    echo "No se detectó una GPU NVIDIA..."
    read -p "¿Deseas instalar los drivers de NVIDIA de todas formas? (y/n): " force_nv
    [[ "$force_nv" =~ ^[Yy]$ ]] && install_nvidia
fi

# 7. LIBRERÍAS & TABLETAS GRÁFICAS
sudo dnf install -y \
    libwacom xorg-x11-drv-wacom \
    libX11 libXcursor libXi libXrandr mesa-libGLU \
    libxkbcommon libxkbcommon-x11 \
    --setopt=install_weak_deps=False --skip-unavailable

# COMPATIBILIDAD 32-BIT (GAMING)
install_32bit_compat() {
    echo "[INFO] -> Instalando librerías 32-bit y compatibilidad con juegos..."

    # Base OpenGL / Mesa 32-bit
    sudo dnf install -y \
        mesa-dri-drivers.i686 \
        mesa-libGL.i686 \
        libglvnd-glx.i686 \
        vulkan-loader.i686 \
        gamemode \
        gamescope \
        --setopt=install_weak_deps=False --skip-unavailable || {
        echo "[WARN] Fallo parcial en librerías Mesa 32-bit"
    }

    # Si hay NVIDIA, se añade el soporte para 32-bit
    if lspci -nn | grep -qi nvidia; then
        echo "[INFO] -> Detectada GPU NVIDIA, instalando librerías 32-bit correspondientes..."

        sudo dnf install -y \
            xorg-x11-drv-nvidia-libs.i686 \
            --skip-unavailable || {
            echo "[WARN] No se pudieron instalar librerías NVIDIA 32-bit"
        }
    else
        echo "[INFO] -> No se detectó NVIDIA, usando stack Mesa 32-bit"
    fi

    echo "[INFO] -> Compatibilidad 32-bit y paquetes gaming instalados correctamente"
}

# Pregunta interactiva
read -p "¿Desea instalar compatibilidad para juegos y librerías 32-bit? (Steam/Wine, Vulkan 32-bit, GameMode, Gamescope) (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    install_32bit_compat
else
    echo "[INFO] -> Se omitió la compatibilidad para juegos y librerías 32-bit"
fi


# 8. APPS & PERSONALIZACIÓN
if ! command -v flatpak &> /dev/null; then
    echo "[RETRY] Flatpak no encontrado. Intentando instalar nuevamente..."
    sudo dnf install -y flatpak
fi

echo "[INFO] -> Instalando aplicaciones..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub -y \
    com.brave.Browser \
    org.gnome.Showtime \
    org.gnome.Loupe \
    org.gnome.Calculator \
    org.gnome.TextEditor \
    org.gnome.Decibels \
    com.mattjakeman.ExtensionManager \
    net.nokyan.Resources

flatpak update -y

# 9. LIMPIEZA
sudo dnf autoremove -y

echo "========================"
echo "INSTALACIÓN COMPLETADA"
echo "========================"

read -p "¿Reiniciar ahora? (y/n): " choice
[[ "$choice" =~ ^[Yy]$ ]] && reboot