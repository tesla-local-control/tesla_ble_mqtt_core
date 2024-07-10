# shellcheck shell=dash
#
# listen_to_mqtt
#


### function setupMQTTCmds
##
##  Define MOSQUITTO_PUB_BASE and MOSQUITTO_SUB_BASE
#   - supports authentication or anonymous
##  - TODO : Add support for key authentication & tls
##
###
setupMQTTCmds() {
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
}


# Function
setupHAAutoDiscoveryLoop() {

  discardMessages=$1

  # Setup or skip HA auto discovery & Discard old MQTT messages
  for vin in $VIN_LIST; do

    # IF HA backend is enable, setup HA Auto Discover
    if [ "$ENABLE_HA_FEATURES" == "true" ]; then
      log_debug "Calling setupHAAutoDiscoveryMain() $vin"
      setupHAAutoDiscoveryMain $vin
    else
      log_info "HA backend is disable, skipping setup for HA Auto Discovery"
    fi

    # Discard or not awaiting messages
    if [ "$discardMessages" = "yes" ]; then
      log_notice "Discarding any unread MQTT messages for $vin"
      eval $MOSQUITTO_SUB_BASE -E -i tesla_ble_mqtt -t tesla_ble_mqtt/$vin/+
    fi
  done
}
