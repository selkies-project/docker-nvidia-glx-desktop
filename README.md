# docker-nvidia-glx-desktop

MATE Desktop container supporting GLX/Vulkan for NVIDIA GPUs by spawning its own X Server and noVNC WebSocket interface instead of using the host X server. Does not require `/tmp/.X11-unix` host sockets or host configuration. Designed for Kubernetes.

Use [docker-nvidia-egl-desktop](https://github.com/ehfd/docker-nvidia-egl-desktop) for a MATE Desktop container that directly accesses NVIDIA GPUs without using an X11 Server, and is also compatible with Kubernetes (but without Vulkan support unlike this container).

Requires reasonably recent NVIDIA GPU drivers and corresponding container toolkits to be set up on the host for allocating GPUs. GPUs should have one or more DVI/HDMI/DisplayPort digital video ports instead of having only analog video ports (very ancient GPUs), although the ports to be used are recommended NOT to be connected with an actual monitor. Since this container fakes the driver to simulate being plugged in to a monitor while it actually does not, make sure the resolutions specified with the environment variables **SIZEW** and **SIZEH** are within the maximum supported by the GPU (1920 x 1200 at 60 hz is the maximum that should work on default configuration without DisplayPort for any recent enough GPUs, and the sizes between this and the GPU maximum size will be functional if the port is set to DisplayPort). The environment variable **VIDEO_PORT** can override which video port is used (defaults to DFP, the first unoccupied port detected in the driver), and overriding **VIDEO_PORT** to an unplugged DisplayPort (for example numbered like DP-0, DP-1, and so on) is recommended for resolutions above 1920 x 1200, because of some driver restrictions applied when the default is a DVI or HDMI port. If all your GPUs are not connected to any monitors and have DisplayPort, simply setting **VIDEO_PORT** to DP-0 is recommended (but not set as default because of legacy compatibility reasons).

Container startup could take some time at first startup as it automatically installs NVIDIA drivers with the same version as the host.

Connect to the spawned noVNC WebSocket instance with a browser in port 5901, no VNC client required (password for the default user is 'vncpasswd').

Wine and Winetricks are bundled by default, comment out the installation section in **Dockerfile** if the user wants to remove them from the container.

This container should not be used in privileged mode, and requires **/dev/ttyN** (N >= 8) virtual terminal device provisioning. All containers in a single node must be provisioned with one chosen virtual terminal device. Check out [smarter-device-manager](https://gitlab.com/arm-research/smarter/smarter-device-manager) or [k8s-hostdev-plugin](https://github.com/bluebeach/k8s-hostdev-plugin) for provisioning this in Kubernetes clusters without privileged access.

```
docker run --gpus 1 --device=/dev/tty63:rw -it -e SIZEW=1920 -e SIZEH=1080 -e SHARED=TRUE -e VNCPASS=vncpasswd -e VIDEO_PORT=DFP -p 5901:5901 ehfd/nvidia-glx-desktop:latest
```

This work was supported in part by NSF awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, the University of California Office of the President, and the University of California San Diego’s California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
