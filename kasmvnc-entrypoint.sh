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

# Configure KasmVNC
export KASM_DISPLAY=":50"
yq -i "
.command_line.prompt = false |
.desktop.resolution.width = ${DISPLAY_SIZEW} |
.desktop.resolution.height = ${DISPLAY_SIZEH} |
.desktop.allow_resize = $(echo ${SELKIES_ENABLE_RESIZE-false} | tr '[:upper:]' '[:lower:]') |
.desktop.pixel_depth = ${DISPLAY_CDEPTH} |
.network.interface = \"127.0.0.1\" |
.network.websocket_port = 8082 |
.network.ssl.require_ssl = $(echo ${SELKIES_ENABLE_HTTPS-false} | tr '[:upper:]' '[:lower:]') |
.encoding.max_frame_rate = ${DISPLAY_REFRESH}
" /etc/kasmvnc/kasmvnc.yaml

if [ -n "${SELKIES_HTTPS_CERT}" ]; then yq -i ".network.ssl.pem_certificate = \"${SELKIES_HTTPS_CERT-/etc/ssl/certs/ssl-cert-snakeoil.pem}\"" /etc/kasmvnc/kasmvnc.yaml; fi
if [ -n "${SELKIES_HTTPS_KEY}" ]; then yq -i ".network.ssl.pem_key = \"${SELKIES_HTTPS_KEY-/etc/ssl/private/ssl-cert-snakeoil.key}\"" /etc/kasmvnc/kasmvnc.yaml; fi

if [ "$(echo ${SELKIES_ENABLE_RESIZE} | tr '[:upper:]' '[:lower:]')" = "true" ]; then export KASM_PROXY_FLAG="${KASM_PROXY_FLAG} -r"; fi
if [ "$(echo ${KASMVNC_VIEWONLY} | tr '[:upper:]' '[:lower:]')" = "true" ]; then export KASM_FLAG="${KASM_FLAG} -AcceptPointerEvents=0 -AcceptKeyEvents=0 -AcceptSetDesktopSize=0"; fi

mkdir -pm700 ~/.vnc
(echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}"; echo "${SELKIES_BASIC_AUTH_PASSWORD:-${PASSWD}}";) | kasmvncpasswd -u "${SELKIES_BASIC_AUTH_USER:-${USER}}" -ow ~/.kasmpasswd
touch ~/.vnc/.de-was-selected

# Wait for X server to start
echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'

# Run KasmVNC
if ls ~/.vnc/*\:"${KASM_DISPLAY#*:}".pid >/dev/null 2>&1; then kasmvncserver -kill "${KASM_DISPLAY}"; fi
kasmvncserver "${KASM_DISPLAY}" -geometry "${DISPLAY_SIZEW}x${DISPLAY_SIZEH}" -depth "${DISPLAY_CDEPTH}" -noxstartup -FrameRate "${DISPLAY_REFRESH}" -interface 127.0.0.1 -rfbport 9082 -websocketPort 8082 -disableBasicAuth -AlwaysShared -BlacklistTimeout 0 ${KASM_FLAG}

until [ -S "/tmp/.X11-unix/X${KASM_DISPLAY#*:}" ]; do sleep 0.5; done;

kasmxproxy -a "${DISPLAY}" -v "${KASM_DISPLAY}" -f "${DISPLAY_REFRESH}" ${KASM_PROXY_FLAG}
