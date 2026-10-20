#!/usr/bin/env python3
"""Exercise the published APK without using or creating a real user account."""
from pathlib import Path
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

OUT = Path("nimzo/build/auth-runtime-evidence")
OUT.mkdir(parents=True, exist_ok=True)
REPORT = {}
APP = "io.nimzo.app"
ACTIVITY = APP + "/" + APP + ".MainActivity"

def adb(*args, timeout=40, binary=False):
    result = subprocess.run(["adb", *args], check=True, capture_output=True, timeout=timeout)
    return result.stdout if binary else result.stdout.decode("utf-8", "replace")

def capture(name):
    (OUT / (name + ".png")).write_bytes(adb("exec-out", "screencap", "-p", binary=True))
    (OUT / "logcat.txt").write_text(adb("logcat", "-d", "-v", "time"))

def nodes():
    adb("shell", "uiautomator", "dump", "--compressed", "/sdcard/nimzo_auth_window.xml")
    xml = adb("shell", "cat", "/sdcard/nimzo_auth_window.xml")
    (OUT / "window.xml").write_text(xml)
    return list(ET.fromstring(xml).iter("node"))

def label(node):
    return " ".join((node.get("text", ""), node.get("content-desc", ""))).strip()

def find(predicate, timeout=35):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for node in nodes():
            if predicate(node):
                return node
        time.sleep(1)
    raise AssertionError("Required Android UI element not found; inspect window.xml")

def tap(node):
    bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if not bounds:
        raise AssertionError("UI element has no valid bounds")
    x1, y1, x2, y2 = map(int, bounds.groups())
    adb("shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2))

def tap_label(text):
    tap(find(lambda node: label(node) == text))

def start_app():
    adb("shell", "am", "start", "-W", "-n", ACTIVITY)

def browser_opened(provider):
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        activity = adb("shell", "dumpsys", "activity", "activities")
        resumed = "\n".join(line for line in activity.splitlines()
                            if "mResumedActivity" in line or "topResumedActivity" in line)
        if resumed and APP not in resumed:
            if "ResolverActivity" in resumed:
                raise AssertionError("Emulator requires a default browser selection")
            REPORT[provider + "_browser_handoff"] = resumed.strip()
            capture(provider)
            print(provider + " external browser handoff: PASS")
            return
        time.sleep(1)
    raise AssertionError(provider + " did not open an external browser")

try:
    apk = sys.argv[1]
    adb("install", "-r", apk, timeout=180)
    adb("logcat", "-c")
    start_app()
    find(lambda node: label(node) == "Google", timeout=45)
    capture("login")
    REPORT["startup_login_screen"] = True

    # This deliberately invalid account never creates a user or a session.
    email = find(lambda node: node.get("class", "").endswith("EditText")
                 and node.get("password") != "true")
    tap(email)
    adb("shell", "input", "text", "nimzo-auth-probe@example.invalid")
    password = find(lambda node: node.get("password") == "true")
    tap(password)
    adb("shell", "input", "text", "invalid-diagnostic-only")
    adb("shell", "input", "keyevent", "4")
    tap(find(lambda node: node.get("checkable") == "true"))
    tap_label("Continue")
    find(lambda node: "Invalid login credentials" in label(node), timeout=30)
    REPORT["email_backend_rejection"] = True
    capture("email-rejection")
    print("Android email request reaches Supabase and shows its rejection: PASS")

    # No account is selected and no credentials are entered into either provider.
    for provider in ("Google", "Facebook"):
        start_app()
        tap_label(provider)
        browser_opened(provider.lower())
    REPORT["scope"] = "Startup, email rejection and external OAuth browser handoff only; real-account callback not tested."
    (OUT / "result.json").write_text(json.dumps(REPORT, indent=2))
except Exception as error:
    REPORT["failure_type"] = type(error).__name__
    REPORT["failure"] = str(error)
    (OUT / "result.json").write_text(json.dumps(REPORT, indent=2))
    try:
        capture("failure")
    except Exception:
        pass
    raise
