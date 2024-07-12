#!/bin/ash
#
# shellcheck shell=dash
#
export SW_VERSION=0.1.0

### LOAD LIBRARIES (FUNCTIONS & ENVIRONMENT ) #################################
echo "[$(date +%H:%M:%S)] loading libproduct.sh"
. /app/libproduct.sh
log_debug "Loading environment & functions..."
for fSource in discovery.sh \
  listen_to_mqtt.sh \
  mqtt.sh \
  subroutines.sh \
  tesla.sh; do

  if [ -f /app/$fSource ]; then
    log_debug "Loading /app/$fSource"
    # shellcheck source=/dev/null
    . /app/$fSource
  else
    echo "Fatal error; file not found $fSource"
    exit 10
  fi
done
### END Source all required files

# If empty string, initialize w/ default value - Required for add-on and Docker standalone
export BLE_CMD_RETRY_DELAY=${BLE_CMD_RETRY_DELAY:-5}
export BLECTL_FILE_INPUT=${BLECTL_FILE_INPUT:-}
export ENABLE_HA_FEATURES=${ENABLE_HA_FEATURES:-true}
export PRESENCE_DETECTION_LOOP_DELAY=${PRESENCE_DETECTION_LOOP_DELAY:-120}
export PRESENCE_DETECTION_TTL=${PRESENCE_DETECTION_TTL:-240}

export BLE_LN_REGEX='S[0-9A-Fa-f]{16}C'
export MAC_REGEX='([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'
export VIN_REGEX='[A-HJ-NPR-Z0-9]{17}'

### LOG CONFIG VARS ###########################################################
log_info "Configuration Options are:
  BLE_CMD_RETRY_DELAY=$BLE_CMD_RETRY_DELAY
  BLE_MAC_LIST=$BLE_MAC_LIST
  DEBUG=$DEBUG
  MQTT_SERVER=$MQTT_SERVER
  MQTT_PORT=$MQTT_PORT
  MQTT_PASSWORD=Not Shown
  MQTT_USERNAME=$MQTT_USERNAME
  PRESENCE_DETECTION_LOOP_DELAY=$PRESENCE_DETECTION_LOOP_DELAY
  PRESENCE_DETECTION_TTL=$PRESENCE_DETECTION_TTL
  VIN_LIST=$VIN_LIST"

[ -n "$ENABLE_HA_FEATURES" ] && log_info "  ENABLE_HA_FEATURES=$ENABLE_HA_FEATURES"
[ -n "$BLECTL_FILE_INPUT" ] && log_info "  BLECTL_FILE_INPUT=$BLECTL_FILE_INPUT"

### SETUP DIRECTORY ###########################################################
if [ ! -d /share/tesla_ble_mqtt ]; then
  log_info "Creating directory /share/tesla_ble_mqtt"
  mkdir -p /share/tesla_ble_mqtt
else
  log_debug "/share/tesla_ble_mqtt already exists"
fi
