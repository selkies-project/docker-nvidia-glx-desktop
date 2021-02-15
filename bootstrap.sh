#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

echo "user:$VNCPASS" | sudo chpasswd

# Install NVIDIA drivers, including X graphic drivers by omitting --x-{prefix,module-path,library-path,sysconfig-path}
export DRIVER_VERSION=$(head -n1 </proc/driver/nvidia/version | awk '{ print $8 }')
BASE_URL=https://us.download.nvidia.com/XFree86/Linux-x86_64
cd /tmp
curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run
sudo sh NVIDIA-Linux-x86_64-$DRIVER_VERSION.run -x
cd NVIDIA-Linux-x86_64-$DRIVER_VERSION
sudo ./nvidia-installer --silent \
                   --no-kernel-module \
                   --install-compat32-libs \
                   --no-nouveau-check \
                   --no-nvidia-modprobe \
                   --no-rpms \
                   --no-backup \
                   --no-check-for-alternate-installs \
                   --no-libglx-indirect \
                   --no-install-libglvnd
sudo rm -rf /tmp/NVIDIA*
cd ~

sudo sed -i "s/allowed_users=console/allowed_users=anybody/;$ a needs_root_rights=yes" /etc/X11/Xwrapper.config

if ! sudo nvidia-smi --id="$(echo "$NVIDIA_VISIBLE_DEVICES" | cut -d ',' -f1)" -q | grep -q "Tesla"; then
  DISPLAYSTRING="--use-display-device=None"
fi

HEX_ID=$(sudo nvidia-smi --query-gpu=pci.bus_id --id="$(echo "$NVIDIA_VISIBLE_DEVICES" | cut -d ',' -f1)" --format=csv | sed -n 2p)
IFS=":." ARR_ID=($HEX_ID)
unset IFS
BUS_ID=PCI:$((16#${ARR_ID[1]})):$((16#${ARR_ID[2]})):$((16#${ARR_ID[3]}))
sudo nvidia-xconfig --virtual="${SIZEW}x${SIZEH}" --depth="$CDEPTH" --allow-empty-initial-configuration --enable-all-gpus --no-use-edid-dpi --busid="$BUS_ID" --only-one-x-screen "$DISPLAYSTRING"

if [ "x$SHARED" == "xTRUE" ]; then
  export SHARESTRING="-shared"
fi

shopt -s extglob
for TTY in /dev/tty+([0-9]); do
  if [ -w "$TTY" ]; then
    Xorg tty"$(echo "$TTY" | grep -Eo '[0-9]+$')" :0 &
    break
  fi
done
sleep 1

x11vnc -display :0 -passwd "$VNCPASS" -forever -xkb -rfbport 5900 "$SHARESTRING" &
sleep 1

/opt/noVNC/utils/launch.sh --vnc localhost:5900 --listen 5901 &
sleep 1

export DISPLAY=:0
UUID_CUT=$(sudo nvidia-smi --query-gpu=uuid --id="$(echo "$NVIDIA_VISIBLE_DEVICES" | cut -d ',' -f1)" --format=csv | sed -n 2p | cut -c 5-)
if vulkaninfo | grep "$UUID_CUT" | grep -q ^; then
  VK=0
  while true; do
    if ENABLE_DEVICE_CHOOSER_LAYER=1 VULKAN_DEVICE_INDEX=$VK vulkaninfo | grep "$UUID_CUT" | grep -q ^; then
      export ENABLE_DEVICE_CHOOSER_LAYER=1
      export VULKAN_DEVICE_INDEX="$VK"
      break
    fi
    VK=$((VK + 1))
  done
else
  echo "Vulkan not available for the current GPU."
fi

mate-session &
sleep 1

pulseaudio --start

echo "Session Running. Press [Return] to exit."
read
