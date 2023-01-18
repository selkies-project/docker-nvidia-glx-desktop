# docker-nvidia-glx-desktop

KDE Plasma Desktop container designed for Kubernetes supporting OpenGL GLX and Vulkan for NVIDIA GPUs with WebRTC and HTML5, providing an open source remote cloud graphics or game streaming platform. Spawns its own fully isolated X Server instead of using the host X server, not requiring `/tmp/.X11-unix` host sockets or host configuration.

Use [docker-nvidia-egl-desktop](https://github.com/selkies-project/docker-nvidia-egl-desktop) for a KDE Plasma Desktop container which directly accesses NVIDIA (and unofficially Intel and AMD) GPUs without using an X11 Server, supports sharing a GPU with many containers, and automatically falling back to software acceleration in the absence of GPUs (but with limited graphics performance).

**Read the [Troubleshooting](#troubleshooting) section first before raising an issue. Support is also available with the [Selkies Discord](https://discord.gg/wDNGDeSW5F). Please redirect issues or discussions regarding the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC HTML5 interface to the [project](https://github.com/selkies-project/selkies-gstreamer).**

## Usage

Container startup could take some time at first launch as it automatically installs NVIDIA drivers compatible with the host.

Wine, Winetricks, Lutris, and PlayOnLinux are bundled by default. Comment out the section where it is installed within `Dockerfile` if the user wants to remove them from the container.

There are two web interfaces that can be chosen in this container, the first being the default [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC HTML5 interface (requires a TURN server or host networking), and the second being the fallback [noVNC](https://github.com/novnc/noVNC) WebSocket HTML5 interface. While the noVNC interface does not support audio forwarding and remote cursors for gaming, it can be useful for troubleshooting the selkies-gstreamer WebRTC interface or using this container with low bandwidth environments.

The noVNC interface can be enabled by setting `NOVNC_ENABLE` to `true`. When using the noVNC interface, all environment variables related to the selkies-gstreamer WebRTC interface are ignored, with the exception of `BASIC_AUTH_PASSWORD`. As with the selkies-gstreamer WebRTC interface, the noVNC interface password will be set to `BASIC_AUTH_PASSWORD`, and uses `PASSWD` by default if not set. The noVNC interface also additionally accepts the `NOVNC_VIEWPASS` environment variable, where a view only password with only the ability to observe the desktop without controlling can also be set.

The container requires host NVIDIA GPU driver versions of at least **450.80.02** and preferably **470.42.01**, with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) to be also configured on the host for allocating GPUs. All Maxwell or later generation GPUs in the consumer, professional, or datacenter lineups will not have significant issues running this container, although the selkies-gstreamer high performance NVENC backend may not be available (see the next paragraph). Kepler GPUs are untested and likely does not support the NVENC backend, but can be mostly functional using fallback software acceleration.

The high performance NVENC backend for the selkies-gstreamer WebRTC interface is only supported in GPUs listed as supporting `H.264 (AVCHD)` under the `NVENC - Encoding` section of NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new). If your GPU is not listed as supporting `H.264 (AVCHD)`, add the environment variable `WEBRTC_ENCODER` with the value `x264enc`, `vp8enc`, or `vp9enc` in your container configuration for falling back to software acceleration, which also has a very good performance depending on your CPU.

The username is `user` in both the container user account and the web authentication prompt. The environment variable `PASSWD` is the password of the container user account, and `BASIC_AUTH_PASSWORD` is the password for the HTML5 interface authentication prompt. If `ENABLE_BASIC_AUTH` is set to `true` for selkies-gstreamer (not required for noVNC) but `BASIC_AUTH_PASSWORD` is unspecified, the HTML5 interface password will default to `PASSWD`.
> NOTES: Only one web browser can be connected at a time with the selkies-gstreamer WebRTC interface. If the signaling connection works, but the WebRTC connection fails, read the [Using a TURN Server](#using-a-turn-server) section.

### Running with Docker

1. Run the container with Docker (or other similar container CLIs like Podman):

```
docker run --gpus 1 -it --tmpfs /dev/shm:rw -e TZ=UTC -e SIZEW=1920 -e SIZEH=1080 -e REFRESH=60 -e DPI=96 -e CDEPTH=24 -e VIDEO_PORT=DFP -e PASSWD=mypasswd -e WEBRTC_ENCODER=nvh264enc -e BASIC_AUTH_PASSWORD=mypasswd -p 8080:8080 ghcr.io/selkies-project/nvidia-glx-desktop:latest
```
> NOTES: The container tags available are `latest` and `22.04` for Ubuntu 22.04, `20.04` for Ubuntu 20.04, and `18.04` for Ubuntu 18.04. Replace all instances of `mypasswd` with your desired password. `BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified. The container must not be run in privileged mode.

Change `WEBRTC_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the selkies-gstreamer interface if your GPU does not support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

2. Connect to the web server with a browser on port 8080. You may also separately configure a reverse proxy to this port for external connectivity.
> NOTES: Additional configurations and environment variables for the selkies-gstreamer WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [selkies-gstreamer main script](https://github.com/selkies-project/selkies-gstreamer/blob/master/src/selkies_gstreamer/__main__.py).

3. (Not Applicable for noVNC) **Read carefully if the selkies-gstreamer WebRTC HTML5 interface does not connect.** Choose whether to use host networking or a TURN server. The selkies-gstreamer WebRTC HTML5 interface will likely just start working if you add `--network host` to the above `docker run` command. However, this may be restricted or be undesired because of security reasons. If so, check if the container starts working after omitting `--network host`. If it does not work, you need a TURN server. Read the [Using a TURN Server](#using-a-turn-server) section and add the environment variables `-e TURN_HOST=`, `-e TURN_PORT=`, and pick one of `-e TURN_SHARED_SECRET=` or both `-e TURN_USERNAME=` and `-e TURN_PASSWORD=` environment variables to the `docker run` command based on your authentication method.

### Running with Kubernetes

1. Create the Kubernetes Secret with your authentication password:

```bash
kubectl create secret generic my-pass --from-literal=my-pass=YOUR_PASSWORD
```
> NOTES: Replace `YOUR_PASSWORD` with your desired password, and change the name `my-pass` to your preferred name of the Kubernetes secret with the `xgl.yml` file changed accordingly as well. It is possible to skip the first step and directly provide the password with `value:` in `xgl.yml`, but this exposes the password in plain text.

2. Create the pod after editing the `xgl.yml` file to your needs, explanations are available in the file:

```bash
kubectl create -f xgl.yml
```
> NOTES: The container tags available are `latest` and `22.04` for Ubuntu 22.04, `20.04` for Ubuntu 20.04, and `18.04` for Ubuntu 18.04. `BASIC_AUTH_PASSWORD` will default to `PASSWD` if unspecified.

Change `WEBRTC_ENCODER` to `x264enc`, `vp8enc`, or `vp9enc` when using the selkies-gstreamer WebRTC interface if your GPU does not support `H.264 (AVCHD)` under the `NVENC - Encoding` section in NVIDIA's [Video Encode and Decode GPU Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

3. Connect to the web server spawned at port 8080. You may configure the ingress endpoint or reverse proxy that your Kubernetes cluster provides to this port for external connectivity.
> NOTES: Additional configurations and environment variables for the selkies-gstreamer WebRTC HTML5 interface are listed in lines that start with `parser.add_argument` within the [selkies-gstreamer main script](https://github.com/selkies-project/selkies-gstreamer/blob/master/src/selkies_gstreamer/__main__.py).

4. (Not Applicable for noVNC) **Read carefully if the selkies-gstreamer WebRTC HTML5 interface does not connect.** Choose whether to use host networking or a TURN server. The selkies-gstreamer WebRTC HTML5 interface will likely just start working if you uncomment `hostNetwork: true` in `xgl.yml`. However, this may be restricted or be undesired because of security reasons. If so, check if the container starts working after commenting out `hostNetwork: true`. If it does not work, you need a TURN server. Read the [Using a TURN Server](#using-a-turn-server) section and fill in the environment variables `TURN_HOST` and `TURN_PORT`, then pick one of `TURN_SHARED_SECRET` or both `TURN_USERNAME` and `TURN_PASSWORD` environment variables based on your authentication method.

## Using a TURN server

Note that this section is only required for the selkies-gstreamer WebRTC HTML5 interface. For an easy fix to when the signaling connection works, but the WebRTC connection fails, add the option `--network host` to your Docker command, or uncomment `hostNetwork: true` in your `xgl.yml` file when using Kubernetes (note that your cluster may have not allowed this, resulting in an error). This exposes your container to the host network, which disables network isolation. If this does not fix the connection issue (normally when the host is behind another firewall) or you cannot use this fix for security or technical reasons, read the below text.

In most cases when either of your server or client has a permissive firewall, the default Google STUN server configuration will work without additional configuration. However, when connecting from networks that cannot be traversed with STUN, a TURN server is required.

### Deploying a TURN server

**Read the instructions from [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer#using-a-turn-server) if want to deploy a TURN server or use a public TURN server instance.**

### Configuring with Docker

With Docker (or Podman), use the `-e` option to add the `TURN_HOST`, `TURN_PORT` environment variables. This is the hostname or IP and the port of the TURN server (3478 in most cases).

You may set `TURN_PROTOCOL` to `tcp` if you are only able to open TCP ports for the coTURN container to the internet, or if the UDP protocol is blocked or throttled in your client network. You may also set `TURN_TLS` to `true` with the `-e` option if TURN over TLS/DTLS was properly configured.

You also require to provide either just `TURN_SHARED_SECRET` for time-limited shared secret TURN authentication, or both `TURN_USERNAME` and `TURN_PASSWORD` for legacy long-term TURN authentication, depending on your TURN server configuration. Provide just one of these authentication methods, not both.

### Configuring with Kubernetes

Your TURN server will use only one out of two ways to authenticate the client, so only provide one type of authentication method. The time-limited shared secret TURN authentication requires to only provide the Base64 encoded `TURN_SHARED_SECRET`. The legacy long-term TURN authentication requires to provide both `TURN_USERNAME` and `TURN_PASSWORD` credentials.

#### Time-limited shared secret authentication

1. Create a secret containing the TURN shared secret:

```bash
kubectl create secret generic turn-shared-secret --from-literal=turn-shared-secret=MY_TURN_SHARED_SECRET
```
> NOTES: Replace `MY_TURN_SHARED_SECRET` with the shared secret of the TURN server, then changing the name `turn-shared-secret` to your preferred name of the Kubernetes secret, with the `xgl.yml` file also being changed accordingly.

2. Uncomment the lines in the `xgl.yml` file related to TURN server usage, updating the `TURN_HOST` and `TURN_PORT` environment variable as needed:

```yaml
- name: TURN_HOST
  value: "turn.example.com"
- name: TURN_PORT
  value: "3478"
- name: TURN_SHARED_SECRET
  valueFrom:
    secretKeyRef:
      name: turn-shared-secret
      key: turn-shared-secret
- name: TURN_PROTOCOL
  value: "udp"
- name: TURN_TLS
  value: "false"
```
> NOTES: It is possible to skip the first step and directly provide the shared secret with `value:`, but this exposes the shared secret in plain text. Set `TURN_PROTOCOL` to `tcp` if you were able to only open TCP ports while creating your own coTURN Deployment/DaemonSet, or if your client network throttles or blocks the UDP protocol.

#### Legacy long-term authentication

1. Create a secret containing the TURN password:

```bash
kubectl create secret generic turn-password --from-literal=turn-password=MY_TURN_PASSWORD
```
> NOTES: Replace `MY_TURN_PASSWORD` with the password of the TURN server, then changing the name `turn-password` to your preferred name of the Kubernetes secret, with the `xgl.yml` file also being changed accordingly.

2. Uncomment the lines in the `xgl.yml` file related to TURN server usage, updating the `TURN_HOST`, `TURN_PORT`, and `TURN_USERNAME` environment variable as needed:

```yaml
- name: TURN_HOST
  value: "turn.example.com"
- name: TURN_PORT
  value: "3478"
- name: TURN_USERNAME
  value: "username"
- name: TURN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: turn-password
      key: turn-password
- name: TURN_PROTOCOL
  value: "udp"
- name: TURN_TLS
  value: "false"
```
> NOTES: It is possible to skip the first step and directly provide the TURN password with `value:`, but this exposes the TURN password in plain text. Set `TURN_PROTOCOL` to `tcp` if you were able to only open TCP ports while creating your own coTURN Deployment/DaemonSet, or if your client network throttles or blocks the UDP protocol.

## Comparison

[docker-nvidia-egl-desktop](https://github.com/selkies-project/docker-nvidia-egl-desktop): It's generally recommended to use docker-nvidia-glx-desktop when possible for maximum capabilities and performance. It starts its own X server inside the container without exposure to security risks. However, docker-nvidia-egl-desktop is versatile in various environments and has less processes running, meaning less possible complications in restricted environments. It is also possible to be used in HPC clusters with Apptainer/Singularity available, and sharing a GPU with multiple containers is also possible. Unofficial support for Intel and AMD GPUs is also available.

[Sunshine](https://github.com/LizardByte/Sunshine): This repository is an open-source server for NVIDIA's GameStream protocol, supporting all clients that can install [Moonlight](https://github.com/moonlight-stream). Try it if you don't need username/password authentication and you don't need to use containers. [Games on Whales](https://github.com/games-on-whales/gow) is a container implementation of Sunshine. However, many container ports have to be accessible to the internet, and because of its requirement for the `/dev/uinput` device, unsafe `privileged` access for containers are required. The [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project, which is integrated to our container, does not require more than one port open from the container (TURN server may be required but can be deployed in a different environment with flexibility), and has almost equal performance while using only a web browser as a client.

[x11docker](https://github.com/mviereck/x11docker): This has a lot of features and is very solid if you are the sole user in full control of the host. However, it starts a lot of processes in the host and is nearly impossible to contain the environment. Kubernetes is also not supported. The docker-nvidia-glx-desktop repository contains everything in the container, with the only requirement being the NVIDIA Container Toolkit with adequate `NVIDIA_DRIVER_CAPABILITIES`, meaning that the container is portable anywhere Docker/Podman or Kubernetes can be run.

[Xpra](https://github.com/Xpra-org/xpra): This is a feature-complete all-in-one remote desktop application optimized for Linux, although not exactly meant for full screen workloads and its HTML5 web interface is not optimized for intensive graphics workloads. Supports various protocols and various hardware acceleration methods.

[KasmVNC](https://github.com/kasmtech/KasmVNC): This almost landed as a replacement for the existing [noVNC](https://github.com/novnc/noVNC) fallback installation, as it incorporates improved functionalities. However, performance compared to [x11vnc](https://github.com/LibVNC/x11vnc) combined with [noVNC](https://github.com/novnc/noVNC) was not much better.

[Parsec](https://parsec.app): Parsec is not open-source. However, it brings top-level performance on Windows or Mac hosts. Try it if you don't need to use containers. But the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project uses the same APIs and isn't that far back in terms of performance.

[CloudRetro](https://github.com/giongto35/cloud-game) and [CloudMorph](https://github.com/giongto35/cloud-morph): This uses WebRTC in a web browser, like the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) project. The principles of this project are pretty similar to our project. However, hardware acceleration across various GPUs is currently not implemented. Hardware acceleration is critical to remote desktop and workload performance, and therefore you should use our repository if you need hardware acceleration.

[neko](https://github.com/m1k1o/neko): Uses WebRTC in a web browser with a text chat, and it is also designed for containers (uses GStreamer too), but I had a hard time in conditions where more than one port can't be exposed or when using reverse proxies. Use this if you want good performance while requiring multiple users to be able to access the screen. However, note that you can always use conference software such as [Zoom](https://zoom.us), [Jitsi](https://meet.jit.si), or [BigBlueButton](https://bigbluebutton.org) to share your screen while using our container.

[RustDesk](https://github.com/rustdesk/rustdesk): This is an open-source TeamViewer or AnyDesk. You can use this to have other people control your node if you need to.

[Weylus](https://github.com/H-M-H/Weylus): This is a very interesting project, and has many technologies in common. Use this if you want to turn your tablet or smartphone to a graphic tablet for your PC.

[GamingAnywhere](https://github.com/chunying/gaminganywhere): This is the father of all open-source remote desktop and game streaming protocols. However, it has been created a long time ago and thus reached its end of life.

## Troubleshooting

### The container does not work.

Check that the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) is properly configured in the host. After that, check the environment variable `NVIDIA_DRIVER_CAPABILITIES` after starting a shell interface inside the container.

`NVIDIA_DRIVER_CAPABILITIES` should be set to `all`, or include a comma-separated list of `compute` (requirement for CUDA and OpenCL, or for the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC remote desktop interface), `utility` (requirement for `nvidia-smi` and NVML), `graphics` (requirement for OpenGL and part of the requirement for Vulkan), `video` (required for encoding or decoding videos using NVIDIA GPUs, or for the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC remote desktop interface), `display` (the other requirement for Vulkan), and optionally `compat32` if you use Wine or 32-bit graphics applications.

If you checked everything here, scroll down.

### I want to share one GPU with multiple containers to run GUI workloads.

Note that because of restrictions from Xorg, it is not possible to share one GPU to multiple Xorg servers running in different containers. Use [docker-nvidia-egl-desktop](https://github.com/selkies-project/docker-nvidia-egl-desktop) if you intend to do this.

### The container does not work if an existing GUI, desktop environment, or X server is running in the host outside the container. / I want to use this container in `--privileged` mode or with `--cap-add` and do not want other containers to interfere.

In order to use an X server on the host for your monitor with one GPU, and provision the other GPUs to the containers, you must change your `/etc/X11/xorg.conf` configuration of the host.

First, use `sudo nvidia-xconfig --no-probe-all-gpus --busid=$BUS_ID --only-one-x-screen` to generate `/etc/X11/xorg.conf` where `BUS_ID` is generated with the below script. Set `GPU_SELECT` to the ID (from `nvidia-smi`) of the specific GPU you want to provision.

```
HEX_ID=$(nvidia-smi --query-gpu=pci.bus_id --id="$GPU_SELECT" --format=csv | sed -n 2p)
IFS=":." ARR_ID=($HEX_ID)
unset IFS
BUS_ID=PCI:$((16#${ARR_ID[1]})):$((16#${ARR_ID[2]})):$((16#${ARR_ID[3]}))
```

Then, edit the `/etc/X11/xorg.conf` file of your host outside the container and add the below snippet to the end of the file. If you want to use containers in `--privileged` mode or with `--cap-add`, add the snippet to the `/etc/X11/xorg.conf` files of all other containers running an Xorg server as well (has been already added for this container). The exact file location may vary if not using the NVIDIA graphics driver.

```
Section "ServerFlags"
    Option "AutoAddGPU" "false"
EndSection
```

The below command adds the above snippet automatically. The exact file location may vary if not using the NVIDIA graphics driver.

```bash
echo -e "Section \"ServerFlags\"\n    Option \"AutoAddGPU\" \"false\"\nEndSection" | sudo tee -a /etc/X11/xorg.conf > /dev/null
```

[Reference](https://man.archlinux.org/man/extra/xorg-server/xorg.conf.d.5.en)

If you restart your OS or the Xorg server, you will now be able to use one GPU for your host X server and your real monitor, and use the rest of the GPUs for the containers.

Then, you must avoid the GPU of which you are using for your host X server. Use `docker --gpus '"device=1,2"'` to provision GPUs with device IDs 1 and 2 to the container, avoiding the GPU with the ID of 0 that is used by the host X server, if you set `GPU_SELECT` to the ID of 0. Note that `--gpus 1` means any single GPU, not the GPU device ID of 1.

### Vulkan does not work.

Make sure that the `NVIDIA_DRIVER_CAPABILITIES` environment variable is set to `all`, or includes both `graphics` and `display`. The `display` capability is especially crucial to Vulkan, but the container does start without noticeable issues other than Vulkan without `display`, despite its name.

### The container does not work if I set the resolution above 1920 x 1200 or 2560 x 1600 in 60 hz.

#### Short answer

If your GPU is a consumer or professional GPU, change the `VIDEO_PORT` environment variable from `DFP` to `DP-0` if `DP-0` is empty, or any empty `DP-*` port. Set `VIDEO_PORT` to where your monitor is connected if you want to show the remote desktop in a real monitor. If your GPU is a Datacenter (Tesla) GPU, keep the `VIDEO_PORT` environment variable to `DFP`, and your maximum resolution is at 2560 x 1600. To go above this restriction, you may set `VIDEO_PORT` to `none`, but you must use borderless window instead of fullscreen, and this may lead to quite a lot of applications not starting, showing errors related to `XRANDR` or `RANDR`.

#### Long answer

The container simulates the GPU to become plugged into a physical DVI-D/HDMI/DisplayPort digital video interface in consumer and professional GPUs with the `ConnectedMonitor` NVIDIA driver option. The container uses virtualized DVI-D ports for this purpose in Datacenter (Tesla) GPUs.

The ports to be used should **only** be connected with an actual monitor if the user wants the remote desktop screen to be shown on that monitor. If you want to show the remote desktop screen spawned by the container in a physical monitor, connect the monitor and set `VIDEO_PORT` to the the video interface identifier that is connected to the monitor. If not, avoid the video interface identifier that is connected to the monitor.

`VIDEO_PORT` identifiers and their connection states can be obtained by typing `xrandr -q` when the `DISPLAY` environment variable is set to the number of the spawned X server display (for example `:0`). As an alternative, you may set `VIDEO_PORT` to `none` (which effectively sets `--use-display-device=None`), but you must use borderless window instead of fullscreen, and this may lead to quite a lot of applications not starting because the `RANDR` extension is not available in the X server.

> NOTES: Do not start two or more X servers for a single GPU. Use a separate GPU (or use Xvfb/Xdummy/Xvnc without hardware acceleration to use no GPUs at all) if you need a host X server unaffiliated with containers, and do not make the GPU available to the container runtime.

Since this container simulates the GPU being virtually plugged into a physical monitor while it actually does not, make sure the resolutions specified with the environment variables `SIZEW` and `SIZEH` are within the maximum size supported by the GPU. The environment variable `VIDEO_PORT` can override which video port is used (defaults to `DFP`, the first interface detected in the driver). Therefore, specifying `VIDEO_PORT` to an unplugged DisplayPort (for example numbered like `DP-0`, `DP-1`, and so on) is recommended for resolutions above 1920 x 1200 at 60 hz, because some driver restrictions are applied when the default is set to an unplugged physical DVI-D or HDMI port. The maximum size that should work in all cases is 1920 x 1200 at 60 hz, mainly for when the default `VIDEO_PORT` identifier `DFP` is not set to DisplayPort. The screen sizes over 1920 x 1200 at 60 hz but under the maximum supported display size specified for each port (supported by GPU specifications) will be possible if the port is set to DisplayPort (both physically connected or disconnected), or when a physical monitor or dummy plug to any other type of display ports (including DVI-D and HDMI) has been physically connected. If all GPUs in the cluster have at least one DisplayPort and they are not physically connected to any monitors, simply setting `VIDEO_PORT` to `DP-0` is recommended (but this is not set as default because of legacy GPU compatibility reasons).

Datacenter (Tesla) GPUs seem to only support resolutions of up to around 2560 x 1600 at 60 hz (`VIDEO_PORT` must be kept to `DFP` instead of changing to `DP-0` or other DisplayPort identifiers). The K40 (Kepler) GPU did not support RandR (required for some graphical applications using SDL and other graphical frameworks). Other Kepler generation Datacenter GPUs (maybe except the GRID K1 and K2 GPUs with vGPU capabilities) are also unlikely to support RandR, thus Datacenter GPU RandR support probably starts from Maxwell. Other tested Datacenter GPUs (V100, T4, A40, A100) support all graphical applications that consumer GPUs support. However, the performances were not better than consumer GPUs that usually cost a fraction of Datacenter GPUs, and the maximum supported resolutions were even lower.

### I want to use `systemd`, FUSE mounts, or sandboxed (containerized) application distribution systems like Flatpak, Snapcraft (snap), AppImage, and etc.

**Use the option `--appimage-extract-and-run` or `--appimage-extract` with your AppImage to run them in a container. Alternatively, set `export APPIMAGE_EXTRACT_AND_RUN=1` to your current shell.**

For `systemd`, FUSE mounts, or other sandboxed application distribution systems, do not use them with containers. You can use them if you add unsafe capabilities to your containers, but it will break the isolation of the containers. This is especially bad if you are using Kubernetes. There will likely be an alternative way to install the applications, including [Personal Package Archives](https://launchpad.net/ubuntu/+ppas). For some applications, there will be options to disable sandboxing when running or options to extract files before running.

---
This project involved a collaboration effort with members of the [Selkies Project](https://github.com/selkies-project), incorporating the [selkies-gstreamer](https://github.com/selkies-project/selkies-gstreamer) WebRTC remote desktop streaming application. Commercial support for this container is available with [itopia Spaces](https://itopiaspaces.com).

This work was supported in part by National Science Foundation (NSF) awards CNS-1730158, ACI-1540112, ACI-1541349, OAC-1826967, OAC-2112167, CNS-2100237, CNS-2120019, the University of California Office of the President, and the University of California San Diego's California Institute for Telecommunications and Information Technology/Qualcomm Institute. Thanks to CENIC for the 100Gbps networks.
