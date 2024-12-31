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
    log_error "${MQTT_OUT}" &&
    return 1
  log_debug "MQTT topic $MQTT_TOPIC succesfully updated to $state"

  return 0

}

function readState() {
  vin=$1

  log_debug "readState; entering vin:$vin"

  # Read and parse charge state
  readChargeState $vin
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    log_debug "readState; failed to read charge state vin:$vin. Exit status: $EXIT_STATUS"
    ret=2
  else
    log_debug "readState; read of charge state succeeded vin:$vin"
    ret=0
  fi

  sleep $BLE_CMD_RETRY_DELAY

  log_debug "readState; leaving vin:$vin return:$ret"
  return $ret

}

function getStateValueAndPublish() {
  vin=$1
  jsonParam=$2
  mqttTopic=$3

  # Get value from JSON, and publish to MQTT
  rqdValue=`echo $stateJSON | jq -e $jsonParam`
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=2
    log_debug "getStateValueAndPublish; failed to parse $jsonParam for vin:$vin return:$ret"
  else
    ret=0
    log_debug "getStateValueAndPublish; $jsonParam parsed as $rqdValue for vin:$vin return:$ret"
    # Publish to MQTT state topic
    stateMQTTpub $vin $rqdValue $mqttTopic
  fi

  return $ret
}

function readChargeState() {
  vin=$1

  # Send state command

  # Exit if not successful

  # Obtain result
  stateJSON=`cat /share/tesla_ble_mqtt/${vin}_charge`
  
  getStateValueAndPublish $vin '.chargeState.batteryLevel' sensor/charge_state && 
  getStateValueAndPublish $vin '.chargeState.batteryRange' sensor/battery_range &&  
  getStateValueAndPublish $vin '.chargeState.chargerPower' sensor/charger_power &&  
  getStateValueAndPublish $vin '.chargeState.chargerActualCurrent' sensor/charger_actual_current && 
  getStateValueAndPublish $vin '.chargeState.chargeEnergyAdded' sensor/charge_energy_added &&
  getStateValueAndPublish $vin '.chargeState.chargeEnableRequest' switch/charge_enable_request &&
  getStateValueAndPublish $vin '.chargeState.chargePortDoorOpen' cover/charge_port_door_open &&
  getStateValueAndPublish $vin '.chargeState.chargeCurrentRequest' number/charge_current_request &&
  getStateValueAndPublish $vin '.chargeState.chargeLimitSoc' number/charge_limit_soc
  # Not done: chargePortLatch, battery_heater_on

  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=3
    log_error "readChargeState; one of the getStateValueAndPublish calls failed for vin:$vin return:$ret"
  else
    ret=0
    log_info "readChargeState; Completed successfully for vin:$vin"
  fi

  return $ret
}
