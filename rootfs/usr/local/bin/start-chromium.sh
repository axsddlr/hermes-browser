#!/bin/sh
set -eu

PROFILE_DIR=/data/profile

# Wait for the X server to come up
i=0
while [ ! -S /tmp/.X11-unix/X99 ]; do
    i=$((i + 1))
    [ "$i" -gt 50 ] && { echo "start-chromium: X display :99 never appeared" >&2; exit 1; }
    sleep 0.2
done

# A container stop leaves Singleton* locks behind (hostname changes per container),
# which makes Chromium refuse to open the persisted profile.
rm -f "$PROFILE_DIR"/SingletonLock "$PROFILE_DIR"/SingletonSocket "$PROFILE_DIR"/SingletonCookie

# After a crash Chromium shows a "Restore pages?" bubble that sits on top of forms.
# Mark the last exit as clean; RestoreOnStartup policy still reopens the tabs.
PREFS="$PROFILE_DIR/Default/Preferences"
[ -f "$PREFS" ] && sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREFS"

# Chromium's namespace sandbox needs syscalls Docker's default seccomp profile blocks,
# so it is off by default; the container is the isolation boundary.
# Set CHROME_SANDBOX=true if you run with a seccomp profile that allows it.
SANDBOX_FLAG="--no-sandbox"
[ "${CHROME_SANDBOX:-false}" = "true" ] && SANDBOX_FLAG=""

# On stop, quit Chromium via CDP so it flushes cookies/session to disk;
# fall back to SIGTERM if that fails.
graceful_stop() {
    trap - TERM INT
    /usr/local/bin/chrome-close.py || kill -TERM "$CHROME_PID" 2>/dev/null
    wait "$CHROME_PID"
    exit 0
}
trap graceful_stop TERM INT

# Chromium only binds CDP to 127.0.0.1; socat re-exposes it on 0.0.0.0:9222.
# shellcheck disable=SC2086
chromium \
    $SANDBOX_FLAG \
    --remote-debugging-port=9223 \
    --user-data-dir="$PROFILE_DIR" \
    --no-first-run \
    --no-default-browser-check \
    --disable-dev-shm-usage \
    --disable-features=Translate \
    --password-store=basic \
    --log-level=3 \
    --window-position=0,0 \
    --window-size="${SCREEN_WIDTH},${SCREEN_HEIGHT}" \
    --start-maximized \
    ${CHROME_EXTRA_FLAGS:-} \
    about:blank &
CHROME_PID=$!

# Returns early when a trapped signal arrives; otherwise mirrors Chromium's exit
wait "$CHROME_PID"
