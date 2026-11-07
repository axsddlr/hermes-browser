# hermes-browser

A headful Chromium in Docker for [Hermes Agent](https://hermes-agent.nousresearch.com/) to drive over CDP. You can watch it, or take over for CAPTCHAs and logins, through noVNC in your own browser. The profile persists, so you log into sites once.

| Port | What | Auth |
|------|------|------|
| 9222 | Chrome DevTools Protocol (CDP) | **none**: firewall it |
| 6080 | noVNC viewer (`/vnc.html`) | `VNC_PASSWORD` |

## Run

```sh
cp .env.example .env      # set VNC_PASSWORD and BIND_IP (the Docker host's LAN IP)
docker compose up -d --build
curl http://<BIND_IP>:9222/json/version   # should print Chrome version JSON
```

To watch the browser, open `http://<BIND_IP>:6080/vnc.html` and enter `VNC_PASSWORD`.

## Point Hermes at it (in the LXC)

`~/.hermes/config.yaml`:

```yaml
browser:
  cdp_url: http://<docker-host-ip>:9222
```

Or for one session: `/browser connect http://<docker-host-ip>:9222`. The env var `BROWSER_CDP_URL` also works.

**Use an IP address, not a hostname.** Chrome's DevTools server rejects requests whose `Host` header isn't an IP or `localhost`, and answers them with HTTP 500.

To check from the LXC without Hermes:

```sh
pip install playwright
python scripts/smoke_test.py http://<docker-host-ip>:9222   # fills + submits httpbin.org/forms/post
```

## How it works

supervisord runs: Xvfb `:99` → fluxbox → Chromium (`/data/profile`) → socat (`0.0.0.0:9222` → Chromium's localhost-only `127.0.0.1:9223`) → x11vnc → noVNC.

- **Persistence:** the `profile` volume holds `/data/profile` (cookies, logins) and `/data/downloads`. Chromium is stopped with CDP `Browser.close` rather than SIGTERM. A SIGTERM'd Chromium doesn't flush its cookie store, so a login done in the last ~30s would be lost on restart. A managed policy (`RestoreOnStartup`) keeps session cookies too.
- **Crash recovery:** if Chromium dies or someone closes its window, supervisord restarts it.
- **Sandbox:** Chromium runs as non-root with `--no-sandbox`, because Docker's default seccomp profile blocks its namespace sandbox. The container is the isolation boundary. Set `CHROME_SANDBOX=true` if you supply a seccomp profile that allows it.

## Security

Anyone who can reach 9222 fully controls a browser that is logged into your accounts.

- Set `BIND_IP` to a private LAN IP. Never port-forward 9222 or 6080 to the internet.
- On Proxmox/host firewall: allow 9222 **only** from the Hermes LXC's IP, and 6080 only from your LAN.
- The `profile` volume contains live session cookies. Treat backups of it as secrets.

## Ops

```sh
docker compose logs -f                      # supervisord + chromium output
docker compose restart                      # cookies/session survive
docker exec hermes-browser supervisorctl status
docker volume rm hermes-browser_profile     # wipe profile (after `docker compose down`)
```
