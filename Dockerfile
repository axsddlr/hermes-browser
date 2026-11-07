FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    SCREEN_WIDTH=1920 \
    SCREEN_HEIGHT=1080 \
    SCREEN_DEPTH=24 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        chromium \
        xvfb fluxbox hsetroot x11vnc \
        novnc python3-websockify python3-websocket \
        socat supervisor curl ca-certificates tini locales \
        fonts-liberation fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji \
    && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# Non-root user that runs everything; X socket dir must exist and be world-writable
RUN useradd --create-home --shell /bin/bash --uid 1000 browser \
    && mkdir -p /data/profile /data/downloads /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix \
    && chown -R browser:browser /data \
    && ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

COPY --chmod=0755 rootfs/usr/local/bin/ /usr/local/bin/
COPY rootfs/etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY rootfs/etc/chromium/policies/managed/ /etc/chromium/policies/managed/
COPY --chown=browser:browser rootfs/home/browser/ /home/browser/

USER browser
WORKDIR /home/browser
VOLUME ["/data"]

# 9222 = CDP (proxied), 6080 = noVNC
EXPOSE 9222 6080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1:9222/json/version >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
