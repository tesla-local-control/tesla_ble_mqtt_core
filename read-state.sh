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
    return 2
  else
    log_notice "readState; read of charge state succeeded vin:$vin"
    ret=0
  fi

  sleep $BLE_CMD_RETRY_DELAY

  # Read and parse climate state
  readClimateState $vin
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    log_debug "readState; failed to read climate state vin:$vin. Exit status: $EXIT_STATUS"
    return 2
  else
    log_notice "readState; read of climate state succeeded vin:$vin"
    ret=0
  fi


  log_debug "readState; leaving vin:$vin return:$ret"
  return $ret

}

# Use tesla-control to send (state) command
# Could use existing teslaCtrlSendCommand(), but that would need modifying to return JSON, and needs generally tidying up, and a fix for the indefinite loop if the car can't be woken 
# If this function works ok, I suggest teslaCtrlSendCommand() can use this code, this be deleted, and references updated
# I believe the indefinite loop occurs when user's automation keeps sending commands when the car is away / out of BLE range, which eventually locks up the container, requiring a restart
sendBLECommand() {
  vin=$1
  command=$2
  commandDescription=$3
  
  # Prepare for calling tesla-control
  export TESLA_VIN=$vin
  export TESLA_KEY_FILE=$KEYS_DIR/${vin}_private.pem
  export TESLA_KEY_NAME=$KEYS_DIR/${vin}_private.pem
  TESLA_CONTROL_CMD='/usr/bin/tesla-control -ble -command-timeout 5s -connect-timeout 10s $command 2>&1'

  # Retry loop
  max_retries=10
  for sendCommandCount in $(seq $max_retries); do

    log_notice "sendBLECommand: Attempt $sendCommandCount/${max_retries} sending $commandDescription to vin:$vin command:$command"
    set +e
    TESLACTRLOUT=$(eval $TESLA_CONTROL_CMD)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_debug "sendBLECommand; $TESLACTRLOUT"
      log_info "Command $command was successfully delivered to vin:$vin"
      return 0
    else
      if [[ "$TESLACTRLOUT" == *"car could not execute command"* ]]; then
        log_warning "sendBLECommand; $TESLACTRLOUT"
        log_warning "Skipping command $command to vin:$vin, not retrying"
        return 10
      elif [[ "$TESLACTRLOUT" == *"context deadline exceeded"* ]]; then
        log_warning "teslaCtrlSendCommand; $TESLACTRLOUT"
        log_warning "Vehicle might be asleep, or not present. Sending wake command"
        sleep $BLE_CMD_RETRY_DELAY
        tesla-control -ble -command-timeout 20s -connect-timeout 20s -domain vcsec wake
        sleep 5
      else
        log_error "tesla-control send command:$command to vin:$vin failed exit status $EXIT_STATUS."
        log_error "sendBLECommand; $TESLACTRLOUT"
      fi
      log_notice "sendBLECommand; Retrying in $BLE_CMD_RETRY_DELAY seconds"
      sleep $BLE_CMD_RETRY_DELAY
    fi
  done

  # Max retries
  log_warning "sendBLECommand; max retries unsuccessfully trying to send command $command to $vin"
  return 99
}

function getStateValueAndPublish() {
  vin=$1
  jsonParam=$2
  mqttTopic=$3
  stateJSON=$4

  # Get value from JSON, and publish to MQTT
  rqdValue=`echo $stateJSON | jq -e $jsonParam`
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -eq 0 ] || ([ $EXIT_STATUS -eq 1 ] && [ $rqdValue == "false" ]); then
    ret=0
    log_debug "getStateValueAndPublish; $jsonParam parsed as $rqdValue for vin:$vin return:$ret"
    
    # Modify values in specific cases
    if [[ $jsonParam == ".climateState.seatHeater"* ]]; then
      case $rqdValue in
        0)
          rqdValue="off"
        ;;
        1)
          rqdValue="low"
        ;;
        2)
          rqdValue="med"
        ;;
        3)
          rqdValue="high"
        ;;      
        *)
          rqdValue=" "
        ;;           
      esac
    fi     

    # Publish to MQTT state topic
    stateMQTTpub $vin $rqdValue $mqttTopic
  else
    ret=2
    log_debug "getStateValueAndPublish; failed to parse $jsonParam for vin:$vin return:$ret"
  fi

  return $ret
}

function readChargeState() {
  vin=$1

  # Send state command
  export TESLACTRLOUT=""
  sendBLECommand $vin "state charge" "Send state command with category=charge"
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=2
    log_debug "readChargeState; sendBLECommand failed for vin:$vin return:$ret"
    return $ret
  else
    log_debug "readChargeState; sendBLECommand succeeded for vin:$vin"
  fi

  # Get values from the JSON and publish corresponding MQTT state topic
  getStateValueAndPublish $vin '.chargeState.batteryLevel' sensor/charge_state "$TESLACTRLOUT" && 
  getStateValueAndPublish $vin '.chargeState.batteryRange' sensor/battery_range "$TESLACTRLOUT" &&  
  getStateValueAndPublish $vin '.chargeState.chargerPower' sensor/charger_power "$TESLACTRLOUT" &&  
  getStateValueAndPublish $vin '.chargeState.chargerActualCurrent' sensor/charger_actual_current "$TESLACTRLOUT" && 
  getStateValueAndPublish $vin '.chargeState.chargeEnergyAdded' sensor/charge_energy_added "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.chargeState.chargeEnableRequest' switch/charge_enable_request "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.chargeState.chargePortDoorOpen' cover/charge_port_door_open "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.chargeState.chargeCurrentRequest' number/charge_current_request "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.chargeState.chargeLimitSoc' number/charge_limit_soc "$TESLACTRLOUT"
  # Not done: 

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

function readClimateState() {
  vin=$1

  # Send state command
  export TESLACTRLOUT=""
  sendBLECommand $vin "state climate" "Send state command with category=climate"
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=2
    log_debug "readClimateState; sendBLECommand failed for vin:$vin return:$ret"
    return $ret
  else
    log_debug "readClimateState; sendBLECommand succeeded for vin:$vin"
  fi

  # Get values from the JSON and publish corresponding MQTT state topic
  getStateValueAndPublish $vin '.climateState.insideTempCelsius' sensor/inside_temp "$TESLACTRLOUT" && 
  getStateValueAndPublish $vin '.climateState.outsideTempCelsius' sensor/outside_temp "$TESLACTRLOUT" &&  
  getStateValueAndPublish $vin '.climateState.driverTempSetting' number/driver_temp_setting "$TESLACTRLOUT" &&  
  getStateValueAndPublish $vin '.climateState.isClimateOn' switch/is_climate_on "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.climateState.steeringWheelHeater' switch/steering_wheel_heater "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.climateState.isPreconditioning' binary_sensor/battery_heater_on "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.climateState.seatHeaterLeft' select/seat_heater_left "$TESLACTRLOUT" &&
  getStateValueAndPublish $vin '.climateState.seatHeaterRight' select/seat_heater_right "$TESLACTRLOUT"
  # Not done: Heater selects

  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=3
    log_error "readClimateState; one of the getStateValueAndPublish calls failed for vin:$vin return:$ret"
  else
    ret=0
    log_info "readClimateState; Completed successfully for vin:$vin"
  fi

  return $ret
}
