#!/bin/bash

# Zotac Zone Dial Driver Installer / Configurator
# Author: Pfahli
# Version: 1.3.2 (Added Arch Linux Support)

# --- Configuration ---
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="zone_dial_drivers.py"
CONFIG_NAME="config.json"
SERVICE_NAME="zotac-dials.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
CONFIG_PATH="$INSTALL_DIR/$CONFIG_NAME"

# GitHub Settings
GITHUB_REPO_URL="https://github.com/OpenZotacZone/Zotac-Zone-Dial-Drivers"
GITHUB_RAW_URL="https://raw.githubusercontent.com/OpenZotacZone/Zotac-Zone-Dial-Drivers/main/zone_dial_drivers.py"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helper Functions ---

get_function_choice() {
    local prompt="$1"
    local default_val="$2"
    local choice_name=""
    
    # Send menu to stderr so it shows up on screen
    {
        echo -e "${CYAN}$prompt${NC}"
        echo "  1) volume            (Volume +/-)"
        echo "  2) brightness        (Brightness +/-)"
        echo "  3) scroll            (Mouse Wheel)"
        echo "  4) scroll_inverted   (Mouse Wheel Inverted)"
        echo "  5) arrows_vertical   (Arrow Up/Down)"
        echo "  6) arrows_horizontal (Arrow Left/Right)"
        echo "  7) media             (Next/Prev Song)"
        echo "  8) page_scroll       (PageUp/PageDown)"
        echo "  9) zoom              (Browser Zoom)"
    } >&2
    
    read -p "Select a number [Default: $default_val]: " selection

    case $selection in
        1) choice_name="volume" ;;
        2) choice_name="brightness" ;;
        3) choice_name="scroll" ;;
        4) choice_name="scroll_inverted" ;;
        5) choice_name="arrows_vertical" ;;
        6) choice_name="arrows_horizontal" ;;
        7) choice_name="media" ;;
        8) choice_name="page_scroll" ;;
        9) choice_name="zoom" ;;
        *) choice_name="$default_val" ;;
    esac
    
    echo "$choice_name"
}

create_config_interactive() {
    echo -e "\n${YELLOW}--- Dial Configuration ---${NC}"
    local def_left="volume"
    local def_right="brightness"
    
    local left_val=$(get_function_choice "Function for the LEFT Dial:" "$def_left")
    echo -e "-> Left set to: ${GREEN}$left_val${NC}\n"
    
    local right_val=$(get_function_choice "Function for the RIGHT Dial:" "$def_right")
    echo -e "-> Right set to: ${GREEN}$right_val${NC}\n"

    cat <<EOF > "$CONFIG_PATH"
{
    "left_dial": "$left_val",
    "right_dial": "$right_val"
}
EOF
    chmod 644 "$CONFIG_PATH"
    echo -e "${GREEN}Configuration saved to $CONFIG_PATH${NC}"
}

download_latest() {
    echo -e "\n${CYAN}Check for updates?${NC}"
    echo "This will download the latest '$SCRIPT_NAME' from:"
    echo "$GITHUB_REPO_URL"
    
    read -p "Download latest version now? [y/N]: " dl_choice
    if [[ "$dl_choice" =~ ^[Yy]$ ]]; then
        echo "Downloading..."
        if command -v curl &> /dev/null; then
            if curl -L -o "$SCRIPT_NAME" "$GITHUB_RAW_URL"; then
                echo -e "${GREEN}Download successful.${NC}"
            else
                echo -e "${RED}Download failed. Please check your internet connection.${NC}"
            fi
        elif command -v wget &> /dev/null; then
             if wget -O "$SCRIPT_NAME" "$GITHUB_RAW_URL"; then
                echo -e "${GREEN}Download successful.${NC}"
            else
                echo -e "${RED}Download failed.${NC}"
            fi
        else
            echo -e "${RED}Error: Neither 'curl' nor 'wget' found. Cannot download.${NC}"
        fi
    else
        echo "Skipping download. Using local file."
    fi
}

# --- Main Script ---

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo ./install_zone_dial_drivers.sh)${NC}"
  exit 1
fi

# Check if already installed
IS_INSTALLED=false
if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    IS_INSTALLED=true
fi

if [ "$IS_INSTALLED" = true ]; then
    echo -e "${YELLOW}The driver is already installed.${NC}"
    echo "What would you like to do?"
    echo "  1) Only change the dial configuration"
    echo "  2) Update driver (Download/Reinstall) & Configure"
    read -p "Selection [1]: " update_choice
    
    if [ "$update_choice" != "2" ]; then
        create_config_interactive
        echo "Restarting service..."
        systemctl restart "$SERVICE_NAME"
        echo -e "${GREEN}Done! Dials have been reconfigured.${NC}"
        exit 0
    fi
fi

echo -e "${YELLOW}--- Installing Zotac Zone Dial Driver ---${NC}"

# 1. Option to Download Latest
download_latest

# 2. Source File Check
if [ ! -f "$SCRIPT_NAME" ]; then
    echo -e "${RED}Error: File '$SCRIPT_NAME' not found.${NC}"
    echo "The file is missing locally and was not downloaded."
    exit 1
fi

# 3. Dependencies
echo "Checking dependencies..."
if ! python3 -c "import evdev" &> /dev/null; then
    echo -e "${YELLOW}'evdev' module missing.${NC}"
    
    # Check if we are on Arch Linux (or derivatives like CachyOS/Endeavour)
    if command -v pacman &> /dev/null; then
        echo -e "${CYAN}Arch Linux detected. Installing 'python-evdev' via pacman...${NC}"
        # --noconfirm allows script to run without user input during install
        # --needed prevents reinstalling if it's already there (safety check)
        if pacman -S --noconfirm --needed python-evdev; then
             echo -e "${GREEN}Successfully installed python-evdev via pacman.${NC}"
        else
             echo -e "${RED}Pacman install failed. Attempting fallback to pip...${NC}"
             pip install evdev --break-system-packages || pip install evdev
        fi
    else
        # Fedora / Bazzite / Ubuntu / Others
        echo -e "${YELLOW}Installing via pip...${NC}"
        pip install evdev --break-system-packages || pip install evdev
    fi
fi

# 4. Copy Script
echo "Copying script to $INSTALL_DIR..."
cp "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# 5. Create Config (Interactive)
create_config_interactive

# 6. Create Service
echo "Creating Systemd Service..."
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Zotac Zone Dials Driver by Pfahli
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $INSTALL_DIR/$SCRIPT_NAME
Restart=always
RestartSec=5
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

# 7. Enable & Start
echo "Enabling service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# 8. Final Check
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}Installation successful! The dials are active.${NC}"
else
    echo -e "${RED}Service failed to start. Check logs with: sudo journalctl -u $SERVICE_NAME -f${NC}"
fi
