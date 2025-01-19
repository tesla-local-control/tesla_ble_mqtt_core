#!/bin/ash
#
# shellcheck shell=dash
#

### LOAD LIBRARIES (FUNCTIONS & ENVIRONMENT ) #################################
echo "[$(date +%H:%M:%S)] loading libproduct.sh"
. /app/libproduct.sh
log_debug "Loading environment & functions..."
for fSource in mqtt.sh \
  mqtt-discovery.sh \
  mqtt-discovery-sensors.sh \
  mqtt-listen.sh \
  subroutines.sh \
  tesla-commands.sh \
  read-state.sh \
  version.sh; do

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
export TC_CMD_TIMEOUT=${TC_CMD_TIMEOUT:-5}
export TC_CON_TIMEOUT=${TC_CON_TIMEOUT:-10}
export TC_KILL_TIMEOUT=${TC_KILL_TIMEOUT:-25}
export PS_LOOP_DELAY=${PS_LOOP_DELAY:-30}
export BLECTL_FILE_INPUT=${BLECTL_FILE_INPUT:-}
export ENABLE_HA_FEATURES=${ENABLE_HA_FEATURES:-true}
export PRESENCE_DETECTION_LOOP_DELAY=${PRESENCE_DETECTION_LOOP_DELAY:-120}
export PRESENCE_DETECTION_TTL=${PRESENCE_DETECTION_TTL:-240}
export TEMPERATURE_UNIT_FAHRENHEIT=${TEMPERATURE_UNIT_FAHRENHEIT:-false}
export MAX_CURRENT=${MAX_CURRENT:-48}
export NO_POLL_SECTIONS=${NO_POLL_SECTIONS:-}
export HCINUM=${BLE_HCI_NUM:-0}

export BLE_LN_REGEX='S[0-9A-Fa-f]{16}C'
export BLTCTL_COMMAND_DEVICES=false
export KEYS_DIR=/share/tesla_ble_mqtt
export MAC_REGEX='([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})'
export VIN_REGEX='[A-HJ-NPR-Z0-9]{17}'

### LOG CONFIG VARS ###########################################################
log_info "Configuration Options are:
  TC_CMD_TIMEOUT=$TC_CMD_TIMEOUT
  TC_CON_TIMEOUT=$TC_CON_TIMEOUT
  TC_KILL_TIMEOUT=$TC_KILL_TIMEOUT
  PS_LOOP_DELAY=$PS_LOOP_DELAY
  DEBUG=$DEBUG
  MQTT_SERVER=$MQTT_SERVER
  MQTT_PORT=$MQTT_PORT
  MQTT_PASSWORD=Not Shown
  MQTT_USERNAME=$MQTT_USERNAME
  PRESENCE_DETECTION_LOOP_DELAY=$PRESENCE_DETECTION_LOOP_DELAY
  PRESENCE_DETECTION_TTL=$PRESENCE_DETECTION_TTL
  TEMPERATURE_UNIT_FAHRENHEIT=$TEMPERATURE_UNIT_FAHRENHEIT
  VIN_LIST=$VIN_LIST
  MAX_CURRENT=$MAX_CURRENT
  NO_POLL_SECTIONS=$NO_POLL_SECTIONS
  BLE_HCI_NUM=$HCINUM"

[ -n "$ENABLE_HA_FEATURES" ] && log_info "  ENABLE_HA_FEATURES=$ENABLE_HA_FEATURES"
[ -n "$BLECTL_FILE_INPUT" ] && log_info "  BLECTL_FILE_INPUT=$BLECTL_FILE_INPUT"

### SETUP DIRECTORY ###########################################################
if [ ! -d $KEYS_DIR ]; then
  log_info "Creating directory $KEYS_DIR"
  mkdir -p $KEYS_DIR
else
  log_debug "$KEYS_DIR already exists"
fi
