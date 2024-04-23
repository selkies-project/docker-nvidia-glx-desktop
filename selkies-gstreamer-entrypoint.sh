#!/bin/bash -e

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Source environment for GStreamer
. /opt/gstreamer/gst-env

# Set default display
export DISPLAY="${DISPLAY:-:0}"

# Configure joystick interposer
sudo mkdir -pm755 /dev/input || true
sudo touch /dev/input/js0 /dev/input/js1 /dev/input/js2 /dev/input/js3 || true

# Show debug logs for GStreamer
export GST_DEBUG="${GST_DEBUG:-*:2}"
# Set password for basic authentication
if [ "${ENABLE_BASIC_AUTH,,}" = "true" ] && [ -z "${BASIC_AUTH_PASSWORD}" ]; then export BASIC_AUTH_PASSWORD="${PASSWD}"; fi

# Wait for X11 to start
echo "Waiting for X socket"
until [ -S "/tmp/.X11-unix/X${DISPLAY/:/}" ]; do sleep 1; done
echo "X socket is ready"

# Clear the cache registry
rm -rf "${HOME}/.cache/gstreamer-1.0"

# Start the selkies-gstreamer WebRTC HTML5 remote desktop application
selkies-gstreamer \
    --addr="0.0.0.0" \
    --port="8080" \
    $@
