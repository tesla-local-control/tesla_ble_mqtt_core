#!/bin/ash
#
# shellcheck shell=dash
#
# Note: shebang will be replaced automatically by the HA addon deployment script to #!/command/with-contenv bashio

### DEFINE FUNCTIONS ##########################################################
echo "Source required files to load required functions"
### Source required files
#
# Source & Init product's library
[ -f /app/libproduct.sh ] &&
  echo "Source libproduct.sh" &&
  . /app/libproduct.sh &&
  type initProduct >/dev/null &&
  initProduct

log_debug "Source /app/subroutines.sh"
. /app/subroutines.sh

log_debug "Source /app/discovery.sh"
. /app/discovery.sh

log_debug "Source /app/listen_to_mqtt.sh"
. /app/listen_to_mqtt.sh
### END Source all required files

### SETUP ENVIRONMENT #########################################################
if [ ! -d /share/tesla_ble_mqtt ]; then
  log_info "Creating directory /share/tesla_ble_mqtt"
  mkdir -p /share/tesla_ble_mqtt
else
  log_debug "/share/tesla_ble_mqtt already exists, existing keys can be reused"
fi

# If empty string, initialize w/ default value - Required for add-on and Docker standalone
export BLE_CMD_RETRY_DELAY=${BLE_CMD_RETRY_DELAY:-5}
export BLECTL_FILE_INPUT=${BLECTL_FILE_INPUT:-}
export HA_BACKEND_DISABLE=${HA_BACKEND_DISABLE:-false}
export PRESENCE_DETECTION_LOOP_DELAY=${PRESENCE_DETECTION_LOOP_DELAY:-120}
export PRESENCE_DETECTION_TTL=${PRESENCE_DETECTION_TTL:-240}

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

[ -n "$HA_BACKEND_DISABLE" ] && log_info "  HA_BACKEND_DISABLE=$HA_BACKEND_DISABLE"
[ -n "$BLECTL_FILE_INPUT" ] && log_info "  BLECTL_FILE_INPUT=$BLECTL_FILE_INPUT"

# MQTT clients anonymous or authentication mode
if [ -n "$MQTT_USERNAME" ]; then
  log_notice "Setting up MQTT clients with authentication"
  export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u '${MQTT_USERNAME}' -P '${MQTT_PASSWORD}'"
  export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT -u '${MQTT_USERNAME}' -P '${MQTT_PASSWORD}'"
else
  log_notice "Setting up MQTT clients using anonymous mode"
  export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT"
  export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT"
fi

# Replace | with ' ' white space
BLE_MAC_LIST=$(echo $BLE_MAC_LIST | sed -e 's/[|,;]/ /g')
VIN_LIST=$(echo $VIN_LIST | sed -e 's/[|,;]/ /g')

vin_count=0
for vin in $VIN_LIST; do
  # Populate BLE Local Names list
  vin_count=$((vin_count + 1))
  BLE_LN=$(eval tesla_vin2ble_ln $vin)
  log_debug "Adding $BLE_LN to BLE_LN_LIST, count $vin_count"
  BLE_LN_LIST="$BLE_LN_LIST $BLE_LN"

  ################ HANDLE CONFIG CHANGE #######################################
  # TEMPORARY - Move original "vin" key to "vin{1}"
  if [ -f /share/tesla_ble_mqtt/private.pem ] && [ $vin_count -eq 1 ]; then
    log_warning "Keys exist from a previous installation with single VIN which is deprecated"
    log_warning "This module migrates the key files to attribute them to $vin and remove old MQTT entities"
    log_warning "/share/tesla_ble_mqtt/private.pem /share/tesla_ble_mqtt/${vin}_private.pem"
    log_warning "/share/tesla_ble_mqtt/public.pem /share/tesla_ble_mqtt/${vin}_public.pem"
    delete_legacies $vin
  fi # END TEMPORARY
done

# Populate PRESENCE_EXPIRE_TIME_LIST only if Presence Detection is enable
if [ $PRESENCE_DETECTION_TTL -gt 0 ]; then
  log_info "Presence detection is enable with a TTL of $PRESENCE_DETECTION_TTL seconds"
  ble_mac_addr_count=0
  # shellcheck disable=SC2034
  for ble_mac in $BLE_MAC_LIST; do
    ble_mac_addr_count=$((ble_mac_addr_count + 1))
    log_debug "Adding 0 to PRESENCE_EXPIRE_TIME_LIST, count $ble_mac_addr_count"
    PRESENCE_EXPIRE_TIME_LIST="$PRESENCE_EXPIRE_TIME_LIST 0"
  done
else
  log_info "Presence detection is not enabled due to TTL of $PRESENCE_DETECTION_TTL seconds"
fi

# Setup HA auto discovery, or skip if HA backend is disable, and discard old MQTT messages
discardMessages=yes
setupHAAutoDiscoveryLoop $discardMessages

# IF HA backend is enable, call listen_for_HA_start()
if [ "$HA_BACKEND_DISABLE" = "false" ]; then
  log_notice "Listening for Home Assistant Start (in background)"
  listen_for_HA_start &
else
  log_info "HA backend is disable, not listening for Home Assistant Start"
fi

### START MAIN PROGRAM LOOP ###################################################

log_info "Entering main loop..."
while :; do

  # Launch listen_to_mqtt_loop in background
  log_notice "Lauching background listen_to_mqtt_loop..."
  listen_to_mqtt_loop &
  # Don't run presence detection if TTL is 0

  # If PRESENCE_DETECTION_TTL > 0 and BLE_MAC_LIST is not empty
  if [ $PRESENCE_DETECTION_TTL -gt 0 ] && [ -n "$BLE_MAC_LIST" ]; then
    log_info "Launch BLE scanning for car presence every $PRESENCE_DETECTION_LOOP_DELAY seconds"
    listen_to_ble $vin_count
    # Run listen_to_ble every 3m
    sleep $PRESENCE_DETECTION_LOOP_DELAY
  else
    while :; do
      sleep 86400
    done
  fi

done
