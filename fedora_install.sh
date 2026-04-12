#!/bin/bash
set -euo pipefail

# LOGGING
LOG_FILE="install.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "=================================================="
echo "FEDORA EVERYTHING INSTALLER MINIMAL (By KKmole69)"
echo "=================================================="

# 1. DNF OPTIMIZATION
echo "[INFO] -> Optimizando configuración de DNF..."
sudo sed -i '/max_parallel_downloads/d' /etc/dnf/dnf.conf
sudo sed -i '/fastestmirror/d' /etc/dnf/dnf.conf
echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf

# 2. SISTEMA BASE
echo "[INFO] -> Instalando base de GNOME..."
sudo dnf install -y \
    gnome-shell gdm nautilus gnome-control-center \
    gnome-session mutter adwaita-icon-theme gnome-menus gnome-desktop3 \
    gnome-settings-daemon gvfs-mtp gvfs-archive \
    xdg-user-dirs-gtk desktop-backgrounds-gnome \
    polkit dconf NetworkManager \
    --setopt=install_weak_deps=False --skip-unavailable || {
    echo "[WARN] Fallo parcial en instalación base GNOME"
}


# 3. MULTIMEDIA & UX
echo "[INFO] -> Instalando motores de software y audio..."

sudo dnf install -y flatpak pipewire wireplumber --setopt=install_weak_deps=False

sudo dnf install -y \
    pipewire pipewire-pulseaudio pipewire-alsa wireplumber \
    xdg-desktop-portal xdg-desktop-portal-gnome \
    gnome-terminal kitty gnome-disk-utility \
    gnome-keyring gnome-shell-extension-prefs \
    bluez \
    --setopt=install_weak_deps=False || {
    echo "[WARN] Fallo parcial en multimedia/UX"
}

# 4. HARDWARE & ESTABILIDAD
echo "[INFO] -> Microcódigo y soporte de energía..."
sudo dnf install -y amd-ucode-firmware fwupd --setopt=install_weak_deps=False || {
    echo "[WARN] Fallo en instalación de firmware"
}

sudo systemctl enable --now fwupd.service fstrim.timer
sudo systemctl enable --now bluetooth.service

# 5. ACTIVAR INTERFAZ
sudo systemctl enable gdm
sudo systemctl set-default graphical.target

# 6. STACK GRÁFICO (NVIDIA)
install_nvidia() {
    echo "[INFO] -> Configurando repositorios RPM Fusion..."
    sudo dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || {
        echo "[WARN] No se pudieron instalar repos RPM Fusion"
    }

    echo "[INFO] -> Refrescando metadatos..."
    sudo dnf makecache

    echo "[INFO] -> Instalando drivers NVIDIA..."
    sudo dnf install -y \
        akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-settings \
        libva-nvidia-driver kernel-devel kernel-headers xorg-x11-server-Xwayland \
        mesa-dri-drivers vulkan-loader vulkan-tools \
        --skip-unavailable || {
        echo "[WARN] Fallo parcial en drivers NVIDIA"
    }

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

# 7. LIBRERÍAS 3D & TABLETAS GRÁFICAS
sudo dnf install -y \
    libwacom xorg-x11-drv-wacom \
    libX11 libXcursor libXi libXrandr mesa-libGLU \
    libxkbcommon libxkbcommon-x11 \
    --setopt=install_weak_deps=False --skip-unavailable || {
    echo "[WARN] Fallo parcial en librerías 3D"
}

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
    com.mattjakeman.ExtensionManager || {
    echo "[WARN] Fallo en instalación de Flatpaks"
}

flatpak update -y

sudo dnf install -y gnome-tweaks --skip-unavailable || {
    echo "[WARN] No se pudo instalar gnome-tweaks"
}

# 9. LIMPIEZA
sudo dnf autoremove -y

echo "========================"
echo "INSTALACIÓN COMPLETADA"
echo "========================"

read -p "¿Reiniciar ahora? (y/n): " choice
[[ "$choice" =~ ^[Yy]$ ]] && reboot