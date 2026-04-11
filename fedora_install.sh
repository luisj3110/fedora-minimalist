#!/bin/bash
set -euo pipefail

# LOGGING
exec > >(tee -i install.log)
exec 2>&1

echo "=================================================="
echo "FEDORA EVERYTHING MINIMALIST INSTALLER (By KKMOLE69)"
echo "=================================================="

# 1. DNF OPTIMIZATION
echo "[INFO] -> Optimizando DNF..."
sudo bash -c 'echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf'
sudo bash -c 'echo "fastestmirror=True" >> /etc/dnf/dnf.conf'

# 2. GNOME SURGICAL CORE
echo "[INFO] -> Instalando cimientos de GNOME..."
sudo dnf install -y \
    gnome-shell \
    gdm \
    nautilus \
    gnome-control-center \
    gnome-settings-daemon \
    gvfs-mtp \
    xdg-user-dirs-gtk \
    desktop-backgrounds-gnome \
    network-manager-applet \
    --setopt=install_weak_deps=False

# 3. COMPONENTES DEL SISTEMA
echo "[INFO] -> Instalando herramientas de usuario..."
sudo dnf install -y \
    gnome-terminal \
    kitty \
    gnome-disk-utility \
    pipewire pipewire-pulseaudio wireplumber \
    xdg-desktop-portal-gnome \
    gnome-keyring \
    seahorse \
    flatpak \
    --setopt=install_weak_deps=False

# 4. ACTIVAR INTERFAZ GRÁFICA
echo "[INFO] -> Activando gestor de arranque gráfico..."
sudo systemctl enable gdm
sudo systemctl set-default graphical.target

# 5. GRAPHICS STACK (NVIDIA + VULKAN)
install_nvidia() {
    echo "[INFO] -> Instalando drivers NVIDIA y RPM Fusion..."
    sudo dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-server-Xwayland mesa-dri-drivers vulkan-loader
    echo "[INFO] -> Compilando módulos (puede tardar)..."
    sudo akmods --force && sudo dracut --force
}

if lspci | grep -qi nvidia; then
    echo "[INFO] -> Hardware NVIDIA detectado."
    install_nvidia
else
    echo "[WARNING] -> No se detectó hardware NVIDIA. Es posible que los drivers no sean necesarios o compatibles."
    read -p "¿Deseas instalar los drivers de todos modos? (y/n): " force_nv
    if [[ "$force_nv" == "y" || "$force_nv" == "Y" ]]; then
        install_nvidia
    else
        echo "[INFO] -> Saltando instalación de NVIDIA."
    fi
fi

# 6. TABLET + LIBS 3D
echo "[INFO] -> Soporte 3D y Tabletas graficas..."
sudo dnf install -y \
    libwacom xorg-x11-drv-wacom \
    libX11 libXcursor libXi libXrandr mesa-libGLU \
    --setopt=install_weak_deps=False --skip-unavailable

# 7. FLATPAK APPS
echo "[INFO] -> Configurando aplicaciones..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub -y \
    com.brave.Browser \
    org.gnome.Showtime \
    org.gnome.Calculator \
    org.gnome.TextEditor \
    org.gnome.Decibels

# 8. TWEAKS (Nombre de paquete corregido)
echo "[INFO] -> Herramientas de personalización..."
sudo dnf install -y gnome-tweaks extension-manager btop --skip-unavailable

# 9. LIMPIEZA FINAL
echo "[INFO] -> Limpiando dependencias..."
sudo dnf autoremove -y

echo "=================================================="
echo "INSTALACIÓN COMPLETADA"
echo "=================================================="

read -p "¿Reiniciar ahora? (y/n): " choice
[[ "$choice" == "y" ]] && reboot