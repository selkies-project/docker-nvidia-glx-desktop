FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04
# Comment the line above and uncomment the line below for Ubuntu 18.04
#FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu18.04

LABEL maintainer "https://github.com/ehfd"

# Make all NVIDIA GPUs visible, but we want to manually install drivers
ARG NVIDIA_VISIBLE_DEVICES=all
# Supress interactive menu while installing keyboard-configuration
ARG DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES all

# Default options (password is "mypasswd")
ENV TZ UTC
ENV PASSWD mypasswd
ENV SIZEW 1920
ENV SIZEH 1080
ENV CDEPTH 24
ENV VIDEO_PORT DFP

# Install locales to prevent errors
RUN apt-get clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install Xorg, MATE desktop, and others
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
        software-properties-common \
        apt-utils \
        build-essential \
        ca-certificates \
        kmod \
        libc6:i386 \
        libc6-dev \
        curl \
        file \
        wget \
        gzip \
        zip \
        unzip \
        gcc \
        git \
        make \
        python \
        python-numpy \
        python3 \
        python3-numpy \
        mlocate \
        nano \
        vim \
        htop \
        firefox \
        supervisor \
        net-tools \
        libpci3 \
        libelf-dev \
        libglvnd-dev \
        pkg-config \
        mesa-utils \
        libglu1 \
        libglu1:i386 \
        libsm6 \
        libxv1 \
        libxv1:i386 \
        libxtst6 \
        libxtst6:i386 \
        x11-xkb-utils \
        x11-xserver-utils \
        x11-apps \
        dbus-x11 \
        libdbus-c++-1-0v5 \
        xauth \
        xinit \
        xfonts-base \
        xkb-data \
        libxrandr-dev \
        xorg-dev \
        ubuntu-mate-desktop && \
    if [ "$(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2)" = "bionic" ]; then apt-get install -y --no-install-recommends vulkan-utils; else apt-get install -y --no-install-recommends vulkan-tools; fi && \
    # Remove Bluetooth packages that throw errors
    apt-get autoremove --purge -y blueman bluez bluez-cups pulseaudio-module-bluetooth && \
    rm -rf /var/lib/apt/lists/*

# Wine and Winetricks, comment out the below lines to disable
ARG WINE_BRANCH=stable
RUN if [ "$(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2)" = "bionic" ]; then add-apt-repository ppa:cybermax-dexter/sdl2-backport; fi && \
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - && \
    apt-add-repository "deb https://dl.winehq.org/wine-builds/ubuntu/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" && \
    apt-get update && apt-get install -y --install-recommends winehq-${WINE_BRANCH} && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL -o /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod 755 /usr/bin/winetricks && \
    curl -fsSL -o /usr/share/bash-completion/completions/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion

# Apache Guacamole and x11vnc
ENV TOMCAT_VERSION 9.0.50
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2-dev \
    libjpeg-turbo8-dev \
    libpng-dev \
    libtool-bin \
    libossp-uuid-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    freerdp2-dev \
    libpango1.0-dev \
    libssh2-1-dev \
    libtelnet-dev \
    libvncserver-dev \
    libwebsockets-dev \
    libpulse-dev \
    libssl-dev \
    libvorbis-dev \
    libwebp-dev \
    autoconf \
    automake \
    autotools-dev \
    pulseaudio \
    pavucontrol \
    openssh-server \
    openssh-sftp-server \
    default-jdk \
    maven \
    libxdamage-dev \
    libxinerama-dev \
    libxrandr-dev \
    libxss-dev \
    libxtst-dev \
    libv4l-dev \
    libavahi-client-dev \
    chrpath \
    debhelper && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/LibVNC/x11vnc.git /tmp/x11vnc && \
    cd /tmp/x11vnc && autoreconf -fi && ./configure && make install && cd / && rm -rf /tmp/* && \
    curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-$(echo $TOMCAT_VERSION | cut -d "." -f 1)/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz | tar -xzf - -C /opt && \
    mv /opt/apache-tomcat-$TOMCAT_VERSION /opt/tomcat && \
    git clone https://github.com/apache/guacamole-server.git /tmp/guacamole-server && \
    cd /tmp/guacamole-server && autoreconf -fi && ./configure --with-init-dir=/etc/init.d && make install && ldconfig && cd / && rm -rf /tmp/* && \
    git clone https://github.com/apache/guacamole-client.git /tmp/guacamole-client && \
    cd /tmp/guacamole-client && JAVA_HOME=/usr/lib/jvm/default-java mvn package && rm -rf /opt/tomcat/webapps/* && mv guacamole/target/guacamole*.war /opt/tomcat/webapps/ROOT.war && chmod +x /opt/tomcat/webapps/ROOT.war && cd / && rm -rf /tmp/* && \
    echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.0/8 auth-anonymous=1" >> /etc/pulse/default.pa

# Create user with password ${PASSWD}
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1000 user && \
    useradd -ms /bin/bash user -u 1000 -g 1000 && \
    usermod -a -G adm,audio,cdrom,dialout,dip,fax,floppy,input,lp,lpadmin,netdev,plugdev,scanner,ssh,sudo,tape,tty,video,voice user && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    chown -R user:user /home/user /opt/tomcat && \
    echo "user:${PASSWD}" | chpasswd && \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone

COPY entrypoint.sh /etc/entrypoint.sh
RUN chmod 755 /etc/entrypoint.sh
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 755 /etc/supervisord.conf

EXPOSE 8080

USER user
WORKDIR /home/user

ENTRYPOINT ["/usr/bin/supervisord"]
