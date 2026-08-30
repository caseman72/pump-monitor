// Copy this to secrets.h and fill in your values
// secrets.h is gitignored

#define WIFI_SSID "your-ssid"
#define WIFI_PASSWORD "your-wifi-password"
#define AP_PASSWORD "your-fallback-hotspot-password"

// OTA password
#define OTA_PASSWORD "your-ota-password"

// Optional, one-time OTA password rotation: uncomment and set to the
// password the device currently runs; upload.sh authenticates with it
// and bakes the new OTA_PASSWORD into the firmware. Remove after one
// successful flash.
// #define OTA_OLD_PASSWORD "current-device-ota-password"

// Home Assistant native API encryption key
// Generate with: openssl rand -base64 32
#define API_ENCRYPTION_KEY "your-base64-api-key"

// Board address per config for OTA (DHCP lease or router DNS name).
// upload.sh picks DEVICE_IP_<CONFIG> from the yaml name, so a config can
// only ever be flashed onto its own board. ./upload.sh <config> <ip> overrides.
#define DEVICE_IP_PUMP_MONITOR    "192.168.1.50"
#define DEVICE_IP_PUMP_CONTROLLER "192.168.1.51"
#define DEVICE_IP_HOME_CONTROLLER "192.168.1.52"
