#!/bin/bash
set -e

trap "echo TRAPed signal" HUP INT QUIT KILL TERM

# NVIDIA driver inside the container must be same version as host.
HEX_ID=$(sudo nvidia-smi --query-gpu=pci.bus_id --id=${NVIDIA_VISIBLE_DEVICES} --format=csv | tail -n1)
IFS=":." ARR_ID=($HEX_ID); unset IFS
BUS_ID=PCI:$((16#${ARR_ID[1]})):$((16#${ARR_ID[2]})):$((16#${ARR_ID[3]}))
# Leave out --use-display-device=None if GPU is headless such as Tesla and download links of such GPU drivers in Dockerfile should also be different
sudo nvidia-xconfig -a --virtual=${SIZEW}x${SIZEH} --allow-empty-initial-configuration --enable-all-gpus --busid=$BUS_ID --use-display-device=None

shopt -s extglob
for tty in /dev/tty+([0-9])
do
if [ -w ${tty} ] ; then
    /usr/bin/X tty$(echo ${tty} | grep -Eo '[0-9]+$') :0 &
    break
fi
done
sleep 1

x11vnc -display :0 -passwd $VNCPASS -forever -rfbport 5900 &
sleep 2

pulseaudio --start
sleep 2

/opt/noVNC/utils/launch.sh --vnc localhost:5900 --listen 5901 &
sleep 2

export DISPLAY=:0
mate-session &

echo "Session Running. Press [Return] to exit."
read
