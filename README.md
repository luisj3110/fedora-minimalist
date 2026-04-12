**Fedora Minimalist**

A clean, high-performance installer for Fedora Everything

This script is designed for developers and creatives who want a rock-solid, bloat-free environment without the overhead of a standard workstation install. It transforms a minimal Fedora base into a robust professional workstation that’s ready for heavy data pipelines and AAA 3D modeling.

**The Philosophy**
Most "out of the box" distros come with tools you'll never use. This project takes the opposite approach: Start with nothing, add only what matters.

* Stability over Fluff: Uses a "Vanilla Plus" GNOME setup for maximum reliability.
* Performance First: Aggressive DNF optimizations and minimal background services to keep RAM usage low.
* Creative-Ready: Built-in support for Wacom tablets and 3D libraries (OpenGL/Vulkan).
* Dev-Focused: Includes modern terminal tools (`Kitty`, `btop`) and a deterministic Docker-ready environment.

**Key Features**

**System Optimization**
* DNF Speedup: Configures 10 parallel downloads and fastest mirror detection.
* Surgical Base: Installs only the core GNOME components (`mutter`, `gnome-shell`, `nautilus`) avoiding pre-installed games or bloat.
* Modern Audio: Full `PipeWire` stack with ALSA and Bluetooth support out of the box.

**Graphics & Hardware**
* NVIDIA "Pro" Setup: Automates RPM Fusion repos and forces `akmods` compilation during install. This prevents the "black screen" lottery on your first reboot.
* AMD Support: Includes `amd-ucode` for Ryzen stability.
* Creative Suite Prep: Pre-configured with `libwacom` and X11/Wayland 3D libraries for Blender and Substance Painter workflows.

**Application Stack**
A carefully curated list of essential apps via Flatpak for isolation:
* Browser: Brave (Fast & Privacy-focused)
* Utilities: Resources (System Monitor), Extension Manager, and standard GNOME tools (Text Editor, Calculator).
* Terminal: Kitty (GPU-accelerated) and btop (System monitoring).

**How to Use**

1.  **Get the ISO: Download the [Fedora Everything ISO](https://alt.fedoraproject.org/) and perform a "Minimal Install."**
**Pre-installation (Fedora Everything)**
To keep the system as lean as possible, use the **Fedora Everything ISO** and select the following during the Software Selection step:
    * Base Environment: Select `Fedora Custom Operating System`.
    * Add-ons: Check `C Development Tools and Libraries` (This is mandatory for NVIDIA driver compilation).
    * Add-ons: Check `Common NetworkManager Submodules` to ensure stable connectivity for the script.
2.  **Clone & Prep:**
    ```bash
    git clone https://github.com/luisj3110/fedora-minimalist.git
    cd fedora-minimalist
    chmod +x fedora_install.sh
    ```
3.  **Execute:**
    ```bash
    sudo ./fedora_install.sh
    ```

**Safety & Logging**
The script uses `set -euo pipefail` to ensure that if any critical step fails, the installer stops immediately to protect your system. Every action is logged to `install.log` for easy debugging.

**Tech Stack**
* **OS:** Fedora Linux (Everything Edition)
* **DE:** GNOME (Minimalist Configuration)
* **Shell:** Bash / Kitty Terminal
* **Drivers:** Proprietary NVIDIA (via RPM Fusion) + Wacom Support

**License**
MIT. Feel free to fork it, break it, and make it your own.
