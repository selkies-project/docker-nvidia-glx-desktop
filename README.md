# docker-nvidia-glx-desktop

MATE Desktop container supporting GLX/Vulkan for NVIDIA GPUs by spawning its own X Server and noVNC WebSocket interface instead of using the host X server. Does not require `/tmp/.X11-unix` host sockets or host configuration. Designed for Kubernetes.

Use [docker-nvidia-egl-desktop](https://github.com/ehfd/docker-nvidia-egl-desktop) for a MATE Desktop container that directly accesses NVIDIA GPUs without using an X11 Server (but without Vulkan support unlike this container).

Requires reasonably recent NVIDIA GPU drivers and corresponding container toolkits to be set up on the host for allocating GPUs. GPUs should have one or more DVI-D/HDMI/DisplayPort digital video ports instead of having only analog video ports (which mean very ancient GPUs). However, the ports to be used are recommended NOT to be connected with an actual monitor, unless the user wants the remote desktop screen to be shown in the monitor. If you need to connect a real monitor to the X server session spawned by the container, connect the monitor and set **VIDEO_PORT** to the the video port connected to the monitor. Manually specify a video port that is not connected to a monitor in **VIDEO_PORT**. **VIDEO_PORT** identifiers and their connection states can be obtained by typing `xrandr -q` when the `$DISPLAY` environment variable is set. **Do not start more than one X server for one GPU. Use a separate GPU (or do not use one) for the host X server, and do not make it available to the containers.**

Since this container fakes the driver to simulate being plugged in to a monitor while it actually does not, make sure the resolutions specified with the environment variables **SIZEW** and **SIZEH** are within the maximum size supported by the GPU. The environment variable **VIDEO_PORT** can override which video port is used (defaults to DFP, the first port detected in the driver). Therefore, overriding **VIDEO_PORT** to an unplugged DisplayPort (for example numbered like DP-0, DP-1, and so on) is recommended for resolutions above 1920 x 1200, because of some driver restrictions applied when the default is set to a DVI-D or HDMI port. The maximum size that should work in all cases is 1920 x 1200 at 60 hz, mainly for when the default DFP **VIDEO_PORT** identifier is not set to DisplayPort. The sizes between 1920 x 1200 and the maximum size for each port supported by GPU specifications will be possible if the port is set to DisplayPort, or when a real monitor or dummy plug to any other type of display ports including DVI-D and HDMI has been connected. If all GPUs have DisplayPort and they are not connected to any monitors, simply setting **VIDEO_PORT** to DP-0 is recommended (but this is not set as default because of legacy compatibility reasons).

The Quadro M4000 (Maxwell) was the earliest GPU with physical video ports to be tested. GPUs of generations at least at Maxwell or after are likely confirmed to work, perhaps even earlier ones as long as a supported driver is installed.

Datacenter GPUs (Tesla) seem to only support resolutions of up to around 2560 x 1600 (**VIDEO_PORT** has to be kept to DFP instead of changing to DP-0 or other DisplayPorts). The K40 (Kepler) GPU did not support RandR (required for some graphical applications using SDL). Other Kepler generation Datacenter GPUs (maybe except the GRID K1 and K2 GPUs with vGPU capabilities) are also unlikely to support RandR, while the remote desktop itself is otherwise functional. RandR support probably starts from Maxwell Datacenter GPUs. Other tested Datacenter GPUs (V100, T4, A40, A100) likely support all graphical applications that consumer GPUs support. However, the performances were not better than consumer GPUs that usually cost a fraction of Datacenter GPUs, and the maximum supported resolutions were even lower.

Container startup could take some time at first launch as it automatically installs NVIDIA drivers with the same version as the host.

Connect to the spawned noVNC WebSocket instance with a browser in port 5901, no installed VNC client is required (password for the default user is 'vncpasswd').

Wine and Winetricks are bundled by default, comment out the installation section in **Dockerfile** if the user wants to remove them from the container.

This container should not be used in privileged mode, and requires to provision one **/dev/ttyN** (N >= 8) virtual terminal device in unprivileged mode. All containers in a single node should be provisioned with the exact same virtual terminal device. Check out [smarter-device-manager](https://gitlab.com/arm-research/smarter/smarter-device-manager) or [k8s-hostdev-plugin](https://github.com/bluebeach/k8s-hostdev-plugin) for provisioning this in Kubernetes clusters without privileged access.

```
docker run --gpus 1 --device=/dev/tty63:rw -it -e SIZEW=1920 -e SIZEH=1080 -e SHARED=TRUE -e VNCPASS=vncpasswd -e VIDEO_PORT=DFP -p 5901:5901 ehfd/nvidia-glx-desktop:latest
```

This work was supported in part by NSF awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, the University of California Office of the President, and the University of California San Diego’s California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
