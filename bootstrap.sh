#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

echo "user:$VNCPASS" | sudo chpasswd

# NVIDIA driver version inside the container from Dockerfile must be equal to the host
HEX_ID=$(sudo nvidia-smi --query-gpu=pci.bus_id --id="$(echo "$NVIDIA_VISIBLE_DEVICES" | cut -d ',' -f1)" --format=csv | sed -n 2p)
IFS=":." ARR_ID=("$HEX_ID")
unset IFS
BUS_ID=PCI:$((16#${ARR_ID[1]})):$((16#${ARR_ID[2]})):$((16#${ARR_ID[3]}))
# Leave out --use-display-device=None if GPU is headless such as Tesla, and download links of such GPU drivers in Dockerfile should also be changed
sudo nvidia-xconfig --virtual="${SIZEW}x$SIZEH" --allow-empty-initial-configuration --enable-all-gpus --no-use-edid-dpi --busid="$BUS_ID" --use-display-device=None

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
