# docker-nvidia-glx-desktop

MATE Desktop container supporting GLX/Vulkan for NVIDIA GPUs by spawning its own
X Server and noVNC WebSocket interface instead of using the host X server. Does
not require `/tmp/.X11-unix` sockets set up.

Note: Requires **privileged** mode because of how Xorg works.

Use
[docker-nvidia-egl-desktop](https://github.com/ehfd/docker-nvidia-egl-desktop)
for a MATE Desktop container that directly accesses NVIDIA GPUs without using an
X Server nor privileged mode (without Vulkan support).

Corresponding container toolkit on the host for allocating GPUs should be set
up. Container startup should take some time as it automatically installs NVIDIA
drivers.

Connect to the spawned noVNC WebSocket instance with a browser in port 5901, no
VNC client required (password for the default user is 'vncpasswd').

For Docker use this configuration:

```
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=0 --privileged -it -e SIZEW=1920 -e SIZEH=1080 -e SHARED=TRUE -e VNCPASS=vncpasswd -p 5901:5901 ehfd/nvidia-glx-desktop:latest
```
