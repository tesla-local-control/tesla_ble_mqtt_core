#!/bin/ash
# Note: shebang will be replaced automatically by the HA addon deployment script to #!/command/with-contenv bashio

### LOAD COLORS ####################################################################################################
export COLOR="true"
. /app/libcolor.sh

### DEFINE FUNCTIONS ###############################################################################################
log_notice "Load subroutines"
. /app/subroutines.sh
. /app/discovery.sh
. /app/listen_to_mqtt.sh

log_cyan "tesla_ble_mqtt_docker by Iain Bullock 2024 https://github.com/iainbullock/tesla_ble_mqtt_docker"
log_cyan "Inspiration by Raphael Murray https://github.com/raphmur"
log_cyan "Instructions by Shankar Kumarasamy https://shankarkumarasamy.blog/2024/01/28/tesla-developer-api-guide-ble-key-pair-auth-and-vehicle-commands-part-3"


###
###
### TODO
### Add validation for input, specially for docker. Addon in config allows to specify
### What's valid/needed or not.
###
###



### SETUP ENVIRONMENT ###########################################################################################
if [ ! -d /share/tesla_ble_mqtt ]; then
    log_info "Creating directory /share/tesla_ble_mqtt"
    mkdir -p /share/tesla_ble_mqtt
else
    log_debug "/share/tesla_ble_mqtt already exists, existing keys can be reused"
fi



### INITIALIZE VARIABLES AND FUNCTIONS TO MAKE THIS .sh RUN ALSO STANDALONE ##########################################
# read options in case of HA addon. Otherwise, they will be sent as environment variables
if [ -n "${HASSIO_TOKEN:-}" ]; then
  export BLE_MAC_LIST="$(bashio::config 'ble_mac3')"
  export DEBUG="$(bashio::config 'debug')"
  export MQTT_IP="$(bashio::config 'mqtt_ip')"
  export MQTT_PORT="$(bashio::config 'mqtt_port')"
  export MQTT_PWD="$(bashio::config 'mqtt_pwd')"
  export MQTT_USER="$(bashio::config 'mqtt_user')"
  export PRESENCE_DETECTION_TTL="$(bashio::config 'presence_detection_ttl')"
  export SEND_CMD_RETRY_DELAY="$(bashio::config 'send_cmd_retry_delay')"
  export TESLA_VIN_LIST="$(bashio::config 'vin_list')"
fi

### HANDLE CONFIG CHANGE #############################################################################################
if [ -f /share/tesla_ble_mqtt/private.pem ]; then
 log_error "Keys exist from a previous installation with single VIN which is deprecated"
 log_info "This module will try to migrate key files to attribute them to VIN1 and remove old MQTT entities"
 log_info "Please restart the docker image or HA addon. If if fails again:"
 log_info "1/ Check your configuration, you should explicitely specify VIN1/2/3"
 log_info "2/ Check that your have correctly renames the keys:"
 log_notice "/share/tesla_ble_mqtt/private.pem /share/tesla_ble_mqtt/[YOUR VIN]_private.pem"
 log_notice "/share/tesla_ble_mqtt/public.pem /share/tesla_ble_mqtt/[YOUR VIN]_public.pem"
 log_info "If you are supplying the keys from outside the container or addon, update them at source"
 delete_legacies
 exit 1
fi

if [ ! -z ${TESLA_VIN} ]; then
 log_fatal "Using deprecated configuration parameters --> Exiting."
 log_fatal "Fix config and restart. If you see this message again, please raise an issue"
 exit 1
fi

### INITIALIZE AND LOG CONFIG VARS ##################################################################################
log_green "Configuration Options are:
  BLE_MAC_LIST=$BLE_MAC_LIST
  DEBUG=$DEBUG
  MQTT_IP=$MQTT_IP
  MQTT_PORT=$MQTT_PORT
  MQTT_PWD=Not Shown
  MQTT_USER=$MQTT_USER
  PRESENCE_DETECTION_TTL=$PRESENCE_DETECTION_TTL
  SEND_CMD_RETRY_DELAY=$SEND_CMD_RETRY_DELAY
  TESLA_VIN_LIST=$TESLA_VIN_LIST"


export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u \"${MQTT_USER}\" -P \"${MQTT_PWD}\""
export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_IP -p $MQTT_PORT -u \"${MQTT_USER}\" -P \"${MQTT_PWD}\""

ble_addr_count=0
while ble_mac in $BLE_MAC_LIST; do
  ble_addr_count=$(expr $ble_addr_count + 1)
  BLE_MAC${ble_addr_count}=$ble_mac
  PRESENCE_EXPIRE_TIME${ble_addr_count}=9999999999
  log_debug "Adding $ble_mac to the list, count $ble_addr_count"
done

vin_count=0
while vin in $TESLA_VIN_LIST; do
  vin_count=$(expr $vin_count + 1)
  BLE_LN${vin_count}=$(tesla_vin2ble_ln $vin)
  TESLA_VIN${vin_count}=$vin
  log_debug "Adding $vin to the list, count $vin_count"
done

if [ $vin_count -eq $mac_addr_count ]; then
  log_debug "Fantastic, we have $vin_count VIN(s) and $ble_addr_count BLE MAC Addr"
else
  log_error "VIN count $vin_count differs from  BLE MAC Addr count $ble_addr_count!"
  # should we exit fatal, things might not work as expected.
fi

# Setup HA auto discovery & Discard old MQTT messages
while vin in $TESLA_VIN_LIST; do
  log_info "Setting up Home Assistant Auto Discovery for $vin"
  setup_auto_discovery $TESLA_VIN1
  log_info "Discarding any unread MQTT messages for $vin"
  eval $MOSQUITTO_SUB_BASE -E -i tesla_ble_mqtt -t tesla_ble_mqtt/$vin/+
done

log_info "Listening for Home Assistant Start (in background)"
listen_for_HA_start &

### START MAIN PROGRAM LOOP ######################################################################################
counter=0
log_info "Entering listening loop"
while true
do
 set +e
 listen_to_mqtt
 ((counter++))
 if [[ $counter -gt 90 ]]; then
  # Don't run presence detection if TTL is 0
  if [ $PRESENCE_DETECTION_TTL -gt 0 ] ; then
   log_info "Reached 90 MQTT loops (~3min): Launch BLE scanning for car presence"
   listen_to_ble
  fi
  counter=0
 fi
 sleep 2
done
