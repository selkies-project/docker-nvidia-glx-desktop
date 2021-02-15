FROM ubuntu:20.04

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
ENV CDEPTH 24

# Install locales to prevent errors
RUN apt-get clean && \
    apt-get update && \
    apt-get install --no-install-recommends -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# https://gitlab.com/nvidia/container-images/driver/-/blob/master/ubuntu20.04/Dockerfile
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -o APT::Immediate-Configure=false -y --no-install-recommends \
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

# Install Xorg and desktop packages
RUN apt-get update && apt-get install -y \
        software-properties-common \
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
        python3 \
        python3-numpy \
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
        ubuntu-mate-desktop \
        mesa-utils \
        x11vnc \
        x11-apps && \
    rm -rf /var/lib/apt/lists/*

# Install Vulkan
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan-dev \
        vulkan-validationlayers-dev \
        vulkan-utils \
        meson && \
    rm -rf /var/lib/apt/lists/* && \
    cd /tmp && \
    git clone https://github.com/aejsmith/vkdevicechooser && \
    cd vkdevicechooser && \
    meson builddir --prefix=/usr && \
    meson install -C builddir && \
    rm -rf /tmp/*

# Sound driver including PulseAudio and GTK library
# If you want to use sounds on docker, try 'pulseaudio --start'
RUN apt-get update && apt-get install -y --no-install-recommends \
        alsa \
        pulseaudio \
        libgtk2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# noVNC and Websockify
ENV NOVNC_VERSION 1.2.0
RUN curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar -xzf - -C /opt && \
    mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify

# Xorg segfault error mitigation
RUN apt-get update && apt-get install -y --no-install-recommends \
        dbus-x11 \
        libdbus-c++-1-0v5 && \
    rm -rf /var/lib/apt/lists/*

# Create user with password ${VNCPASS}
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1000 user && \
    useradd -ms /bin/bash user -u 1000 -g 1000 && \
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,input,lpadmin,netdev,plugdev,render,scanner,ssh,sudo,tape,tty,video,voice user && \
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
