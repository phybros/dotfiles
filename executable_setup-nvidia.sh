#!/usr/bin/env bash
set -euo pipefail

### ------------------------------------------------------------
### 1. Enable multilib
### ------------------------------------------------------------

PACMAN_CONF="/etc/pacman.conf"
MULTILIB_BLOCK="[multilib]
Include = /etc/pacman.d/mirrorlist"

if ! grep -q "^[[:space:]]*\[multilib\]" "$PACMAN_CONF"; then
  echo "Adding multilib block to pacman.conf..."
  printf "\n%s\n" "$MULTILIB_BLOCK" | sudo tee -a "$PACMAN_CONF" >/dev/null
else
  echo "Multilib already enabled."
fi

### ------------------------------------------------------------
### 2. Update system
### ------------------------------------------------------------

echo "Updating system packages..."
sudo pacman -Syu --noconfirm

### ------------------------------------------------------------
### 3. Install NVIDIA packages
### ------------------------------------------------------------

NVIDIA_DRIVER_PACKAGE="nvidia-open-dkms"
KERNEL_HEADERS="linux-headers"

PACKAGES_TO_INSTALL=(
  "$KERNEL_HEADERS"
  "$NVIDIA_DRIVER_PACKAGE"
  "nvidia-utils"
  "lib32-nvidia-utils"
  "egl-wayland"
  "libva-nvidia-driver"
  "qt5-wayland"
  "qt6-wayland"
)

echo "Installing NVIDIA packages..."
sudo pacman -S --needed --noconfirm "${PACKAGES_TO_INSTALL[@]}"

### ------------------------------------------------------------
### 4. Configure mkinitcpio for early loading
### ------------------------------------------------------------

echo "Configuring mkinitcpio..."
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
NVIDIA_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

# Backup once
if [ ! -f "${MKINITCPIO_CONF}.backup" ]; then
  echo "Creating backup of mkinitcpio.conf..."
  sudo cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.backup"
fi

# Remove existing NVIDIA modules from MODULES=() safely
sudo sed -i -E \
  '/^MODULES=/ s/\<(nvidia|nvidia_drm|nvidia_uvm|nvidia_modeset)\>//g' \
  "$MKINITCPIO_CONF"

# Add modules at start of MODULES=()
sudo sed -i -E \
  "s/^MODULES=\(/MODULES=(${NVIDIA_MODULES} /" \
  "$MKINITCPIO_CONF"

# Normalize spacing
sudo sed -i -E 's/  +/ /g' "$MKINITCPIO_CONF"

### ------------------------------------------------------------
### 5. Enable NVIDIA DRM modeset for Wayland + X11
### ------------------------------------------------------------

MODPROBE_CONF="/etc/modprobe.d/nvidia.conf"
MODPROBE_LINE="options nvidia-drm modeset=1"

if [ -f "$MODPROBE_CONF" ]; then
  if ! grep -q "^$MODPROBE_LINE\$" "$MODPROBE_CONF"; then
    echo "Updating $MODPROBE_CONF to enable modeset..."
    echo "$MODPROBE_LINE" | sudo tee -a "$MODPROBE_CONF" >/dev/null
  else
    echo "NVIDIA DRM modeset already enabled."
  fi
else
  echo "Creating $MODPROBE_CONF to enable NVIDIA DRM modeset..."
  echo "$MODPROBE_LINE" | sudo tee "$MODPROBE_CONF" >/dev/null
fi

### ------------------------------------------------------------
### 6. Regenerate initramfs
### ------------------------------------------------------------

echo "Regenerating initramfs..."
sudo mkinitcpio -P

### ------------------------------------------------------------
### 7. Finish
### ------------------------------------------------------------

echo "Done! NVIDIA drivers, early modules, and DRM modeset are configured."
echo "Reboot to activate everything."
