#!/bin/ash
#
# shellcheck shell=dash
#
# read-state.sh

## function poll_state_loop. For future implementation
function poll_state_loop() {
  log_notice "Entering poll_state_loop..."

  # Loop indefinitely
  while :; do
  
    # Loop for a day (arbitary but need to be a long time as modulus may slip when it resets casuing an early poll)
    i=0
    while [ $i -le 86400 ]; do

      # Repeat for each car
      for vin in $VIN_LIST; do

        log_debug "poll_state_loop: Setting variables from MQTT for VIN: $vin"
        set +e
        mqttOp=$( eval $MOSQUITTO_SUB_BASE --nodelay -W 1 --topic tesla_ble/$vin/variables/+ -F \"%t=%p\" 2>/dev/null )
        EXIT_CODE=$?
        set -e
        if [ $EXIT_CODE -eq 27 ]; then
          for item in $mqttOp; do
             assign=${item##*/}
             log_debug "Setting variable from MQTT: $assign"
             eval export ${vin}_$assign
          done
        fi

        # Get variables for this VIN. Note ash needs to use eval for dynamic variables
        polling=$( eval "echo \"\$${vin}_polling\"" )
        polling_interval=$( eval "echo \"\$${vin}_polling_interval\"" )
     
        # Check if polling turned off for this car
        if [ "$polling" != "on" ]; then
          log_debug "Polling is off for VIN: $vin, skipping"
        else
          log_debug "Polling is on for VIN: $vin, checking interval"
        
          # Is counter divisible by interval with no remainder? If so, it is time to attempt to poll
          mod=$(( i % $polling_interval ))
          if [ $mod -ne 0 ]; then
            log_debug "Count not divisible by polling_interval for VIN: $vin, Count: $i, Interval: $polling_interval"
          else
            log_info "Attempting to poll VIN: $vin"
            # Send a body-controller-state command. This checks if car is in bluetooth range and whether awake or asleep without acutally waking it
            set +e
            retjson=$( /usr/bin/tesla-control -ble -vin $vin -command-timeout 5s -connect-timeout 10s body-controller-state 2>&1 )
            EXIT_VALUE=$?
            set -e

            # If non zero, car is not contactable by bluetooth
            if [ $EXIT_VALUE -ne 0 ]; then
              log_warning "Car is not responding to bluetooth, maybe it's away. Not attempting to poll. VIN: $vin"

              # TODO: Update a future presence sensor. Set awake sensor to Unknown via MQTT availability

            else
              # Car has responded. Check if awake or asleep from the body-controller-state response
              rqdValue=$(echo $retjson | jq -e '.vehicleSleepStatus')
              EXIT_VALUE=$?
              if [ $EXIT_VALUE -eq 0 ] && [ "$rqdValue" == "\"VEHICLE_SLEEP_STATUS_AWAKE\"" ]; then
                log_info "Car is awake, so polling VIN: $vin"
                
                # Publish to MQTT awake topic, 'press' the Data Update Env button (which checks NO_POLL_SECTIONS environment variable to exclude various sections if required)
                stateMQTTpub $vin 'true' 'binary_sensor/awake'
                stateMQTTpub $vin 'read-state-envcheck' 'config'

              else
                log_info "Car is asleep, not polling VIN: $vin"
                stateMQTTpub $vin 'false' 'binary_sensor/awake' 
              fi

            fi

          fi

        fi

      done
    
      # Loop repeat approx every 30 secs
     sleep 29
     i=$(( i + 30 ))

    done

  done

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
  sections=$2

  log_debug "readState; entering. Sections: $sections VIN:$vin"
  charge=0; climate=0; tyre=0; closure=0; drive=0
  case $sections in
  charge)
    charge=1
  ;;
  climate)
    climate=1
  ;;
  tyre)
    tyre=1
  ;;
  closure)
    closure=1
  ;;
  drive)
    drive=1
  ;;
  env_check)
    charge=1; climate=1; tyre=1; closure=1; drive=1
    for sect in $NO_POLL_SECTIONS; do
      case $sect in
      charge)
        charge=0
      ;;
      climate)
        climate=0
      ;;
      tire-pressure)
        tyre=0
      ;;
      closures)
        closure=0
      ;;
      drive)
        drive=0
      ;;
      *)
      log_warning "readState: Invalid state category in NO_POLL_SECTIONS"
      ;;
      esac
    done
  ;;  
  *)
    charge=1; climate=1; tyre=1; closure=1; drive=1
  ;;  
  esac

  if [ $charge -eq 1 ]; then
    # Read and parse charge state
    readChargeState $vin
    sleep $BLE_CMD_RETRY_DELAY
  fi

  if [ $climate -eq 1 ]; then
    # Read and parse climate state
    readClimateState $vin
    sleep $BLE_CMD_RETRY_DELAY
  fi

  if [ $tyre -eq 1 ]; then
    # Read and parse tire-pressure state
    readTyreState $vin
    sleep $BLE_CMD_RETRY_DELAY
  fi

  if [ $closure -eq 1 ]; then
    # Read and parse closures state
    closuresState $vin
    sleep $BLE_CMD_RETRY_DELAY
  fi

  if [ $drive -eq 1 ]; then
    # Read and parse drive state
    driveState $vin
    sleep $BLE_CMD_RETRY_DELAY
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
  TESLA_CONTROL_CMD="/usr/bin/tesla-control -ble -command-timeout 5s -connect-timeout 10s $command 2>&1"

  # Retry loop
  max_retries=5
  for sendCommandCount in $(seq $max_retries); do

    log_notice "sendBLECommand: Attempt $sendCommandCount/${max_retries} sending $commandDescription to vin:$vin command:$command"
    set +e
    TESLACTRLOUT=$(eval $TESLA_CONTROL_CMD)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_debug "sendBLECommand; $TESLACTRLOUT"
      log_info "Command $command was successfully delivered to vin:$vin"
      # Publish to MQTT awake topic
      stateMQTTpub $vin 'true' 'binary_sensor/awake' 
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
  rqdValue=$(echo $stateJSON | jq -e $jsonParam)
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -eq 0 ] || { [ $EXIT_STATUS -eq 1 ] && [ $rqdValue == "false" ]; } || { [ $EXIT_STATUS -eq 1 ] && [ $jsonParam == ".chargeState.connChargeCable" ]; }; then

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

    # Modify values in specific cases
    if [ $jsonParam == ".closuresState.sentryModeState" ]; then
      rqdValue=$(echo $rqdValue | jq '.Off')
      if [ $rqdValue == "{}" ]; then
        rqdValue="false"
      else
        rqdValue="true"
      fi
    fi

    # Modify values in specific cases
    if [ $jsonParam == ".chargeState.connChargeCable" ]; then
      rqdValue=$(echo $rqdValue | awk -F "\"" '{print $2}')
      if [ -z "$rqdValue" ]; then
        rqdValue="No"
      fi
    fi

    # Modify values in specific cases
    if [ $jsonParam == ".driveState.odometerInHundredthsOfAMile" ]; then
      rqdValue=$((rqdValue / 100))
    fi

    # Note if any window is open
    if [[ $jsonParam == ".closuresState.windowOpen"* ]] && [ $rqdValue == "true" ]; then
      ANYWINDOWOPEN="true"
    fi

    ret=0
    log_debug "getStateValueAndPublish; $jsonParam parsed as $rqdValue for vin:$vin return:$ret"

    # Publish to MQTT state topic
    stateMQTTpub $vin $rqdValue $mqttTopic

  else
    ret=2
    log_warning "getStateValueAndPublish; failed to parse $jsonParam for vin:$vin"
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
  getStateValueAndPublish $vin '.chargeState.batteryLevel' sensor/charge_state "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.batteryRange' sensor/battery_range "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargerPower' sensor/charger_power "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargerActualCurrent' sensor/charger_actual_current "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargerVoltage' sensor/charger_voltage "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargeEnergyAdded' sensor/charge_energy_added "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargeMilesAddedRated' sensor/charge_range_added "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargeRateMph' sensor/charge_speed "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.connChargeCable' sensor/charge_cable "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargeEnableRequest' switch/charge_enable_request "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargePortDoorOpen' cover/charge_port_door_open "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargeCurrentRequest' number/charge_current_request "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.chargeState.chargeLimitSoc' number/charge_limit_soc "$TESLACTRLOUT"

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
  getStateValueAndPublish $vin '.climateState.insideTempCelsius' sensor/inside_temp "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.outsideTempCelsius' sensor/outside_temp "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.passengerTempSetting' sensor/passenger_temp "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.driverTempSetting' number/driver_temp_setting "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.isClimateOn' switch/is_climate_on "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.steeringWheelHeater' switch/steering_wheel_heater "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.batteryHeater' binary_sensor/battery_heater_on "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.isFrontDefrosterOn' binary_sensor/front_defrost "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.isRearDefrosterOn' binary_sensor/rear_defrost "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.wiperBladeHeater' binary_sensor/wiper_heater "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.sideMirrorHeaters' binary_sensor/mirror_heater "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.seatHeaterLeft' select/seat_heater_left "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.seatHeaterRight' select/seat_heater_right "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.seatHeaterRearLeft' select/seat_heater_rear_left "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.climateState.seatHeaterRearRight' select/seat_heater_rear_right "$TESLACTRLOUT"

}

function readTyreState() {
  vin=$1

  # Send state command
  export TESLACTRLOUT=""
  sendBLECommand $vin "state tire-pressure" "Send state command with category=tire-pressure"
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=2
    log_debug "readTyreState; sendBLECommand failed for vin:$vin return:$ret"
    return $ret
  else
    log_debug "readTyreState; sendBLECommand succeeded for vin:$vin"
  fi

  # Get values from the JSON and publish corresponding MQTT state topic
  getStateValueAndPublish $vin '.tirePressureState.tpmsPressureFl' sensor/tpms_pressure_fl "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.tirePressureState.tpmsPressureFr' sensor/tpms_pressure_fr "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.tirePressureState.tpmsPressureRl' sensor/tpms_pressure_rl "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.tirePressureState.tpmsPressureRr' sensor/tpms_pressure_rr "$TESLACTRLOUT"

}

function closuresState() {
  vin=$1

  # Send state command
  export TESLACTRLOUT=""
  sendBLECommand $vin "state closures" "Send state command with category=closures"
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=2
    log_debug "closuresState; sendBLECommand failed for vin:$vin return:$ret"
    return $ret
  else
    log_debug "closuresState; sendBLECommand succeeded for vin:$vin"
  fi

  # Windows Cover is for all windows, so report status to be open if any window is open
  export ANYWINDOWOPEN=0

  # Get values from the JSON and publish corresponding MQTT state topic
  getStateValueAndPublish $vin '.closuresState.sentryModeState' switch/sentry_mode "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.doorOpenTrunkRear' cover/rear_trunk "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.doorOpenTrunkFront' binary_sensor/frunk_open "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.windowOpenDriverFront' binary_sensor/window_open_driver_front "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.windowOpenPassengerFront' binary_sensor/window_open_pass_front "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.windowOpenDriverRear' binary_sensor/window_open_driver_rear "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.windowOpenPassengerRear' binary_sensor/window_open_pass_rear "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.doorOpenDriverFront' binary_sensor/door_open_driver_front "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.doorOpenPassengerFront' binary_sensor/door_open_pass_front "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.doorOpenDriverRear' binary_sensor/door_open_driver_rear "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.doorOpenPassengerRear' binary_sensor/door_open_pass_rear "$TESLACTRLOUT"
  getStateValueAndPublish $vin '.closuresState.locked' lock/locked "$TESLACTRLOUT"

  # Publish to windows cover state topic
  if [ $ANYWINDOWOPEN == "true" ]; then
    # Publish to MQTT state topic
    stateMQTTpub $vin "true" "cover/windows"
  else
    stateMQTTpub $vin "false" "cover/windows"
  fi

}

function driveState() {
  vin=$1

  # Send state command
  export TESLACTRLOUT=""
  sendBLECommand $vin "state drive" "Send state command with category=drive"
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    ret=2
    log_debug "driveState; sendBLECommand failed for vin:$vin return:$ret"
    return $ret
  else
    log_debug "driveState; sendBLECommand succeeded for vin:$vin"
  fi

  # Get values from the JSON and publish corresponding MQTT state topic
  getStateValueAndPublish $vin '.driveState.odometerInHundredthsOfAMile' sensor/odometer "$TESLACTRLOUT"

}
