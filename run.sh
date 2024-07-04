#!/bin/ash
# Note: shebang will be replaced automatically by the HA addon deployment script to #!/command/with-contenv bashio

### DEFINE FUNCTIONS ###############################################################################################

### Source required files
#
# Source product's library
log_info "Source required files to load our functions"
[ -f /app/libproduct.sh ] \
  && log_info "Source libproduct.sh" \
  && . /app/libproduct.sh

log_info "Source /app/libcolor.sh"
export COLOR="true" \
  && . /app/libcolor.sh

log_info "Source /app/subroutines.sh"
. /app/subroutines.sh

log_info "Source /app/discovery.sh"
. /app/discovery.sh

log_info "Source /app/listen_to_mqtt.sh"
. /app/listen_to_mqtt.sh
### END Source all required files


### Credits Time
#
log_cyan "tesla_ble_mqtt_docker by Iain Bullock 2024 https://github.com/iainbullock/tesla_ble_mqtt_docker"
log_cyan "Inspiration by Raphael Murray https://github.com/raphmur"
log_cyan "Instructions by Shankar Kumarasamy https://shankarkumarasamy.blog/2024/01/28/tesla-developer-api-guide-ble-key-pair-auth-and-vehicle-commands-part-3"
### END Credits Time


### SETUP ENVIRONMENT ###########################################################################################
if [ ! -d /share/tesla_ble_mqtt ]; then
    log_info "Creating directory /share/tesla_ble_mqtt"
    mkdir -p /share/tesla_ble_mqtt
else
    log_debug "/share/tesla_ble_mqtt already exists, existing keys can be reused"
fi


### SETUP PRODUCT  ###########################################################################################
# If it's a function, call productInit
if type -f productInit > /dev/null; then
  productInit
fi


### TODO : MOVE TO ADD-ON's libproduct; make it a function and name it "productInit()"
### INITIALIZE VARIABLES AND FUNCTIONS TO MAKE THIS .sh RUN ALSO STANDALONE ##########################################
# read options in case of HA addon. Otherwise, they will be sent as environment variables
if [ -n "${HASSIO_TOKEN:-}" ]; then
  export BLE_MAC_LIST="$(bashio::config 'ble_mac3')"
  export DEBUG="$(bashio::config 'debug')"
  export MQTT_SERVER="$(bashio::config 'mqtt_server')"
  export MQTT_PORT="$(bashio::config 'mqtt_port')"
  export MQTT_PASSWORD="$(bashio::config 'mqtt_password')"
  export MQTT_USERNAME="$(bashio::config 'mqtt_username')"
  export PRESENCE_DETECTION_TTL="$(bashio::config 'presence_detection_ttl')"
  export BLE_CMD_RETRY_DELAY="$(bashio::config 'ble_cmd_retry_delay')"
  export VIN_LIST="$(bashio::config 'vin_list')"
fi


### TODO - Move to Docker's libproduct otherwise this setting will show up for add-on
export HA_BACKEND_DISABLE=${HA_BACKEND_DISABLE:=false}
### TODO : Add validations in Docker's libproduct; make it a function and name it "productInit()"
### Docker Add validation for ly for docker. Addon in config allows to specify
### What's valid/needed or not.
###
###


### LOG CONFIG VARS ##################################################################################
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
[ ! -z $HA_BACKEND_DISABLE ] && log_green "HA_BACKEND_DISABLE=$HA_BACKEND_DISABLE"
[ ! -z $BLECTL_FILE_INPUT ] && log_green "BLECTL_FILE_INPUT=$BLECTL_FILE_INPUT"

# MQTT clients anonymous or authentication mode
if [ ! -z ${MQTT_USERNAME} ]; then
  log_debug "Setting up MQTT clients with authentication is on; MQTT_USERNAME=$MQTT_USERNAME"
  export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u \"${MQTT_USERNAME}\" -P \"${MQTT_PASSWORD}\""
  export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT -u \"${MQTT_USERNAME}\" -P \"${MQTT_PASSWORD}\""
else
  log_notice "Setting up MQTT clients in anonymous"
  export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT"
  export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT"
fi

# Replace | with ' ' white space
BLE_MAC_LIST=$(echo $BLE_MAC_LIST | sed -e 's/|/ /g')
VIN_LIST=$(echo $VIN_LIST | sed -e 's/|/ /g')

vin_count=0
while vin in $VIN_LIST; do
  # Populate BLE Local Names and VINS "arrays"
  vin_count=$(expr $vin_count + 1)
  BLE_LN${vin_count}=$(tesla_vin2ble_ln $vin)
  VIN${vin_count}=$vin
  log_debug "Adding $vin to the list, count $vin_count"

  ################ HANDLE CONFIG CHANGE ##############
  # TEMPORARY - Move original "vin" key to "vin{1}"
  if [ -f /share/tesla_ble_mqtt/private.pem ] && [ $vin_count -eq 1 ]; then
    log_notice "Keys exist from a previous installation with single VIN which is deprecated"
    log_notice "This module migrates the key files to attribute them to $vin and remove old MQTT entities"
    log_notice "/share/tesla_ble_mqtt/private.pem /share/tesla_ble_mqtt/${vin}_private.pem"
    log_notice "/share/tesla_ble_mqtt/public.pem /share/tesla_ble_mqtt/${vin}_public.pem"
    delete_legacies $vin
  fi # END TEMPORARY
done

# Populate BLE_MACS "array" only if Presence Detection is enable
if [ $PRESENCE_DETECTION_TTL -gt 0 ] ; then
  log_info "Presence detection is enable with a TTL of $PRESENCE_DETECTION_TTL seconds"
  ble_addr_count=0
  while ble_mac in $BLE_MAC_LIST; do
    ble_addr_count=$(expr $ble_addr_count + 1)
    BLE_MAC${ble_addr_count}=$ble_mac
    PRESENCE_EXPIRE_TIME${ble_addr_count}=9999999999
    log_debug "Adding $ble_mac to the list, count $ble_addr_count"
  done

  if [ $vin_count -eq $mac_addr_count ]; then
    log_debug "Fantastic, we have $vin_count VIN(s) and $ble_addr_count BLE MAC Addr"
  else
    log_fotal "VIN count $vin_count differs from  BLE MAC Addr count $ble_addr_count!"
    # should we exit fatal, things might not work as expected.
    exit 10
  fi
else
  log_info "Presence detection is not enable due to TTL of $PRESENCE_DETECTION_TTL seconds"
fi


# Setup HA auto discovery, or skip if HA backend is disable, and discard old MQTT messages
discardMessages=yes
setup_auto_discovery_loop $discardMessages

# IF HA backend is enable, call listen_for_HA_start()
if [ "$HA_BACKEND_DISABLE" == "false" ]; then
  log_info "Listening for Home Assistant Start (in background)"
  listen_for_HA_start &
else
  log_notice "HA backend is disable, not listening for Home Assistant Start"
fi


### START MAIN PROGRAM LOOP ######################################################################################
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
    ((counter++))
    if [[ $counter -gt 90 ]]; then
      log_info "Reached 90 MQTT loops (~3min): Launch BLE scanning for car presence"
      listen_to_ble
    fi
    counter=0
  fi
  sleep 2
done
