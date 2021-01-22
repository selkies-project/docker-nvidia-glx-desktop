# docker-nvidia-glx-desktop

MATE Desktop container supporting GLX/Vulkan for NVIDIA GPUs by spawning its own
X Server and noVNC WebSocket interface instead of using the host X server. Does
not require `/tmp/.X11-unix` host sockets or any non-conventional/dangerous host
setup.

Use
[docker-nvidia-egl-desktop](https://github.com/ehfd/docker-nvidia-egl-desktop)
for a MATE Desktop container that directly accesses NVIDIA GPUs without using an
X Server (without Vulkan support).

**Change the NVIDIA GPU driver version inside the container to be equal to the
host and build your own Dockerfile.** Change **bootstrap.sh** also if you are
using a headless GPU like Tesla. Corresponding container toolkit on the host for
allocating GPUs should also be set up.

Connect to the spawned noVNC WebSocket instance with a browser in port 5901, no
VNC client required (password for the default user is 'vncpasswd').

Note: Requires access to at least one **/dev/ttyX** device. Check out
[k8s-hostdev-plugin](https://github.com/bluebeach/k8s-hostdev-plugin) for
provisioning this in Kubernetes clusters without privileged access.

For Docker this configuration is tested to work but the container will have
potentially unsafe privileged access:

```
docker run --gpus 1 --privileged -it -e SIZEW=1920 -e SIZEH=1080 -e SHARED=TRUE -e VNCPASS=vncpasswd -p 5901:5901 ehfd/nvidia-glx-desktop:latest
```

The below may also work without privileged access but is untested:

```
docker run --gpus 1 --device=/dev/tty0:rw -it -e SIZEW=1920 -e SIZEH=1080 -e SHARED=TRUE -e VNCPASS=vncpasswd -p 5901:5901 ehfd/nvidia-glx-desktop:latest
```
