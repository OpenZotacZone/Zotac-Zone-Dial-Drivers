#!/bin/bash

# Zotac Zone Dial Driver Uninstaller
# Author: Pfahli

# --- Configuration ---
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="zone_dial_drivers.py"
CONFIG_NAME="config.json"
SERVICE_NAME="zotac-dials.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo ./uninstall.sh)${NC}"
  exit 1
fi

echo -e "${YELLOW}--- Uninstalling Zotac Zone Dial Driver ---${NC}"

# 1. Stop Service
if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    echo "Stopping and disabling service..."
    systemctl stop "$SERVICE_NAME"
    systemctl disable "$SERVICE_NAME"
    rm -f "$SERVICE_PATH"
    systemctl daemon-reload
else
    echo "Service not found or already removed."
fi

# 2. Remove Files
echo "Removing files..."
rm -f "$INSTALL_DIR/$SCRIPT_NAME"
rm -f "$INSTALL_DIR/$CONFIG_NAME"
rm -rf "$INSTALL_DIR/__pycache__"

echo -e "${GREEN}Uninstallation complete. Cleaned up.${NC}"
