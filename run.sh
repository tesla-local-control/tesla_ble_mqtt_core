#!/bin/ash
#
# shellcheck shell=dash
#
# Note: shebang will be replaced automatically by the HA addon deployment script to #!/command/with-contenv bashio

### DEFINE FUNCTIONS ##########################################################
echo "Source required files to load required functions"
### Source required files
#
# Source product's library
[ -f /app/libproduct.sh ] \
  && echo "Source libproduct.sh" \
  && . /app/libproduct.sh

# Source libcolor
echo "Source /app/libcolor.sh"
export COLOR=${COLOR:=true}
. /app/libcolor.sh

log_info "Source /app/subroutines.sh"
. /app/subroutines.sh

log_info "Source /app/discovery.sh"
. /app/discovery.sh

log_info "Source /app/listen_to_mqtt.sh"
. /app/listen_to_mqtt.sh
### END Source all required files


### SETUP ENVIRONMENT #########################################################
if [ ! -d /share/tesla_ble_mqtt ]; then
    log_info "Creating directory /share/tesla_ble_mqtt"
    mkdir -p /share/tesla_ble_mqtt
else
    log_debug "/share/tesla_ble_mqtt already exists, existing keys can be reused"
fi


### SETUP PRODUCT  ############################################################
# If it's a function, call productInit
if type productInit > /dev/null; then
  productInit
fi


### TODO - Move to Docker's libproduct otherwise this setting will show up for add-on
export HA_BACKEND_DISABLE=${HA_BACKEND_DISABLE:=false}
### TODO : Add validations in Docker's libproduct; make it a function and name it "productInit()"
### Docker Add validation for ly for docker. Addon in config allows to specify
### What's valid/needed or not.
###
###


### LOG CONFIG VARS ###########################################################
log_green "Configuration Options are:
  BLE_MAC_LIST=$BLE_MAC_LIST
  DEBUG=$DEBUG
  MQTT_SERVER=$MQTT_SERVER
  MQTT_PORT=$MQTT_PORT
  MQTT_PASSWORD=Not Shown
  MQTT_USERNAME=$MQTT_USERNAME
  PRESENCE_DETECTION_TTL=$PRESENCE_DETECTION_TTL
  BLE_CMD_RETRY_DELAY=$BLE_CMD_RETRY_DELAY
  VIN_LIST=$VIN_LIST"

export BLECTL_FILE_INPUT=${BLECTL_FILE_INPUT:-}

[ -n "$HA_BACKEND_DISABLE" ] && log_green "HA_BACKEND_DISABLE=$HA_BACKEND_DISABLE"
[ -n "$BLECTL_FILE_INPUT" ] && log_green "BLECTL_FILE_INPUT=$BLECTL_FILE_INPUT"

# MQTT clients anonymous or authentication mode
if [ -n "$MQTT_USERNAME" ]; then
  log_debug "Setting up MQTT clients with authentication"
  export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u \"${MQTT_USERNAME}\" -P \"${MQTT_PASSWORD}\""
  export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT -u \"${MQTT_USERNAME}\" -P \"${MQTT_PASSWORD}\""
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
    log_notice "Keys exist from a previous installation with single VIN which is deprecated"
    log_notice "This module migrates the key files to attribute them to $vin and remove old MQTT entities"
    log_notice "/share/tesla_ble_mqtt/private.pem /share/tesla_ble_mqtt/${vin}_private.pem"
    log_notice "/share/tesla_ble_mqtt/public.pem /share/tesla_ble_mqtt/${vin}_public.pem"
    delete_legacies $vin
  fi # END TEMPORARY
done

# Populate PRESENCE_EXPIRE_TIME_LIST only if Presence Detection is enable
if [ $PRESENCE_DETECTION_TTL -gt 0 ] ; then
  log_info "Presence detection is enable with a TTL of $PRESENCE_DETECTION_TTL seconds"
  ble_mac_addr_count=0
  # shellcheck disable=SC2034
  for ble_mac in $BLE_MAC_LIST; do
    ble_mac_addr_count=$((ble_mac_addr_count + 1))
    log_debug "Adding 0 to PRESENCE_EXPIRE_TIME_LIST, count $ble_mac_addr_count"
    PRESENCE_EXPIRE_TIME_LIST="$PRESENCE_EXPIRE_TIME_LIST 0"
  done
else
  log_info "Presence detection is not enable due to TTL of $PRESENCE_DETECTION_TTL seconds"
fi


# Setup HA auto discovery, or skip if HA backend is disable, and discard old MQTT messages
discardMessages=yes
setup_auto_discovery_loop $discardMessages

# IF HA backend is enable, call listen_for_HA_start()
if [ "$HA_BACKEND_DISABLE" = "false" ]; then
  log_info "Listening for Home Assistant Start (in background)"
  listen_for_HA_start &
else
  log_notice "HA backend is disable, not listening for Home Assistant Start"
fi


### START MAIN PROGRAM LOOP ###################################################
log_info "Entering main MQTT listening loop"

# TODO : How should we handle a MQTT restart or network failure to reach the service?
#        The while loop below will restart listen_to_mqtt but for listen_for_HA_start,
#        it will fail and nothing will restart it.
#        If set probably set -e/+e , perhaps on MQTT restat we also want to restart?

counter=0
log_info "Entering listening loop"
while true
do

  # Call listen_to_mqtt()
  log_debug "Calling listen_to_mqtt()"
  set +e
  listen_to_mqtt

  # Don't run presence detection if TTL is 0
  if [ $PRESENCE_DETECTION_TTL -gt 0 ] ; then
    counter=$((counter + 1))
    if [ $counter -gt 90 ]; then
      log_info "Reached 90 MQTT loops (~3min): Launch BLE scanning for car presence"
      listen_to_ble $vin_count
      counter=0
    fi
  fi
  sleep 2
done
