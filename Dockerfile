FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04

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
ENV VIDEO_PORT DFP

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

# Install Xorg, MATE desktop, and others
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
        dbus-x11 \
        libdbus-c++-1-0v5 \
        x11-xkb-utils \
        x11-xserver-utils \
        xauth \
        xinit \
        xfonts-base \
        xkb-data \
        libxrandr-dev \
        xorg-dev \
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
    # Remove Bluetooth packages that throw errors
    apt-get autoremove --purge -y blueman bluez bluez-cups pulseaudio-module-bluetooth && \
    rm -rf /var/lib/apt/lists/*

# Install Vulkan and fix containerization issues
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

# Wine and Winetricks, comment out the below lines to disable
ARG WINE_BRANCH=stable
RUN curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - && \
    apt-add-repository "deb https://dl.winehq.org/wine-builds/ubuntu/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" && \
    apt-get update && apt-get install -y --install-recommends winehq-${WINE_BRANCH} && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL -o /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod 755 /usr/bin/winetricks && \
    curl -fsSL -o /usr/share/bash-completion/completions/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion

# noVNC and Websockify
ENV NOVNC_VERSION 1.2.0
RUN curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar -xzf - -C /opt && \
    mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify

# Create user with password ${VNCPASS}
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1000 user && \
    useradd -ms /bin/bash user -u 1000 -g 1000 && \
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,input,lp,lpadmin,netdev,plugdev,render,scanner,ssh,sudo,tape,tty,video,voice user && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R user:user /home/user && \
    echo "user:${VNCPASS}" | chpasswd

COPY bootstrap.sh /etc/bootstrap.sh
RUN chmod 755 /etc/bootstrap.sh
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 755 /etc/supervisord.conf

EXPOSE 5901

USER user
WORKDIR /home/user

ENTRYPOINT ["/usr/bin/supervisord"]
