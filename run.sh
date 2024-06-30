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


### INITIALIZE VARIABLES AND FUNCTIONS TO MAKE THIS .sh RUN ALSO STANDALONE ##########################################
# read options in case of HA addon. Otherwise, they will be sent as environment variables
if [ -n "${HASSIO_TOKEN:-}" ]; then
  export TESLA_VIN1="$(bashio::config 'vin1')"
  export TESLA_VIN2="$(bashio::config 'vin2')"
  export TESLA_VIN3="$(bashio::config 'vin3')"
  export PRESENCE_DETECTION="$(bashio::config 'presence_detection')"
  export BLE_MAC1="$(bashio::config 'ble_mac1')"
  export BLE_MAC2="$(bashio::config 'ble_mac2')"
  export BLE_MAC3="$(bashio::config 'ble_mac3')"
  export MQTT_IP="$(bashio::config 'mqtt_ip')"
  export MQTT_PORT="$(bashio::config 'mqtt_port')"
  export MQTT_USER="$(bashio::config 'mqtt_user')"
  export MQTT_PWD="$(bashio::config 'mqtt_pwd')"
  export SEND_CMD_RETRY_DELAY="$(bashio::config 'send_cmd_retry_delay')"
  export DEBUG="$(bashio::config 'debug')"
fi

export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u \"${MQTT_USER}\" -P \"${MQTT_PWD}\""
export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_IP -p $MQTT_PORT -u \"${MQTT_USER}\" -P \"${MQTT_PWD}\""

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
if [ ${TESLA_VIN-} ]; then
 log_error "Using depecated configuration parameters --> Exiting."
 log_error "Fix config and restart. If you see this message again, please raise an issue"
 exit 1
fi

### INITIALIZE AND LOG CONFIG VARS ##################################################################################
log_green "Configuration Options are:
  TESLA_VIN=$TESLA_VIN1; $TESLA_VIN2; $TESLA_VIN3
  PRESENCE_DETECTION=$PRESENCE_DETECTION
  BLE_MAC=$BLE_MAC1; $BLE_MAC2; $BLE_MAC3
  MQTT_IP=$MQTT_IP
  MQTT_PORT=$MQTT_PORT
  MQTT_USER=$MQTT_USER
  MQTT_PWD=Not Shown
  SEND_CMD_RETRY_DELAY=$SEND_CMD_RETRY_DELAY
  DEBUG=$DEBUG"


### SETUP ENVIRONMENT ###########################################################################################
if [ ! -d /share/tesla_ble_mqtt ]; then
    log_info "Creating directory /share/tesla_ble_mqtt"
    mkdir -p /share/tesla_ble_mqtt
else
    log_debug "/share/tesla_ble_mqtt already exists, existing keys can be reused"
fi


log_info "Setting up auto discovery for Home Assistant"
if [ "$TESLA_VIN1" ] && [ $TESLA_VIN1 != "00000000000000000" ]; then
  setup_auto_discovery $TESLA_VIN1
fi
if [ "$TESLA_VIN2" ] && [ $TESLA_VIN2 != "00000000000000000" ]; then
  setup_auto_discovery $TESLA_VIN2
fi
if [ "$TESLA_VIN3" ] && [ $TESLA_VIN3 != "00000000000000000" ]; then
  setup_auto_discovery $TESLA_VIN3
fi

log_info "Listening for Home Assistant Start (in background)"
listen_for_HA_start &

log_info "Discarding any unread MQTT messages"
mosquitto_sub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -E -i tesla_ble_mqtt -t tesla_ble_mqtt/$TESLA_VIN1/+
mosquitto_sub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -E -i tesla_ble_mqtt -t tesla_ble_mqtt/$TESLA_VIN2/+
mosquitto_sub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -E -i tesla_ble_mqtt -t tesla_ble_mqtt/$TESLA_VIN3/+

### START MAIN PROGRAM LOOP ######################################################################################
counter=0
log_info "Entering listening loop"
while true
do
 set +e
 listen_to_mqtt
 ((counter++))
 if [[ $counter -gt 90 ]]; then
  if [ "$PRESENCE_DETECTION" = true ] ; then
   log_info "Reached 90 MQTT loops (~3min): Launch BLE scanning for car presence"
   listen_to_ble
  fi
  counter=0
 fi
 sleep 2
done
