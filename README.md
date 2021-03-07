# docker-nvidia-glx-desktop

MATE Desktop container supporting GLX/Vulkan for NVIDIA GPUs by spawning its own
X Server and noVNC WebSocket interface instead of using the host X server. Does
not require `/tmp/.X11-unix` host sockets or host configuration.

Use
[docker-nvidia-egl-desktop](https://github.com/ehfd/docker-nvidia-egl-desktop)
for a MATE Desktop container that directly accesses NVIDIA GPUs without using an
X Server or privileged mode and is compatible with Kubernetes (without Vulkan
support).

Corresponding container toolkit on the host for allocating GPUs should be set
up. Container startup should take some time as it automatically installs NVIDIA
drivers.

Connect to the spawned noVNC WebSocket instance with a browser in port 5901, no
VNC client required (password for the default user is 'vncpasswd').

This configuration allows usage of multiple GPU desktops per node but the
container will use potentially unsafe privileged mode:

```
docker run --gpus 1 --privileged -it -e SIZEW=1920 -e SIZEH=1080 -e SHARED=TRUE -e VNCPASS=vncpasswd -p 5901:5901 ehfd/nvidia-glx-desktop:latest
```

Without privileged mode only one GPU desktop can be used per node because of
Xorg limitations:

Note: Requires **/dev/ttyN** (N >= 8) provision. Check out
[k8s-hostdev-plugin](https://github.com/bluebeach/k8s-hostdev-plugin) for
provisioning this in Kubernetes clusters without privileged access.

```
docker run --gpus 1 --device=/dev/tty63:rw -it -e SIZEW=1920 -e SIZEH=1080 -e SHARED=TRUE -e VNCPASS=vncpasswd -p 5901:5901 ehfd/nvidia-glx-desktop:latest
```
