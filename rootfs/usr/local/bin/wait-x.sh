#!/bin/sh
# Wait for Xvfb's :99 socket, then exec the given command (avoids startup races).
i=0
while [ ! -S /tmp/.X11-unix/X99 ]; do
    i=$((i + 1))
    [ "$i" -gt 50 ] && { echo "wait-x: X display :99 never appeared" >&2; exit 1; }
    sleep 0.2
done
exec "$@"
