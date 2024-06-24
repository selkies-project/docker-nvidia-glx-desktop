#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

trap "echo TRAPed signal" HUP INT QUIT TERM

# Create and modify permissions of XDG_RUNTIME_DIR
mkdir -pm700 /tmp/runtime-ubuntu
chown ubuntu:ubuntu /tmp/runtime-ubuntu
chmod 700 /tmp/runtime-ubuntu
# Make user directory owned by the default ubuntu user
chown ubuntu:ubuntu /home/ubuntu || sudo-root chown ubuntu:ubuntu /home/ubuntu || chown ubuntu:ubuntu /home/ubuntu/* || sudo-root chown ubuntu:ubuntu /home/ubuntu/* || echo 'Failed to change user directory permissions, there may be permission issues'
# Change operating system password to environment variable
(echo "$PASSWD"; echo "$PASSWD";) | sudo passwd ubuntu
# Remove directories to make sure the desktop environment starts
rm -rf /tmp/.X* ~/.cache
# Change time zone from environment variable
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | tee /etc/timezone > /dev/null
# Add Lutris directories to path
export PATH="${PATH:+${PATH}:}/usr/local/games:/usr/games"
# Add LibreOffice to library path
export LD_LIBRARY_PATH="/usr/lib/libreoffice/program${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Configure joystick interposer
export SDL_JOYSTICK_DEVICE=/dev/input/js0
mkdir -pm777 /dev/input || sudo-root mkdir -pm777 /dev/input || echo 'Failed to create joystick interposer directory'
touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || sudo-root touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || echo 'Failed to create joystick interposer devices'

# Set default display
export DISPLAY="${DISPLAY:-:0}"
# PipeWire-Pulse server socket location
export PIPEWIRE_LATENCY="32/48000"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

if ! command -v nvidia-xconfig >/dev/null 2>&1; then
  # Install NVIDIA userspace driver components including X graphic libraries, keep contents same as docker-nvidia-egl-desktop
  export NVIDIA_DRIVER_ARCH="$(dpkg --print-architecture | sed -e 's/arm64/aarch64/' -e 's/armhf/32bit-ARM/' -e 's/i.*86/x86/' -e 's/amd64/x86_64/' -e 's/unknown/x86_64/')"
  if [ -z "${NVIDIA_DRIVER_VERSION}" ]; then
    # Driver version is provided by the kernel through the container toolkit, prioritize kernel driver version if available
    if [ -f "/proc/driver/nvidia/version" ]; then
      export NVIDIA_DRIVER_VERSION="$(head -n1 </proc/driver/nvidia/version | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9\.]+/) {print $i; exit}}')"
    elif command -v nvidia-smi >/dev/null 2>&1; then
      # Use NVIDIA-SMI when not available
      export NVIDIA_DRIVER_VERSION="$(nvidia-smi --version | grep 'DRIVER version' | cut -d: -f2 | tr -d ' ')"
    else
      echo "Failed to find NVIDIA GPU driver version. You might not be using the NVIDIA container toolkit. Exiting."
      exit 1
    fi
  fi
  cd /tmp
  # If version is different, new installer will overwrite the existing components
  if [ ! -f "/tmp/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" ]; then
    # Check multiple sources in order to probe both consumer and datacenter driver versions
    curl -fsSL -O "https://international.download.nvidia.com/XFree86/Linux-${NVIDIA_DRIVER_ARCH}/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || curl -fsSL -O "https://international.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" || { echo "Failed NVIDIA GPU driver download. Exiting."; exit 1; }
  fi
  # Extract installer before installing
  sh "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}.run" -x
  cd "NVIDIA-Linux-${NVIDIA_DRIVER_ARCH}-${NVIDIA_DRIVER_VERSION}"
  # Run NVIDIA driver installation without the kernel modules and host components
  sudo ./nvidia-installer --silent \
                    --accept-license \
                    --no-kernel-module \
                    --install-compat32-libs \
                    --no-nouveau-check \
                    --no-nvidia-modprobe \
                    --no-systemd \
                    --no-rpms \
                    --no-backup \
                    --no-check-for-alternate-installs
  rm -rf /tmp/NVIDIA* && cd ~
fi

# Allow starting Xorg from a pseudoterminal instead of strictly on a tty console
if [ ! -f /etc/X11/Xwrapper.config ]; then
    echo -e "allowed_users=anybody\nneeds_root_rights=yes" | tee /etc/X11/Xwrapper.config > /dev/null
fi
if grep -Fxq "allowed_users=console" /etc/X11/Xwrapper.config; then
  sed -i "s/allowed_users=console/allowed_users=anybody/;$ a needs_root_rights=yes" /etc/X11/Xwrapper.config
fi

# Remove existing Xorg configuration
if [ -f "/etc/X11/xorg.conf" ]; then
  rm -f "/etc/X11/xorg.conf"
fi

# Get first GPU device if all devices are available or `NVIDIA_VISIBLE_DEVICES` is not set
if [ "$NVIDIA_VISIBLE_DEVICES" == "all" ] || [ -z "$NVIDIA_VISIBLE_DEVICES" ]; then
  export GPU_SELECT="$(nvidia-smi --query-gpu=uuid --format=csv,noheader | head -n1)"
# Get first GPU device out of the visible devices in other situations
else
  export GPU_SELECT="$(nvidia-smi --id=$(echo "$NVIDIA_VISIBLE_DEVICES" | cut -d ',' -f1) --query-gpu=uuid --format=csv,noheader | head -n1)"
  if [ -z "$GPU_SELECT" ]; then
    export GPU_SELECT="$(nvidia-smi --query-gpu=uuid --format=csv,noheader | head -n1)"
  fi
fi

if [ -z "$GPU_SELECT" ]; then
  echo "No NVIDIA GPUs detected or nvidia-container-toolkit not configured. Exiting."
  exit 1
fi

# Setting `VIDEO_PORT` to none disables RANDR/XRANDR, do not set this if using datacenter GPUs
if [ "$(echo ${VIDEO_PORT} | tr '[:upper:]' '[:lower:]')" = "none" ]; then
  export CONNECTED_MONITOR="--use-display-device=None"
# The X server is otherwise deliberately set to a specific video port despite not being plugged to enable RANDR/XRANDR, monitor will display the screen if plugged to the specific port
else
  export CONNECTED_MONITOR="--connected-monitor=${VIDEO_PORT}"
fi

# Bus ID from nvidia-smi is in hexadecimal format and should be converted to decimal format (including the domain) which Xorg understands, required because nvidia-xconfig doesn't work as intended in a container
HEX_ID="$(nvidia-smi --query-gpu=pci.bus_id --id="$GPU_SELECT" --format=csv,noheader | head -n1)"
IFS=":." ARR_ID=($HEX_ID)
unset IFS
BUS_ID="PCI:$((16#${ARR_ID[1]}))@$((16#${ARR_ID[0]})):$((16#${ARR_ID[2]})):$((16#${ARR_ID[3]}))"
# A custom modeline should be generated because there is no monitor to fetch this information normally
export MODELINE="$(cvt -r "${DISPLAY_SIZEW}" "${DISPLAY_SIZEH}" "${DISPLAY_REFRESH}" | sed -n 2p)"
# Generate /etc/X11/xorg.conf with nvidia-xconfig
nvidia-xconfig --virtual="${DISPLAY_SIZEW}x${DISPLAY_SIZEH}" --depth="$DISPLAY_CDEPTH" --mode="$(echo "$MODELINE" | awk '{print $2}' | tr -d '\"')" --allow-empty-initial-configuration --no-probe-all-gpus --busid="$BUS_ID" --include-implicit-metamodes --mode-debug --no-sli --no-base-mosaic --only-one-x-screen ${CONNECTED_MONITOR}
# Guarantee that the X server starts without a monitor by adding more options to the configuration
sed -i '/Driver\s\+"nvidia"/a\    Option         "ModeValidation" "NoMaxPClkCheck,NoEdidMaxPClkCheck,NoMaxSizeCheck,NoHorizSyncCheck,NoVertRefreshCheck,NoVirtualSizeCheck,NoExtendedGpuCapabilitiesCheck,NoTotalSizeCheck,NoDualLinkDVICheck,NoDisplayPortBandwidthCheck,AllowNon3DVisionModes,AllowNonHDMI3DModes,AllowNonEdidModes,NoEdidHDMI2Check,AllowDpInterlaced"' /etc/X11/xorg.conf
sed -i '/Driver\s\+"nvidia"/a\    Option         "PrimaryGPU" "True"' /etc/X11/xorg.conf
# Support external GPUs
sed -i '/Driver\s\+"nvidia"/a\    Option         "AllowExternalGpus" "True"' /etc/X11/xorg.conf
# Add custom generated modeline to the configuration
sed -i '/Section\s\+"Monitor"/a\    '"$MODELINE" /etc/X11/xorg.conf
# Prevent interference between GPUs, add this to the host or other containers running Xorg as well
echo -e "Section \"ServerFlags\"\n    Option         \"DontVTSwitch\" \"true\"\n    Option         \"AllowMouseOpenFail\" \"true\"\n    Option         \"AutoAddGPU\" \"false\"\nEndSection" | tee -a /etc/X11/xorg.conf > /dev/null

# Run Xorg server with required extensions
/usr/bin/Xorg "${DISPLAY}" vt7 -noreset -novtswitch -sharevts -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" &

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Run the KasmVNC fallback web interface if enabled
if [ "$(echo ${KASMVNC_ENABLE} | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  export KASM_DISPLAY=":50"
  yq -i "
  .command_line.prompt = false |
  .desktop.allow_resize = $(echo ${SELKIES_ENABLE_RESIZE-false} | tr '[:upper:]' '[:lower:]') |
  .network.interface = \"0.0.0.0\" |
  .network.websocket_port = 8080 |
  .network.ssl.require_ssl = $(echo ${SELKIES_ENABLE_HTTPS-false} | tr '[:upper:]' '[:lower:]') |
  .encoding.max_frame_rate = ${DISPLAY_REFRESH}
  " /etc/kasmvnc/kasmvnc.yaml
  if [ -n "${SELKIES_HTTPS_CERT}" ]; then yq -i ".network.ssl.pem_certificate = \"${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem}\"" /etc/kasmvnc/kasmvnc.yaml; fi
  if [ -n "${SELKIES_HTTPS_KEY}" ]; then yq -i ".network.ssl.pem_key = \"${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key}\"" /etc/kasmvnc/kasmvnc.yaml; fi
  if [ "$(echo ${SELKIES_ENABLE_RESIZE} | tr '[:upper:]' '[:lower:]')" = "true" ]; then export KASM_RESIZE_FLAG="-r"; fi
  (echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}"; echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}";) | kasmvncpasswd -u "${SELKIES_BASIC_AUTH_USER:-${USER}}" -o
  if [ "$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')" = "false" ]; then export NO_KASM_AUTH_FLAG="-disableBasicAuth"; fi
  if [ -n "${KASMVNC_VIEWPASS}" ]; then (echo "${KASMVNC_VIEWPASS}"; echo "${KASMVNC_VIEWPASS}";) | kasmvncpasswd -u "view"; fi
  kasmvncserver "${KASM_DISPLAY}" -geometry "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}" -depth "${DISPLAY_CDEPTH}" -noxstartup -FrameRate "${DISPLAY_REFRESH}" -websocketPort 8080 -AlwaysShared -BlacklistTimeout 0 ${NO_KASM_AUTH_FLAG}
  until [ -S "/tmp/.X11-unix/X${KASM_DISPLAY#*:}" ]; do sleep 0.5; done;
  kasmxproxy -a "${DISPLAY}" -v "${KASM_DISPLAY}" -f "${DISPLAY_REFRESH}" ${KASM_RESIZE_FLAG} &
fi

# Start KDE desktop environment
export XDG_SESSION_ID="${DISPLAY#*:}"
export QT_LOGGING_RULES='*.debug=false;qt.qpa.*=false'
/usr/bin/startplasma-x11 &

# Start Fcitx input method framework
/usr/bin/fcitx &

# Add custom processes right below this line, or within `supervisord.conf` to perform service management similar to systemd

echo "Session Running. Press [Return] to exit."
read
