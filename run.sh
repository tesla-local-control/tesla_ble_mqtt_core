#!/bin/ash -e
#
# shellcheck shell=dash
#
# Note: shebang will be replaced automatically by the HA addon deployment script to #!/command/with-contenv bashio

### DEFINE FUNCTIONS ##########################################################
echo "[$(date +%H:%M:%S)] Starting... loading /app/env.sh"
# Init product's environment
. /app/env.sh

# Replace | with ' ' white space
VIN_LIST=$(echo $VIN_LIST | sed -e 's/[|,;]/ /g')

vin_count=0
for vin in $VIN_LIST; do
  # Populate BLE Local Names list
  vin_count=$((vin_count + 1))
  BLE_LN=$(vinToBLEln $vin)
  log_debug "Adding $BLE_LN to BLE_LN_LIST, vin_count:$vin_count"
  BLE_LN_LIST="$BLE_LN_LIST $BLE_LN"
  if [ -f $KEYS_DIR/${vin}_macaddr ]; then
    BLE_MAC=$(cat $KEYS_DIR/${vin}_macaddr)
    log_debug "Found BLE_MAC:$BLE_MAC in $KEYS_DIR/${vin}_macaddr; adding to BLE_MAC_LIST"
    BLE_MAC_LIST="$BLE_MAC_LIST $BLE_MAC"
  else
    log_debug "Adding default value FF:FF:FF:FF:FF:FF to BLE_MAC_LIST"
    BLE_MAC_LIST="$BLE_MAC_LIST FF:FF:FF:FF:FF:FF"
    # Request bluetooth_read to run the "devices" command
    # shellcheck disable=SC2034
    BLTCTL_COMMAND_DEVICES=true
  fi
  log_debug "Adding default value 0 to PRESENCE_EXPIRE_TIME_LIST"
  PRESENCE_EXPIRE_TIME_LIST="$PRESENCE_EXPIRE_TIME_LIST 0"

  if [ -f $KEYS_DIR/${vin}_private.pem ] &&
    [ -f $KEYS_DIR/${vin}_public.pem ]; then
    log_debug "Found public and private keys set for vin:$vin"
    # TODO Remove in next release
    touch $KEYS_DIR/${vin}_pubkey_accepted
  else
    log_debug "Did not find public and private keys for vin:$vin"
  fi

  ################ HANDLE CONFIG CHANGE #######################################
  ### TODO TEMPORARY - Move original "vin" key to "vin{1}"
  ###
  if [ -f $KEYS_DIR/private.pem ] && [ $vin_count -eq 1 ]; then
    log_warning "Keys exist from a previous installation with single VIN which is deprecated"
    log_warning "This module migrates the key files to attribute them to $vin and remove old MQTT entities"
    log_warning "$KEYS_DIR/private.pem $KEYS_DIR/${vin}_private.pem"
    log_warning "$KEYS_DIR/public.pem $KEYS_DIR/${vin}_public.pem"
    delete_legacies $vin
  fi # END TEMPORARY

  if [ $PRESENCE_DETECTION_TTL -eq 0 ]; then
    MQTT_TOPIC=tesla_ble/$vin/binary_sensor/presence
    eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m Unknown
    log_notice "Presence detection disable; Deleting MQTT topic $MQTT_TOPIC"
    eval $MOSQUITTO_PUB_BASE -t $MQTT_TOPIC/config -n
  fi
  # Remove single entities (brute force command, no easy way to collect declared MQTT topics crossplatform)
  log_notice "Removing single buttons to be replaced by switches & covers:"
  log_notice "windows, charger, cherge-port, climate, trunk"
  delete_legacies_singles $vin

done
# remove leading white space
BLE_LN_LIST=$(echo $BLE_LN_LIST | sed -e 's/^ //g')
BLE_MAC_LIST=$(echo $BLE_MAC_LIST | sed -e 's/^ //g')
PRESENCE_EXPIRE_TIME_LIST=$(echo $PRESENCE_EXPIRE_TIME_LIST | sed -e 's/^ //g')

# log _LIST values
log_debug "VIN_LIST:$VIN_LIST"
log_debug "BLE_LN:$BLE_LN"
log_debug "BLE_LN_LIST:$BLE_LN_LIST"
log_debug "BLE_MAC_LIST:$BLE_MAC_LIST"
log_debug "PRESENCE_EXPIRE_TIME_LIST:$PRESENCE_EXPIRE_TIME_LIST"

# Setup HA auto discovery, or skip if HA backend is disable and discard old /config MQTT messages
setupHADeviceAllVINsLoop

# IF HA backend is enable, call listenForHAstatus()
if [ "$ENABLE_HA_FEATURES" == "true" ]; then
  log_notice "Listening for Home Assistant Start (in background)"
  listenForHAstatus &
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
  if [ $PRESENCE_DETECTION_TTL -gt 0 ]; then
    log_info "Launch BLE scanning for car presence every $PRESENCE_DETECTION_LOOP_DELAY seconds"
    listen_to_ble $vin_count
    # Run listen_to_ble every 3m
    sleep $PRESENCE_DETECTION_LOOP_DELAY
  else
    log_info "Presence detection is disable"
    while :; do
      sleep 86400
    done
  fi

done
