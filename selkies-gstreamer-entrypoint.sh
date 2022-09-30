#!/bin/bash -e

# Source environment for GStreamer
source /opt/gstreamer/gst-env
# Add CUDA library path
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

# Default display is :0 across this setup
export DISPLAY=":0"
# Show debug logs for GStreamer
export GST_DEBUG="${GST_DEBUG:-*:2}"
# Set password for basic authentication
if [ "${ENABLE_BASIC_AUTH,,}" = "true" ] && [ -z "$BASIC_AUTH_PASSWORD" ]; then export BASIC_AUTH_PASSWORD="$PASSWD"; fi

# Wait for X11 to start
echo "Waiting for X socket"
until [ -S "/tmp/.X11-unix/X${DISPLAY/:/}" ]; do sleep 1; done
echo "X socket is ready"

# Write Progressive Web App (PWA) configuration
export PWA_APP_NAME="Selkies WebRTC"
export PWA_APP_SHORT_NAME="selkies"
export PWA_START_URL="/index.html"
sed -i \
    -e "s|PWA_APP_NAME|${PWA_APP_NAME}|g" \
    -e "s|PWA_APP_SHORT_NAME|${PWA_APP_SHORT_NAME}|g" \
    -e "s|PWA_START_URL|${PWA_START_URL}|g" \
/opt/gst-web/manifest.json && \
sed -i \
    -e "s|PWA_CACHE|${PWA_APP_SHORT_NAME}-webrtc-pwa|g" \
/opt/gst-web/sw.js

# Write default user configuration
export SELKIES_USER_CONFIG_FILE="${HOME}/.config/selkies/selkies-gstreamer-conf.json"
mkdir -p $(dirname "$SELKIES_USER_CONFIG_FILE")
if [ ! -f "${SELKIES_USER_CONFIG_FILE}" ]; then
    cat - > "${SELKIES_USER_CONFIG_FILE}" <<EOF
{
    "framerate": "${WEBRTC_FRAMERATE:-60}",
    "video_bitrate": "${WEBRTC_VIDEO_BITRATE:-4000}",
    "audio_bitrate": "${WEBRTC_AUDIO_BITRATE:-64000}",
    "enable_audio": "${ENABLE_AUDIO:-true}",
    "enable_resize": "${WEBRTC_ENABLE_RESIZE:-true}",
    "encoder": "${WEBRTC_ENCODER:-nvh264enc}"
}
EOF
fi

# Clear the cache registry to force the CUDA elements to refresh
rm -f "${HOME}/.cache/gstreamer-1.0/registry.x86_64.bin"

# Start the selkies-gstreamer WebRTC HTML5 remote desktop application
selkies-gstreamer \
    --json_config="${SELKIES_USER_CONFIG_FILE}" \
    --addr="0.0.0.0" \
    --port="8080" \
    $@
