#!/usr/bin/env python3
"""
Zotac Zone Dial Driver for Linux
--------------------------------
Version: 1.3.0
Author: Pfahli

Changes:
- Added Direct Backlight Control to bypass Gamescope limitations.
- Fixed config menu visibility in installer.
"""

import os
import sys
import glob
import time
import select
import json
from evdev import UInput, ecodes as e

# --- METADATA ---
__version__ = "1.3.0"

# --- CONSTANTS ---
DIAL_REPORT_ID = 0x03
TARGET_VID_PART = "1EE9"
TARGET_PID_PART = "1590"

# --- ACTION DEFINITIONS ---
ACTIONS = {
    "volume": {
        "type": "key",
        "up": e.KEY_VOLUMEUP,
        "down": e.KEY_VOLUMEDOWN
    },
    "brightness": {
        "type": "backlight", # Special type for direct hardware control
        "step": 5            # Percentage to change per click
    },
    "scroll": {
        "type": "rel",
        "axis": e.REL_WHEEL,
        "up": 1,
        "down": -1
    },
    "scroll_inverted": {
        "type": "rel",
        "axis": e.REL_WHEEL,
        "up": -1,
        "down": 1
    },
    "arrows_vertical": {
        "type": "key",
        "up": e.KEY_UP,
        "down": e.KEY_DOWN
    },
    "arrows_horizontal": {
        "type": "key",
        "up": e.KEY_RIGHT,
        "down": e.KEY_LEFT
    },
    "media": {
        "type": "key",
        "up": e.KEY_NEXTSONG,
        "down": e.KEY_PREVIOUSSONG
    },
    "page_scroll": {
        "type": "key",
        "up": e.KEY_PAGEUP,
        "down": e.KEY_PAGEDOWN
    },
    "zoom": {
        "type": "key",
        "up": e.KEY_ZOOMIN,
        "down": e.KEY_ZOOMOUT
    }
}

DEFAULT_CONFIG = {
    "left_dial": "volume",
    "right_dial": "brightness"
}

# --- BACKLIGHT HELPERS ---
def find_backlight_path():
    """Finds the system backlight directory (usually amdgpu_bl0)."""
    # Look for common backlight controllers
    paths = glob.glob("/sys/class/backlight/*")
    if not paths:
        return None
    # Prefer amdgpu_bl0 if available (common on handhelds)
    for p in paths:
        if "amdgpu" in p:
            return p
    return paths[0]

def change_hardware_brightness(directory, direction, step_percent):
    """Reads current brightness and writes new value."""
    try:
        max_path = os.path.join(directory, "max_brightness")
        curr_path = os.path.join(directory, "brightness")

        with open(max_path, "r") as f:
            max_val = int(f.read().strip())

        with open(curr_path, "r") as f:
            curr_val = int(f.read().strip())

        # Calculate step size based on percentage
        step_val = int(max_val * (step_percent / 100.0))
        if step_val < 1: step_val = 1

        new_val = curr_val
        if direction == "up":
            new_val += step_val
        else:
            new_val -= step_val

        # Clamp values
        if new_val > max_val: new_val = max_val
        if new_val < 0: new_val = 0

        # Write result
        with open(curr_path, "w") as f:
            f.write(str(new_val))

    except Exception as e:
        print(f"Error changing backlight: {e}")

# --- SETUP HELPERS ---
def load_config():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, "config.json")
    config = DEFAULT_CONFIG.copy()
    if os.path.exists(config_path):
        try:
            with open(config_path, "r") as f:
                user_config = json.load(f)
                if "left_dial" in user_config: config["left_dial"] = user_config["left_dial"]
                if "right_dial" in user_config: config["right_dial"] = user_config["right_dial"]
        except: pass
    return config

def find_zotac_device():
    paths = sorted(glob.glob("/sys/class/hidraw/hidraw*"))
    for path in paths:
        try:
            uevent_path = os.path.join(path, "device/uevent")
            if not os.path.exists(uevent_path): continue
            with open(uevent_path, "r") as f:
                content = f.read().upper()
                if TARGET_VID_PART in content and TARGET_PID_PART in content:
                    return f"/dev/{os.path.basename(path)}"
        except: continue
    return None

# --- MAIN ---
def main():
    print(f"--- Zotac Zone Dial Driver v{__version__} ---")

    # 1. Setup Config & Hardware
    config = load_config()
    backlight_path = find_backlight_path()

    if backlight_path:
        print(f"Backlight controller found: {backlight_path}")
    else:
        print("Warning: No backlight controller found. Direct brightness control will fail.")

    left_action = ACTIONS.get(config.get("left_dial", "volume"), ACTIONS["volume"])
    right_action = ACTIONS.get(config.get("right_dial", "brightness"), ACTIONS["brightness"])

    dev_path = find_zotac_device()
    if not dev_path:
        print("Error: Zotac device not found.")
        sys.exit(1)
    print(f"Input device: {dev_path}")

    # 2. Create Virtual Device (UInput)
    needed_keys = []
    needed_rels = []

    for act in [left_action, right_action]:
        if act["type"] == "key":
            needed_keys.extend([act["up"], act["down"]])
        elif act["type"] == "rel":
            needed_rels.append(act["axis"])
        # "backlight" type needs no UInput keys

    try:
        capabilities = {e.EV_KEY: needed_keys, e.EV_REL: needed_rels}
        ui = UInput(events=capabilities, name="Zotac-Zone-Dials")
    except Exception as err:
        print(f"UInput Error: {err}. (Did you run with sudo?)")
        sys.exit(1)

    # 3. Main Loop
    try:
        f = open(dev_path, "rb", buffering=0)
        fd = f.fileno()
        poller = select.poll()
        poller.register(fd, select.POLLIN)

        print("Driver running...")

        while True:
            if poller.poll(1000):
                try:
                    data = f.read(64)
                except: continue

                if data and len(data) >= 4:
                    if data[0] != DIAL_REPORT_ID: continue

                    trigger = data[3]
                    if trigger == 0x00: continue

                    target = None
                    direction = None

                    if trigger == 0x10: target, direction = left_action, "down"
                    elif trigger == 0x08: target, direction = left_action, "up"
                    elif trigger == 0x02: target, direction = right_action, "down"
                    elif trigger == 0x01: target, direction = right_action, "up"

                    if target and direction:
                        # Handle Key Press
                        if target["type"] == "key":
                            k = target[direction]
                            ui.write(e.EV_KEY, k, 1)
                            ui.write(e.EV_KEY, k, 0)
                            ui.syn()

                        # Handle Mouse Scroll
                        elif target["type"] == "rel":
                            ui.write(e.EV_REL, target["axis"], target[direction])
                            ui.syn()

                        # Handle Direct Backlight (Bypassing Gamescope)
                        elif target["type"] == "backlight":
                            if backlight_path:
                                change_hardware_brightness(backlight_path, direction, target["step"])

    except KeyboardInterrupt: pass
    finally:
        ui.close()
        try: f.close()
        except: pass

if __name__ == "__main__":
    main()
