#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

sudo chown -R user:user /home/user /opt/tomcat
echo "user:$PASSWD" | sudo chpasswd
sudo ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" | sudo tee /etc/timezone > /dev/null
export PATH="${PATH}:/opt/tomcat/bin"

sudo ln -snf /dev/ptmx /dev/tty7
sudo /etc/init.d/ssh start
sudo /etc/init.d/dbus start
pulseaudio --start

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
  cd ~
fi

if grep -Fxq "allowed_users=console" /etc/X11/Xwrapper.config; then
  sudo sed -i "s/allowed_users=console/allowed_users=anybody/;$ a needs_root_rights=yes" /etc/X11/Xwrapper.config
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
sudo sed -i '/Driver\s\+"nvidia"/a\    Option         "ModeValidation" "NoMaxPClkCheck, NoEdidMaxPClkCheck, NoMaxSizeCheck, NoHorizSyncCheck, NoVertRefreshCheck, NoVirtualSizeCheck, NoExtendedGpuCapabilitiesCheck, NoTotalSizeCheck, NoDualLinkDVICheck, NoDisplayPortBandwidthCheck, AllowNon3DVisionModes, AllowNonHDMI3DModes, AllowNonEdidModes, NoEdidHDMI2Check, AllowDpInterlaced"' /etc/X11/xorg.conf
sudo sed -i '/Section\s\+"Monitor"/a\    '"$MODELINE" /etc/X11/xorg.conf

export __GL_SYNC_TO_VBLANK=0
Xorg vt7 -novtswitch -sharevts -dpi 96 +extension "MIT-SHM" :0 &
sleep 1

sudo x11vnc -display ":0" -passwd "$PASSWD" -shared -forever -repeat -xkb -xrandr "resize" -rfbport 5900 &

mkdir -p ~/.guacamole
echo "<user-mapping>
    <authorize username=\"user\" password=\"$PASSWD\">
        <connection name=\"VNC\">
            <protocol>vnc</protocol>
            <param name=\"hostname\">localhost</param>
            <param name=\"port\">5900</param>
            <param name=\"autoretry\">10</param>
            <param name=\"password\">$PASSWD</param>
            <param name=\"enable-sftp\">true</param>
            <param name=\"sftp-hostname\">localhost</param>
            <param name=\"sftp-username\">user</param>
            <param name=\"sftp-password\">$PASSWD</param>
            <param name=\"sftp-directory\">/home/user</param>
            <param name=\"enable-audio\">true</param>
            <param name=\"audio-servername\">localhost</param>
        </connection>
        <connection name=\"SSH\">
            <protocol>ssh</protocol>
            <param name=\"hostname\">localhost</param>
            <param name=\"username\">user</param>
            <param name=\"password\">$PASSWD</param>
            <param name=\"enable-sftp\">true</param>
        </connection>
    </authorize>
</user-mapping>
" > ~/.guacamole/user-mapping.xml
chmod 0600 ~/.guacamole/user-mapping.xml

/opt/tomcat/bin/catalina.sh run &
guacd -b 0.0.0.0 -f &

export DISPLAY=:0
mate-session &

echo "Session Running. Press [Return] to exit."
read
