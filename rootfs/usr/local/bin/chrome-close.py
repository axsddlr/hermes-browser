#!/usr/bin/env python3
"""Ask Chromium to quit like a user would (CDP Browser.close).

A SIGTERM'd Chromium exits without flushing its cookie store, which loses any
cookie set in the last ~30s (e.g. a login done just before a restart).
Browser.close goes through the normal quit path, which flushes everything.
"""
import json
import sys
import urllib.request

import websocket  # python3-websocket

try:
    with urllib.request.urlopen("http://127.0.0.1:9223/json/version", timeout=3) as r:
        ws_url = json.load(r)["webSocketDebuggerUrl"]
    ws = websocket.create_connection(ws_url, timeout=5)
    ws.send(json.dumps({"id": 1, "method": "Browser.close"}))
    ws.close()
except Exception as e:  # caller falls back to SIGTERM
    print(f"chrome-close: {e}", file=sys.stderr)
    sys.exit(1)
