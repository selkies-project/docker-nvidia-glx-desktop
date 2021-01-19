FROM ubuntu:20.04

# Based on https://github.com/ryought/glx-docker-headless-gpu/blob/master/Dockerfile
LABEL maintainer "https://github.com/ehfd"

# Make all NVIDIA GPUS visible, but we want to manually install drivers
ARG NVIDIA_VISIBLE_DEVICES=all
# Supress interactive menu while installing keyboard-configuration
ARG DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES all

# Default options (password is 'vncpasswd')
ENV VNCPASS vncpasswd
ENV SIZEW 1920
ENV SIZEH 1080

# Install locales to prevent errors
RUN apt-get clean && \
    apt-get update && \
    apt-get install --no-install-recommends -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Almost same as nvidia/driver https://gitlab.com/nvidia/container-images/driver/-/blob/master/ubuntu20.04/Dockerfile
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        kmod \
        file \
        libc6:i386 \
        libelf-dev \
        libglvnd-dev \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install X server and desktop before driver
RUN apt-get update && apt-get install -y software-properties-common
RUN apt-get install -y \
        wget \
        gzip \
        zip \
        unzip \
        gcc \
        git \
        libc6-dev \
        libglu1 \
        libglu1:i386 \
        libsm6 \
        libxv1 \
        libxv1:i386 \
        make \
        python \
        python-numpy \
        x11-xkb-utils \
        xauth \
        xinit \
        xfonts-base \
        xkb-data \
        libxtst6 \
        libxtst6:i386 \
        mlocate \
        nano \
        vim \
        htop \
        firefox \
        libpci3 \
        supervisor \
        net-tools \
        ubuntu-mate-core \
        ubuntu-mate-desktop && \
    rm -rf /var/lib/apt/lists/*

# Install NVIDIA drivers, including X graphic drivers by omitting --x-{prefix,module-path,library-path,sysconfig-path}
# Driver version must be equal to the host
#ARG BASE_URL=https://us.download.nvidia.com/tesla
ARG BASE_URL=http://us.download.nvidia.com/XFree86/Linux-x86_64
ENV DRIVER_VERSION 450.66
RUN cd /tmp && \
    curl -fSsl -O $BASE_URL/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run && \
    sh NVIDIA-Linux-x86_64-$DRIVER_VERSION.run -x && \
    cd NVIDIA-Linux-x86_64-$DRIVER_VERSION* && \
    ./nvidia-installer --silent \
                       --no-kernel-module \
                       --install-compat32-libs \
                       --no-nouveau-check \
                       --no-nvidia-modprobe \
                       --no-rpms \
                       --no-backup \
                       --no-check-for-alternate-installs \
                       --no-libglx-indirect \
                       --no-install-libglvnd && \
    mkdir -p /usr/src/nvidia-$DRIVER_VERSION && \
    mv LICENSE mkprecompiled kernel /usr/src/nvidia-$DRIVER_VERSION && \
    sed '9,${/^\(kernel\|LICENSE\)/!d}' .manifest > /usr/src/nvidia-$DRIVER_VERSION/.manifest && \
    rm -rf /tmp/*

# Install packages related to X server
# pkg-config: nvidia-xconfig requires this package
# mesa-utils: This package includes glxgears and glxinfo, which is useful for testing GLX drivers
# x11vnc: Make connection between X11 server and VNC client.
# x11-apps: xeyes can be used to make sure that X11 server is running.
RUN apt-get update && apt-get install -y --no-install-recommends \
        mesa-utils \
        x11vnc \
        x11-apps && \
    rm -rf /var/lib/apt/lists/*

# Install Vulkan
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan1 \
        vulkan-utils && \
    rm -rf /var/lib/apt/lists/*

# Sound driver including PulseAudio and GTK library
# If you want to use sounds on docker, try 'pulseaudio --start'
RUN apt-get update && apt-get install -y --no-install-recommends \
        alsa \
        pulseaudio \
        libgtk2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# noVNC and Websockify
ENV NOVNC_VERSION 1.1.0
RUN wget https://github.com/novnc/noVNC/archive/v$NOVNC_VERSION.zip && \
    unzip -q v$NOVNC_VERSION.zip && \
    rm -rf v$NOVNC_VERSION.zip && \
    mv noVNC-$NOVNC_VERSION /opt/noVNC && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify

# X server segfault error mitigation
RUN apt-get update && apt-get install -y --no-install-recommends \
        dbus-x11 \
        libdbus-c++-1-0v5 && \
    rm -rf /var/lib/apt/lists/*

RUN sed -i "s/allowed_users=console/allowed_users=anybody/;$ a needs_root_rights=yes" /etc/X11/Xwrapper.config

# Create user with password ${VNCPASS}
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1000 user && \
    useradd -ms /bin/bash user -u 1000 -g 1000 && \
    usermod -a -G adm,audio,bluetooth,cdrom,dialout,dip,fax,floppy,input,lpadmin,netdev,plugdev,pulse-access,render,scanner,ssh,sudo,tape,tty,video,voice user && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R user:user /home/user && \
    echo "user:${VNCPASS}" | chpasswd

COPY bootstrap.sh /bootstrap.sh
RUN chmod 755 /bootstrap.sh
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 755 /etc/supervisord.conf

EXPOSE 5901

USER user
WORKDIR /home/user

ENTRYPOINT ["/usr/bin/supervisord"]
