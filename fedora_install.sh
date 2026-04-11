#!/bin/bash
set -e

echo "=================================================="
echo "Fedora Everything Minimalist"
echo "=================================================="

# 1. OPTIMIZACIÓN DE DNF (Velocidad)
echo "Optimizando DNF para descargas paralelas..."
sudo bash -c 'echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf'
sudo bash -c 'echo "fastestmirror=True" >> /etc/dnf/dnf.conf'

# 2. NÚCLEO GNOME & GESTIÓN DE DISCOS
echo "Instalando entorno GNOME filtrado..."
sudo dnf groupinstall "GNOME" --setopt=install_weak_deps=False -y

# Añadimos la Utilidad de Discos y componentes de sistema
sudo dnf install -y \
gnome-terminal nautilus gnome-disk-utility \
pipewire pipewire-pulseaudio wireplumber \
xdg-desktop-portal-gnome xdg-user-dirs-gtk \
gnome-keyring kitty \
--setopt=install_weak_deps=False

# 3. GRÁFICOS NVIDIA (GTX 1650)
echo "Configurando drivers NVIDIA y XWayland..."
sudo dnf install -y \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo dnf install -y \
akmod-nvidia xorg-x11-drv-nvidia-cuda \
xorg-x11-server-Xwayland mesa-dri-drivers \
vulkan-loader

echo "Compilando módulos del kernel NVIDIA (No canceles)..."
sudo akmods --force && sudo dracut --force


# 4. LIBRERÍAS DE PRODUCCIÓN 3D (Blender/Substance)
echo "Instalando librerías de soporte 3D y Tablet..."
sudo dnf install -y \
libwacom xorg-x11-drv-wacom \
libX11 libXcursor libXi libXrandr \
mesa-libGLU mesa-libGL-devel \
google-ubuntu-font-family \
--setopt=install_weak_deps=False


# 5. CAPA FLATPAK (Aplicaciones de Usuario)
echo "Instalando aplicaciones Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install flathub -y \
com.brave.Browser \
org.gnome.Showtime \
org.gnome.Calculator \
org.gnome.TextEditor \
org.gnome.Decibels


# 6. DATA ENGINEERING TOOLS
echo "Configurando Docker y herramientas de monitoreo..."
sudo dnf install -y \
gnome-tweaks gnome-extension-manager btop \
docker docker-compose-plugin

sudo usermod -aG docker $USER
sudo systemctl disable docker


# 7. LIMPIEZA Y CIERRE
echo "Limpiando dependencias huérfanas..."
sudo dnf autoremove -y

echo "=================================================="
echo "INSTALACIÓN COMPLETADA CON ÉXITO"
echo "⚠️  REINICIA AHORA."
echo "=================================================="