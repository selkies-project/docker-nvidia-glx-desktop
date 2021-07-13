#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

echo "user:$VNCPASS" | sudo chpasswd

sudo /etc/init.d/dbus start

# Install NVIDIA drivers, including X graphic drivers by omitting --x-{prefix,module-path,library-path,sysconfig-path}
if ! command -v nvidia-xconfig &> /dev/null; then
  export DRIVER_VERSION=$(head -n1 </proc/driver/nvidia/version | awk '{print $8}')
  BASE_URL=https://download.nvidia.com/XFree86/Linux-x86_64
  cd /tmp
  curl -fsSL -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run
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
  sudo sed -i "s/allowed_users=console/allowed_users=anybody/;$ a needs_root_rights=yes" /etc/X11/Xwrapper.config
  cd ~
fi

if [ -f "/etc/X11/xorg.conf" ]; then
  sudo rm /etc/X11/xorg.conf
fi

if [ "$NVIDIA_VISIBLE_DEVICES" == "all" ]; then
  export GPU_SELECT=$(sudo nvidia-smi --query-gpu=uuid --format=csv | sed -n 2p)
elif [ -z "$NVIDIA_VISIBLE_DEVICES" ]; then
  export GPU_SELECT=$(sudo nvidia-smi --query-gpu=uuid --format=csv | sed -n 2p)
else
  export GPU_SELECT=$(sudo nvidia-smi --id=$(echo "$NVIDIA_VISIBLE_DEVICES" | cut -d ',' -f1) --query-gpu=uuid --format=csv | sed -n 2p)
  if [ -z "$GPU_SELECT" ]; then
    export GPU_SELECT=$(sudo nvidia-smi --query-gpu=uuid --format=csv | sed -n 2p)
  fi
fi

if [ -z "$GPU_SELECT" ]; then
  echo "No NVIDIA GPUs detected. Exiting."
  exit 1
fi

HEX_ID=$(sudo nvidia-smi --query-gpu=pci.bus_id --id="$GPU_SELECT" --format=csv | sed -n 2p)
IFS=":." ARR_ID=($HEX_ID)
unset IFS
BUS_ID=PCI:$((16#${ARR_ID[1]})):$((16#${ARR_ID[2]})):$((16#${ARR_ID[3]}))
export MODELINE=$(cvt -r ${SIZEW} ${SIZEH} | sed -n 2p)
sudo nvidia-xconfig --virtual="${SIZEW}x${SIZEH}" --depth="$CDEPTH" --mode=$(echo $MODELINE | awk '{print $2}' | tr -d '"') --allow-empty-initial-configuration --no-probe-all-gpus --busid="$BUS_ID" --only-one-x-screen --connected-monitor="$VIDEO_PORT"
sudo sed -i '/Driver\s\+"nvidia"/a\    Option         "ModeValidation" "NoMaxPClkCheck, NoEdidMaxPClkCheck, NoMaxSizeCheck, NoHorizSyncCheck, NoVertRefreshCheck, NoVirtualSizeCheck, NoExtendedGpuCapabilitiesCheck, NoTotalSizeCheck, NoDualLinkDVICheck, NoDisplayPortBandwidthCheck, AllowNon3DVisionModes, AllowNonHDMI3DModes, AllowNonEdidModes, NoEdidHDMI2Check, AllowDpInterlaced"\n    Option         "DPI" "96 x 96"' /etc/X11/xorg.conf
sudo sed -i '/Section\s\+"Monitor"/a\    '"$MODELINE" /etc/X11/xorg.conf

shopt -s extglob
for TTY in $(ls -1 /dev/tty+([0-9]) | sort -rV); do
  if [ -w "$TTY" ]; then
    Xorg vt"$(echo "$TTY" | grep -Eo '[0-9]+$')" -sharevts :0 &
    break
  fi
done
sleep 1

if [ "x$SHARED" == "xTRUE" ]; then
  export SHARESTRING="-shared"
fi

x11vnc -display ":0" -passwd "$VNCPASS" -forever -repeat -xkb -xrandr "resize" -rfbport 5900 "$SHARESTRING" &
sleep 1

/opt/noVNC/utils/launch.sh --vnc localhost:5900 --listen 5901 &
sleep 1

export DISPLAY=:0
UUID_CUT=$(sudo nvidia-smi --query-gpu=uuid --id="$GPU_SELECT" --format=csv | sed -n 2p | cut -c 5-)
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
  echo "Vulkan is not available for the current GPU."
fi

mate-session &
pulseaudio --start

echo "Session Running. Press [Return] to exit."
read
