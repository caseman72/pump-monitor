#!/bin/bash
# OTA upload script for the pump-monitor boards
# Parses secrets.h and injects values as ESPHome substitutions so no
# credentials live in the YAML.
#
# Usage: ./upload.sh <config.yaml> [device] [secrets]
#   config   pump-monitor.yaml | pump-controller.yaml | home-controller.yaml
#   device   defaults to DEVICE_IP_<CONFIG> from secrets.h, e.g.
#            DEVICE_IP_PUMP_CONTROLLER for pump-controller.yaml, else the
#            node name as a DNS host. (mDNS does not resolve on every
#            network; the router's DNS name is the ESPHome node name.)
#
# The config comes FIRST and picks its own board: with three boards on the
# bench, "./upload.sh <ip>" used to flash pump-monitor.yaml onto whatever
# board owned that IP. ESPHome OTA does not check node names, so the
# mapping in secrets.h is the only guard. An explicit device is still
# accepted as the 2nd arg for recovery (fallback hotspot 192.168.4.1).
#
# DRY_RUN=1 ./upload.sh <config> prints the resolved target and exits.
#
# NEVER flash a controller while a zone is running: the OTA reboot drops the
# zone relay mid-cycle and loses the cycle, its timers and the RTC stamp.
# Wait for the cycle to finish (see README "Building & uploading").
#
# Changing the OTA password: set the NEW value in OTA_PASSWORD and add
#   #define OTA_OLD_PASSWORD "<current device password>"
# The script compiles the new password into the firmware but authenticates
# the upload with the old one. Remove OTA_OLD_PASSWORD after one
# successful flash.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-}"
SECRETS="${3:-secrets.h}"

if [[ -z "$CONFIG" || ! "$CONFIG" =~ \.ya?ml$ ]]; then
    echo "Usage: ./upload.sh <config.yaml> [device] [secrets]"
    echo "  (the config comes first - it selects which board gets flashed)"
    exit 1
fi
if [[ ! -f "$SCRIPT_DIR/$CONFIG" ]]; then
    echo "Error: ${CONFIG} not found."
    exit 1
fi

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
# Per-config board address: pump-controller.yaml -> DEVICE_IP_PUMP_CONTROLLER
NODE="$(basename "$CONFIG" .yaml)"
IP_KEY="DEVICE_IP_$(echo "$NODE" | tr 'a-z-' 'A-Z_')"
DEVICE="${2:-$(parse_secret "$IP_KEY" || true)}"
if [[ -z "$DEVICE" ]]; then
    DEVICE="$NODE"
    echo "Note: ${IP_KEY} not set in ${SECRETS}; using DNS name '${DEVICE}'."
fi

echo "Target: ${CONFIG} -> ${DEVICE}"
if [[ -n "${DRY_RUN:-}" ]]; then
    exit 0
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
