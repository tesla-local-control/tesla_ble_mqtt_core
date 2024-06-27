#!/bin/ash

# function for colored output to console
. /app/libcolor.sh

log.cyan "tesla_ble_mqtt_docker by Iain Bullock 2024 https://github.com/iainbullock/tesla_ble_mqtt_docker"
log.cyan "Inspiration by Raphael Murray https://github.com/raphmur"
log.cyan "Instructions by Shankar Kumarasamy https://shankarkumarasamy.blog/2024/01/28/tesla-developer-api-guide-ble-key-pair-auth-and-vehicle-commands-part-3"


### HANDLE CONFIG CHANGE #############################################################################################
if [ -f /share/tesla_ble_mqtt/private.pem ]; then
 log.error "Keys exist from a previous installation with single VIN which is deprecated"
 log.info "This module will try to migrate key files to attribute them to VIN1 and remove old MQTT entities"
 log.info "Please restart the docker image or HA addon. If if fails again:"
 log.info "1/ Check your configuration, you should explicitely specify VIN1/2/3"
 log.info "2/ Check that your have correctly renames the keys:"
 log.notice "/share/tesla_ble_mqtt/private.pem /share/tesla_ble_mqtt/[YOUR VIN]_private.pem"
 log.notice "/share/tesla_ble_mqtt/public.pem /share/tesla_ble_mqtt/[YOUR VIN]_public.pem"
 delete_legacies
 log.info "Succeeded. Please restart the addon or docker image."
 exit 1
fi
if [ "${TESLA_VIN}" ]; then
 log.error "Using depecated configuration parameters --> Exiting."
 log.error "Fix config and restart. If you see this message again, please raise an issue"
 exit 1
fi
 

### INITIALIZE VARIABLES AND FUNCTIONS TO MAKE THIS .sh RUN ALSO STANDALONE ##########################################
# read options in case of HA addon. Otherwise, they will be sent as environment variables
if [ -n "${HASSIO_TOKEN:-}" ]; then
  export TESLA_VIN1="$(config 'vin1')"
  export TESLA_VIN2="$(config 'vin2')"
  export TESLA_VIN3="$(config 'vin3')"
  export BLE_MAC1="$(config 'ble_mac1')"
  export BLE_MAC2="$(config 'ble_mac2')"
  export BLE_MAC3="$(config 'ble_mac3')"
  export MQTT_IP="$(config 'mqtt_ip')"
  export MQTT_PORT="$(config 'mqtt_port')"
  export MQTT_USER="$(config 'mqtt_user')"
  export MQTT_PWD="$(config 'mqtt_pwd')"
  export SEND_CMD_RETRY_DELAY="$(config 'send_cmd_retry_delay')"
  export DEBUG="$(config 'debug')"
fi

### INITIALIZE AND LOG CONFIG VARS ##################################################################################
log.green "Configuration Options are:
  TESLA_VIN=$TESLA_VIN1; $TESLA_VIN2; $TESLA_VIN3
  BLE_MAC=$BLE_MAC1; $BLE_MAC2; $BLE_MAC3
  MQTT_IP=$MQTT_IP
  MQTT_PORT=$MQTT_PORT
  MQTT_USER=$MQTT_USER
  MQTT_PWD=Not Shown
  SEND_CMD_RETRY_DELAY=$SEND_CMD_RETRY_DELAY
  DEBUG=$DEBUG"

### DEFINE FUNCTIONS ###############################################################################################
log.notice "Include subroutines"
. /app/subroutines.sh
. /app/discovery.sh
. /app/listen_to_mqtt.sh

### SETUP ENVIRONMENT ###########################################################################################
if [ ! -d /share/tesla_ble_mqtt ]
then
    log.info "Creating directory /share/tesla_ble_mqtt"
    mkdir /share/tesla_ble_mqtt
else
    log.debug "/share/tesla_ble_mqtt already exists, existing keys can be reused"
fi


log.info "Setting up auto discovery for Home Assistant"
if [ "$TESLA_VIN1" ] && [ $TESLA_VIN1 != "00000000000000000" ]; then
  setup_auto_discovery $TESLA_VIN1
fi
if [ "$TESLA_VIN2" ] && [ $TESLA_VIN2 != "00000000000000000" ]; then
  setup_auto_discovery $TESLA_VIN2
fi
if [ "$TESLA_VIN3" ] && [ $TESLA_VIN3 != "00000000000000000" ]; then
  setup_auto_discovery $TESLA_VIN3
fi

log.info "Listening for Home Assistant Start (in background)"
listen_for_HA_start &

log.info "Discarding any unread MQTT messages"
mosquitto_sub -E -i tesla_ble_mqtt -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t tesla_ble_mqtt/$TESLA_VIN1/+
mosquitto_sub -E -i tesla_ble_mqtt -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t tesla_ble_mqtt/$TESLA_VIN2/+
mosquitto_sub -E -i tesla_ble_mqtt -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t tesla_ble_mqtt/$TESLA_VIN3/+

### START MAIN PROGRAM LOOP ######################################################################################
counter=0
log.info "Entering listening loop"
while true
do
 set +e
 listen_to_mqtt
 ((counter++))
 if [[ $counter -gt 90 ]]; then
  log.info "Reached 90 MQTT loops (~3min): Launch BLE scanning for car presence"
  listen_to_ble
  counter=0
 fi
 sleep 2
done
