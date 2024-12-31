#!/bin/ash
#
# shellcheck shell=dash
#
# read-state.sh

## function poll_state_loop
function poll_state_loop() {
    log_notice "Entering poll_state_loop..."

    sleep 30
}

function stateMQTTpub() {
  vin=$1
  state=$2
  topic=$3

  MQTT_TOPIC="tesla_ble/$vin/$topic"

  log_info "Setting MQTT topic $MQTT_TOPIC to $state"

  # Maybe we need a function in the future for mosquitto_pub w/ retry
  set +e
  MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m $state 2>&1)
  EXIT_STATUS=$?
  set -e
  [ $EXIT_STATUS -ne 0 ] &&
    log_error "$(MQTT_OUT)" &&
    return 1
  log_debug "MQTT topic $MQTT_TOPIC succesfully updated to $state"

  return 0

}

function readState() {
  vin=$1

  log_debug "readState; entering vin:$vin"

  # Read and parse charge state
  if readChargeState $vin; then
    log_debug "readState; failed to read charge state vin:$vin"
    return 2
  else
    log_debug "readState; read of charge state succeeded vin:$vin"
    ret=0
  fi

  sleep $BLE_CMD_RETRY_DELAY

  log_debug "readState; leaving vin:$vin return:$ret"
  return $ret

}

function readChargeState() {
  vin=$1
  jsonParam=.chargeState.batteryLevel
  mqttTopic=/sensor/charge_state

  # Send state command

  # Exit if not successful

  # Obtain result
  stateJSON=`cat /share/tesla_ble_mqtt/${vin}_charge`
  
  # Get value from JSON, and publish to MQTT
  rqdValue=`echo $stateJSON | jq -e '${jsonParam}'`
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    log_debug "readChargeState; failed to parse $jsonParam for vin:$vin return:$ret"
    return 2
  else
      log_debug "readChargeState; $jsonParam parsed as $rqdValue for vin:$vin return:$ret"
      # Publish to MQTT state topic
      stateMQTTpub($vin,$rqdValue,$mqttTopic)
  fi

  return 0
}
