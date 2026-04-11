#!/bin/bash
set -euo pipefail

echo "=================================================="
echo "[INFO] -> Fedora Everything Minimalist"
echo "=================================================="


# LOGGING
exec > >(tee -i install.log)
exec 2>&1

# 1. DNF OPTIMIZATION
echo "[INFO] -> Optimizando DNF..."

grep -q "max_parallel_downloads" /etc/dnf/dnf.conf || echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
grep -q "fastestmirror" /etc/dnf/dnf.conf || echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf


# 2. SYSTEM UPDATE
echo "[INFO] -> Actualizando sistema..."
sudo dnf update -y


# 3. GNOME DESKTOP
echo "[INFO] -> Instalando GNOME Desktop..."
sudo dnf install @gnome-desktop --setopt=install_weak_deps=False -y


# 4. CORE SYSTEM (SIN BLOAT)
echo "[INFO] -> Instalando componentes esenciales..."
sudo dnf install -y \
gnome-terminal \
nautilus \
gnome-disk-utility \
pipewire \
pipewire-pulseaudio \
wireplumber \
xdg-desktop-portal-gnome \
xdg-user-dirs-gtk \
gnome-keyring \
seahorse \
kitty \
flatpak \
--setopt=install_weak_deps=False


# 5. ACTIVAR INTERFAZ GRÁFICA
echo "[INFO] -> Activando entorno gráfico..."
sudo systemctl enable gdm
sudo systemctl set-default graphical.target


# 6. GRAPHICS STACK (WAYLAND + VULKAN)
echo "[INFO] -> Instalando stack gráfico..."
sudo dnf install -y \
xorg-x11-server-Xwayland \
egl-wayland \
mesa-dri-drivers \
vulkan \
vulkan-tools


# 7. DETECCIÓN NVIDIA (VM SAFE)
if lspci | grep -qi nvidia; then
    echo "[INFO] -> NVIDIA detectada - instalando drivers..."

    sudo dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    echo "[INFO] -> Instalando dependencias del kernel..."
    sudo dnf install -y kernel-devel kernel-headers

    echo "-> Instalando drivers NVIDIA..."
    sudo dnf install -y \
    akmod-nvidia \
    xorg-x11-drv-nvidia-cuda

    echo "[INFO] -> Compilando módulos (esto puede tardar)..."
    sudo akmods --force && sudo dracut --force

else
    echo "[INFO] -> No se detectó NVIDIA (VM o GPU distinta) → se omite"
fi


# 8. MULTIMEDIA (CRÍTICO)
echo "[INFO] -> Instalando códecs multimedia..."
sudo dnf install -y \
ffmpeg ffmpeg-libs \
gstreamer1-plugins-bad-* \
gstreamer1-plugins-good \
gstreamer1-plugins-base \
gstreamer1-libav \
--setopt=install_weak_deps=False


# 9. TABLET + LIBS 3D
echo "[INFO] -> Instalando soporte tablet y libs 3D..."
sudo dnf install -y \
libwacom \
xorg-x11-drv-wacom \
libX11 libXcursor libXi libXrandr \
mesa-libGLU \
libxkbcommon libxkbcommon-x11 \
--setopt=install_weak_deps=False --skip-unavailable


# 10. FONTS 
echo "[INFO] -> Instalando fuentes..."
sudo dnf install -y \
ubuntu-family-fonts \
google-noto-fonts \
google-noto-sans-fonts \
google-noto-mono-fonts \
--skip-unavailable


# 11. FLATPAK + APPS
echo "[INFO] -> Configurando Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "[INFO] -> Instalando apps Flatpak..."
flatpak install flathub -y \
com.brave.Browser \
org.gnome.Showtime \
org.gnome.Loupe \
org.gnome.Music \
org.gnome.Calculator \
org.gnome.TextEditor \
org.gnome.Decibels


# 12. TOOLS
echo "[INFO] -> Instalando herramientas..."
sudo dnf install -y \
gnome-tweaks \
gnome-extension-manager \
btop \
--skip-unavailable


# 13. CLEANUP (SAFE)
echo "[INFO] -> Eliminando bloat innecesario..."
sudo dnf remove -y \
gnome-tour \
cheese \
simple-scan || true

echo "[INFO] -> Limpiando dependencias..."
sudo dnf autoremove -y


# 14. FINAL
echo "=================================================="
echo "[INFO] -> INSTALACIÓN COMPLETADA"
echo "[INFO] -> Sistema listo para 3D + Desarrollo"
echo "[INFO] -> Log disponible en: install.log"
echo "=================================================="


# 15. REBOOT OPCIONAL
read -p "[INFO] -> ¿Reiniciar ahora? (y/n): " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    reboot
fi