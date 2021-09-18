# docker-nvidia-glx-desktop

MATE Desktop container supporting GLX/Vulkan for NVIDIA GPUs by spawning its own X Server and Guacamole interface instead of using the host X server. Does not require `/tmp/.X11-unix` host sockets or host configuration. Designed for Kubernetes, also supporting audio forwarding.

Use [docker-nvidia-egl-desktop](https://github.com/ehfd/docker-nvidia-egl-desktop) for a MATE Desktop container that directly accesses NVIDIA GPUs without using an X11 Server (but without Vulkan support unlike this container).

Requires reasonably recent NVIDIA GPU drivers and corresponding container toolkits to be set up on the host for allocating GPUs. GPUs should have one or more DVI-D/HDMI/DisplayPort digital video ports instead of having only analog video ports (but this only excludes very ancient GPUs). However, the ports to be used are recommended NOT to be connected with an actual monitor, unless the user wants the remote desktop screen to be shown in the monitor. If you need to connect a real monitor to the X server session spawned by the container, connect the monitor and set **VIDEO_PORT** to the the video port identifier that is connected to the monitor. Manually specify a video port identifier that is not connected to a monitor in **VIDEO_PORT** if you do not want this. **VIDEO_PORT** identifiers and their connection states can be obtained by typing `xrandr -q` when the `$DISPLAY` environment variable is set to the spawned X server display number (for example :0). **Do not start two or more X servers for a single GPU. Use a separate GPU (or use Xvfb/Xdummy/XVnc without hardware acceleration to not use any at all) if you need a host X server, and do not make the GPU available to the containers.**

Since this container fakes the driver to simulate being plugged in to a monitor while it actually does not, make sure the resolutions specified with the environment variables **SIZEW** and **SIZEH** are within the maximum size supported by the GPU. The environment variable **VIDEO_PORT** can override which video port is used (defaults to DFP, the first port detected in the driver). Therefore, overriding **VIDEO_PORT** to an unplugged DisplayPort (for example numbered like DP-0, DP-1, and so on) is recommended for resolutions above 1920 x 1200 at 60 hz, because some driver restrictions are applied when the default is set to an unplugged DVI-D or HDMI port. The maximum size that should work in all cases is 1920 x 1200 at 60 hz, mainly for when the default **VIDEO_PORT** identifier DFP is not set to DisplayPort. The screen sizes between 1920 x 1200 at 60 hz and the maximum supported display size for each port supported by GPU specifications will be possible if the port is set to DisplayPort (connected or disconnected), or when a real monitor or dummy plug to any other type of display ports (including DVI-D and HDMI) has been connected. If all GPUs in the cluster have at least one DisplayPort and they are not connected to any monitors, simply setting **VIDEO_PORT** to DP-0 is recommended (but this is not set as default because of legacy GPU compatibility reasons).

The Quadro M4000 (Maxwell) was the earliest non-datacenter GPU with physical video ports to be tested. GPUs of generations at least Maxwell or after are likely confirmed to work, perhaps even earlier ones as long as a supported driver is installed.

Datacenter GPUs (Tesla) seem to only support resolutions of up to around 2560 x 1600 at 60 hz (**VIDEO_PORT** has to be kept to DFP instead of changing to DP-0 or other DisplayPorts). The K40 (Kepler) GPU did not support RandR (required for some graphical applications using SDL). Other Kepler generation Datacenter GPUs (maybe except the GRID K1 and K2 GPUs with vGPU capabilities) are also unlikely to support RandR, while the remote desktop itself is otherwise functional. RandR support probably starts from Maxwell Datacenter GPUs. Other tested Datacenter GPUs (V100, T4, A40, A100) likely support all graphical applications that consumer GPUs support. However, the performances were not better than consumer GPUs that usually cost a fraction of Datacenter GPUs, and the maximum supported resolutions were even lower.

Container startup could take some time at first launch as it automatically installs NVIDIA drivers with the same version as the host.

Connect to the spawned Apache Guacamole instance with a web browser in port 8080 (the username is "user" and the default password is "mypasswd"). No VNC client installation is required. Press Ctrl+Alt+Shift to toggle the configuration option in Guacamole. Click the fullscreen button in your web browser settings or press F11 after pressing Ctrl+Alt+Shift to bring up fullscreen.

Wine and Winetricks are bundled by default, comment out the installation section in **Dockerfile** if the user wants to remove them from the container.

For building Ubuntu 18.04 containers, in **Dockerfile** change `FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04` to `FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu18.04`.

For Docker this will be sufficient (the container must only be used in unprivileged mode, use `--tmpfs /dev/shm:rw` for a slight performance improvement):

```
docker run --gpus 1 -it -e TZ=UTC -e SIZEW=1920 -e SIZEH=1080 -e CDEPTH=24 -e PASSWD=mypasswd -e VIDEO_PORT=DFP -p 8080:8080 ghcr.io/ehfd/nvidia-glx-desktop:latest
```

This work was supported in part by NSF awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, the University of California Office of the President, and the University of California San Diego’s California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
