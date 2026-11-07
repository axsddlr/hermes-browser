#!/bin/sh
set -eu

if [ -z "${VNC_PASSWORD:-}" ]; then
    echo "entrypoint: VNC_PASSWORD must be set (see .env.example)" >&2
    exit 1
fi

mkdir -p /tmp/vnc
x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vnc/passwd >/dev/null 2>&1
chmod 600 /tmp/vnc/passwd

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
