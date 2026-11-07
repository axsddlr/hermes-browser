"""Drive the container over CDP the way Hermes will: open a form, fill it, submit, check the echo.

Usage (from the Hermes LXC or anywhere that can reach the CDP port):
    pip install playwright        # no browser download needed, we connect to the remote one
    python scripts/smoke_test.py http://<docker-host-ip>:9222
"""
import json
import sys

from playwright.sync_api import sync_playwright

cdp_url = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:9222"

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp(cdp_url)
    context = browser.contexts[0]  # the persistent profile's context
    page = context.new_page()
    try:
        page.goto("https://httpbin.org/forms/post", wait_until="domcontentloaded")
        page.fill("input[name=custname]", "Hermes Smoke Test")
        page.fill("input[name=custtel]", "555-0100")
        page.fill("input[name=custemail]", "hermes@example.com")
        page.check("input[name=size][value=medium]")
        page.check("input[name=topping][value=cheese]")
        page.fill("textarea[name=comments]", "submitted over CDP")
        page.click("button")
        page.wait_for_load_state("domcontentloaded")
        form = json.loads(page.inner_text("pre"))["form"]
        assert form["custname"] == "Hermes Smoke Test", form
        assert form["size"] == "medium", form
        print("OK: form submitted over CDP ->", form)
    finally:
        page.close()
        browser.close()  # disconnects only; the remote browser keeps running
