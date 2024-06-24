#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -e

# Set password for basic authentication
if [ "$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')" = "true" ] && [ -z "${SELKIES_BASIC_AUTH_PASSWORD}" ]; then export SELKIES_BASIC_AUTH_PASSWORD="${PASSWD}"; fi

# Set default display
export DISPLAY="${DISPLAY:-:0}"
# PipeWire-Pulse server socket path
export PIPEWIRE_LATENCY="32/48000"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${PULSE_RUNTIME_PATH:-${XDG_RUNTIME_DIR:-/tmp}/pulse}/native}"

# Configure NGINX
echo "# Selkies KasmVNC NGINX Configuration
server {
    listen 8080 $(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then printf \"ssl\"; fi);
    listen [::]:8080 $(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then printf \"ssl\"; fi);
    ssl_certificate ${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem};
    ssl_certificate_key ${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key};

    location / {
        proxy_set_header        Upgrade \$http_upgrade;
        proxy_set_header        Connection \"upgrade\";

        proxy_set_header        Host \$host;
        proxy_set_header        X-Real-IP \$remote_addr;
        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto \$scheme;

        proxy_http_version      1.1;
        proxy_read_timeout      1800s;
        proxy_send_timeout      1800s;
        proxy_connect_timeout   1800s;
        proxy_buffering         off;

        client_max_body_size    10M;

        proxy_pass http$(if [ \"$(echo ${SELKIES_ENABLE_HTTPS} | tr '[:upper:]' '[:lower:]')\" = \"true\" ]; then printf \"s\"; fi)://localhost:8081;
    }
}" | tee /etc/nginx/sites-available/default > /dev/null

# Configure KasmVNC
export KASM_DISPLAY=":50"
yq -i "
.command_line.prompt = false |
.network.interface = \"0.0.0.0\" |
.network.websocket_port = 8081 |
.network.ssl.require_ssl = $(echo ${SELKIES_ENABLE_HTTPS-false} | tr '[:upper:]' '[:lower:]') |
.encoding.max_frame_rate = ${DISPLAY_REFRESH}
" /etc/kasmvnc/kasmvnc.yaml

if [ -n "${SELKIES_HTTPS_CERT}" ]; then yq -i ".network.ssl.pem_certificate = \"${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem}\"" /etc/kasmvnc/kasmvnc.yaml; fi
if [ -n "${SELKIES_HTTPS_KEY}" ]; then yq -i ".network.ssl.pem_key = \"${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key}\"" /etc/kasmvnc/kasmvnc.yaml; fi

if [ "$(echo ${SELKIES_ENABLE_RESIZE} | tr '[:upper:]' '[:lower:]')" = "true" ]; then export KASM_RESIZE_FLAG="-r"; fi

(echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}"; echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}";) | kasmvncpasswd -u "${SELKIES_BASIC_AUTH_USER:-${USER}}" -ow
if [ "$(echo ${SELKIES_ENABLE_BASIC_AUTH} | tr '[:upper:]' '[:lower:]')" = "false" ]; then export NO_KASM_AUTH_FLAG="-disableBasicAuth"; fi
if [ -n "${KASMVNC_VIEWPASS}" ]; then (echo "${KASMVNC_VIEWPASS}"; echo "${KASMVNC_VIEWPASS}";) | kasmvncpasswd -u "view"; fi

# Run KasmVNC
kasmvncserver "${KASM_DISPLAY}" -geometry "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}" -depth "${DISPLAY_CDEPTH}" -noxstartup -FrameRate "${DISPLAY_REFRESH}" -websocketPort 8081 -AlwaysShared -BlacklistTimeout 0 ${NO_KASM_AUTH_FLAG}

until [ -S "/tmp/.X11-unix/X${KASM_DISPLAY#*:}" ]; do sleep 0.5; done;

kasmxproxy -a "${DISPLAY}" -v "${KASM_DISPLAY}" -f "${DISPLAY_REFRESH}" ${KASM_RESIZE_FLAG} &
