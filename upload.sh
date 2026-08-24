#!/bin/bash
# OTA upload script for pump-monitor
# Parses secrets.h and injects values as ESPHome substitutions so no
# credentials live in the YAML.
#
# Usage: ./upload.sh [device] [config] [secrets]
#   device defaults to DEVICE_IP from secrets.h (mDNS does not resolve on
#   every network; the router's DNS name is the ESPHome node name)
#
# Changing the OTA password: set the NEW value in OTA_PASSWORD and add
#   #define OTA_OLD_PASSWORD "<current device password>"
# The script compiles the new password into the firmware but authenticates
# the upload with the old one. Remove OTA_OLD_PASSWORD after one
# successful flash.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${2:-pump-monitor.yaml}"
SECRETS="${3:-secrets.h}"

if [[ ! -f "$SCRIPT_DIR/$SECRETS" ]]; then
    echo "Error: ${SECRETS} not found. Copy secrets.example.h to ${SECRETS} and fill in values."
    exit 1
fi

# Parse secrets.h and extract value (no escaping needed - quotes protect from shell)
parse_secret() {
    grep "#define $1 " "$SCRIPT_DIR/$SECRETS" | sed 's/.*"\(.*\)"/\1/'
}

WIFI_SSID=$(parse_secret WIFI_SSID)
WIFI_PASSWORD=$(parse_secret WIFI_PASSWORD)
AP_PASSWORD=$(parse_secret AP_PASSWORD)
OTA_PASSWORD=$(parse_secret OTA_PASSWORD)
OTA_OLD_PASSWORD=$(parse_secret OTA_OLD_PASSWORD || true)
API_KEY=$(parse_secret API_ENCRYPTION_KEY)
DEVICE="${1:-$(parse_secret DEVICE_IP || true)}"

if [[ -z "$DEVICE" ]]; then
    echo "Error: no device given and DEVICE_IP not set in ${SECRETS}."
    echo "Usage: ./upload.sh <device-ip-or-host> [config] [secrets]"
    exit 1
fi

SUBS=(
    -s wifi_ssid "$WIFI_SSID"
    -s wifi_password "$WIFI_PASSWORD"
    -s ap_password "$AP_PASSWORD"
    -s api_key "$API_KEY"
)

cd "$SCRIPT_DIR"

if [[ -n "$OTA_OLD_PASSWORD" ]]; then
    # Password rotation: bake NEW into the firmware, authenticate with OLD.
    echo "OTA password rotation: compiling with new password..."
    esphome "${SUBS[@]}" -s ota_password "$OTA_PASSWORD" compile "$CONFIG"
    echo "Uploading to $DEVICE (authenticating with old password)..."
    esphome "${SUBS[@]}" -s ota_password "$OTA_OLD_PASSWORD" upload "$CONFIG" --device "$DEVICE"
    echo "Done. Remove OTA_OLD_PASSWORD from ${SECRETS} - the device now uses the new password."
else
    echo "Uploading to $DEVICE..."
    esphome "${SUBS[@]}" -s ota_password "$OTA_PASSWORD" run "$CONFIG" --no-logs --device "$DEVICE"
fi
