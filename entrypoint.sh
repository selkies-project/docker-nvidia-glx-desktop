#!/bin/bash -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

sudo chown -R user:user /home/user
echo "user:$PASSWD" | sudo chpasswd
sudo rm -rf /tmp/.X*
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone > /dev/null

sudo ln -snf /dev/ptmx /dev/tty7
sudo /etc/init.d/dbus start

# Install NVIDIA drivers, including X graphic drivers by omitting --x-{prefix,module-path,library-path,sysconfig-path}
if ! command -v nvidia-xconfig &> /dev/null; then
  export DRIVER_VERSION=$(head -n1 </proc/driver/nvidia/version | awk '{print $8}')
  cd /tmp
  if [ ! -f "/tmp/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run" ]; then
    curl -fsL -O "https://us.download.nvidia.com/XFree86/Linux-x86_64/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run" || curl -fsL -O "https://us.download.nvidia.com/tesla/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run" || { echo "Failed NVIDIA GPU driver download. Exiting."; exit 1; }
  fi
  sudo sh "NVIDIA-Linux-x86_64-$DRIVER_VERSION.run" -x
  cd "NVIDIA-Linux-x86_64-$DRIVER_VERSION"
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
  sudo rm -rf /tmp/NVIDIA* && cd ~
fi

if grep -Fxq "allowed_users=console" /etc/X11/Xwrapper.config; then
  sudo sed -i "s/allowed_users=console/allowed_users=anybody/;$ a needs_root_rights=yes" /etc/X11/Xwrapper.config
fi

if [ -f "/etc/X11/xorg.conf" ]; then
  sudo rm "/etc/X11/xorg.conf"
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
export MODELINE=$(cvt -r "${SIZEW}" "${SIZEH}" "${REFRESH}" | sed -n 2p)
sudo nvidia-xconfig --virtual="${SIZEW}x${SIZEH}" --depth="$CDEPTH" --mode=$(echo "$MODELINE" | awk '{print $2}' | tr -d '"') --allow-empty-initial-configuration --no-probe-all-gpus --busid="$BUS_ID" --only-one-x-screen --connected-monitor="$VIDEO_PORT"
sudo sed -i '/Driver\s\+"nvidia"/a\    Option         "ModeValidation" "NoMaxPClkCheck, NoEdidMaxPClkCheck, NoMaxSizeCheck, NoHorizSyncCheck, NoVertRefreshCheck, NoVirtualSizeCheck, NoExtendedGpuCapabilitiesCheck, NoTotalSizeCheck, NoDualLinkDVICheck, NoDisplayPortBandwidthCheck, AllowNon3DVisionModes, AllowNonHDMI3DModes, AllowNonEdidModes, NoEdidHDMI2Check, AllowDpInterlaced"' /etc/X11/xorg.conf
sudo sed -i '/Section\s\+"Monitor"/a\    '"$MODELINE" /etc/X11/xorg.conf

export DISPLAY=":0"
export __GL_SYNC_TO_VBLANK="0"
Xorg vt7 -novtswitch -sharevts -dpi "${DPI}" +extension "MIT-SHM" "${DISPLAY}" &

# Wait for X11 to start
echo "Waiting for X socket"
until [ -S "/tmp/.X11-unix/X${DISPLAY/:/}" ]; do sleep 1; done
echo "X socket is ready"

if [ "$NOVNC_ENABLE" = "true" ]; then
  sudo x11vnc -display "${DISPLAY}" -passwd "${BASIC_AUTH_PASSWORD:-$PASSWD}" -shared -forever -repeat -xkb -xrandr "resize" -rfbport 5900 &
  /opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 8080 --heartbeat 10 &
fi

# Add custom processes below this section or within `supervisord.conf`
mate-session &

echo "Session Running. Press [Return] to exit."
read
