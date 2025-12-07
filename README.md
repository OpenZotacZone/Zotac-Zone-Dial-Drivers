# Zotac Zone Dial Driver for Linux

The rotary dials (jog wheels) on the Zotac Zone have been pretty useless. On Linux they had no functionality at all and even on Windows they were limited to brightness, volume and RGB control. This driver allows you to finally make use of the dials.

Since there is no official Linux driver for these controls, this script reverse-engineers the HID protocol to map the dials to useful system functions like Volume, Brightness, or Mouse Scrolling.

**Works on:** Bazzite, Fedora. Other distributions have not been tested, so feel free to give us feedback.

## Features

* **Full Dial Support:** Enables both the Left and Right radial dials.
* **More functionality:** Simulate mouse scroll, arrow keys and much more to quickly swap weapons in your game
* **Gaming Mode Compatible:** Includes a **Direct Backlight Control** mode that bypasses Gamescope limitations, allowing brightness control to work in Steam Gaming Mode.
* **Configurable:** Choose functions via an interactive installer.
* **Auto-Start:** Installs as a systemd service to run automatically in the background.

## Available Functions

You can map the following functions to either the Left or Right dial:

* **Volume:** Increase/Decrease System Volume.
* **Brightness:** Increase/Decrease Screen Brightness (Hardware Level).
* **Scroll:** Emulate Mouse Wheel Scroll.
* **Scroll (Inverted):** Inverted Mouse Wheel.
* **Arrows:** Emulate Up/Down or Left/Right keyboard arrows.
* **Media:** Next/Previous Track.
* **Page Scroll:** Page Up/Page Down.
* **Zoom:** Browser Zoom (CTRL +/-).

## Installation

### Prerequisites
* A Zotac Zone Handheld running Bazzite Linux.
* Root privileges (`sudo`).

### Steps
1.  Download or place the following files in a folder:
    * `zone_dial_drivers.py`
    * `install_zone_dial_drivers.sh`
    * `uninstall_zone_dial_drivers.sh`

2.  Open a terminal in that folder and make the scripts executable:
    ```bash
    chmod +x install_zone_dial_drivers.sh uninstall_zone_dial_drivers.sh
    ```

3.  Run the installer:
    ```bash
    sudo ./install_zone_dial_drivers.sh
    ```

4.  Follow the on-screen menu to select which function you want for the Left and Right dials.

The driver will start immediately.

## Changing Configuration

To change the dial functions (e.g., swap Volume for Scrolling), simply **run the installer again**:

    sudo ./install_zone_dial_drivers.sh

Select **Option 1** ("Only change the dial configuration"). You do not need to reinstall the whole driver.

## Uninstallation

To remove the driver, stop the service, and clean up all files:

    sudo ./uninstall_zone_dial_drivers.sh

## Future plans

> We are planning to write a Decky plugin to configure the driver directly in Steam Gaming Mode

## Changelog

### v1.3.0
* **New Feature:** Added "Direct Backlight Control".
    * *Fixes an issue where brightness control would not work in SteamOS/Bazzite Gaming Mode (Gamescope).* The driver now writes directly to the hardware backlight controller instead of simulating keyboard keys.
* * **New Feature:** Installer Script now allows you to download the latest version from github.
* **Fix:** Improved installer menu visibility.

### v1.2.1
* **Fix:** Resolved a bug in the installer where the configuration menu text was hidden during input capture.

### v1.2.0
* **New Feature:** Interactive Installer Script.
    * Added a visual menu to select dial functions during install.
    * Added logic to update existing installations or just reconfigure `config.json`.
* **Refactor:** Renamed main script to `zone_dial_drivers.py`.

### v1.1.0
* **New Feature:** External `config.json` support.
* **New Feature:** Mouse Wheel emulation (`REL_WHEEL`) support.
* **New Options:** Added Media keys, Page Scroll, Zoom, and Inverted Scroll.

### v1.0.0
* **Initial Release:**
* Reverse-engineered Zotac HID protocol (Report ID `0x03`).
* Implemented Touchpad filtering (Ignoring Report ID `0x04`) to fix input collisions.
* Basic mapping for Volume and Brightness via `uinput`.

## Credits

**Author:** Pfahli

---
*Disclaimer: This software is provided "as is", without warranty of any kind. Use at your own risk.*

