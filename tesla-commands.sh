# shellcheck shell=dash
#
# tesla-commands.sh
#

# Use tesla-control to send command
sendBLECommand() {
  vin=$1
  command=$2
  commandDescription=$3

  # Prepare for calling tesla-control
  export TESLA_VIN=$vin
  export TESLA_KEY_FILE=$KEYS_DIR/${vin}_private.pem
  export TESLA_KEY_NAME=$KEYS_DIR/${vin}_private.pem

  # Retry loop
  max_retries=5
  for sendCommandCount in $(seq $max_retries); do

    log_notice "sendBLECommand: Attempt $sendCommandCount/${max_retries} sending $commandDescription to vin:$vin command:$command"

    # Get presence and awake status via body-controller-state
    set +e
    bcs_json=$(timeout -k 1 -s SIGKILL $TC_KILL_TIMEOUT /usr/bin/tesla-control -ble -vin $vin -command-timeout ${TC_CMD_TIMEOUT}s -connect-timeout ${TC_CON_TIMEOUT}s body-controller-state 2>&1)
    EXIT_VALUE=$?
    set -e
    wait

    # If exit code is 137 then the tesla-control process had to be killed
    if [ $EXIT_VALUE -eq 137 ]; then
      log_warning "sendBLECommand (BCS): tesla_control process was killed. This may indicate that the bluetooth adapter is struggling to keep up with the rate of commands"
      log_warning "See https://github.com/tesla-local-control/tesla_ble_mqtt_core/issues/142"

    # If non zero, car is not contactable by bluetooth
    elif [ $EXIT_VALUE -ne 0 ]; then
      log_info "Car is not responding to bluetooth, it's probably away VIN:$vin"
      # Publish to MQTT presence_bc sensor. TODO: Set awake sensor to Unknown via MQTT availability
      stateMQTTpub $vin 'false' 'binary_sensor/presence_bc'

    else
      # Car has responded
      log_debug "Car has responded to bluetooth, it is present. VIN:$vin"
      stateMQTTpub $vin 'true' 'binary_sensor/presence_bc'

      # Check if awake or asleep from the body-controller-state response
      rqdValue=$(echo $bcs_json | jq -e '.vehicleSleepStatus')
      EXIT_VALUE=$?
      if [ $EXIT_VALUE -ne 0 ] || [ "$rqdValue" != "\"VEHICLE_SLEEP_STATUS_AWAKE\"" ]; then
        log_info "Car is present but asleep VIN:$vin. Attempting to wake it"

        stateMQTTpub $vin 'false' 'binary_sensor/awake'

        # Send wake command
        set +e
        timeout -k 1 -s SIGKILL $TC_KILL_TIMEOUT tesla-control -ble -command-timeout ${TC_CMD_TIMEOUT}s -connect-timeout ${TC_CON_TIMEOUT}s -domain vcsec wake
        EXIT_STATUS=$?
        set -e
        wait
        # If exit code is 137 then the tesla-control process had to be killed
        if [ $EXIT_STATUS -eq 137 ]; then
          log_warning "sendBLECommand (wake): tesla_control process was killed. This may indicate that the bluetooth adapter is struggling to keep up with the rate of commands"
          log_warning "See https://github.com/tesla-local-control/tesla_ble_mqtt_core/issues/142"
        fi
        sleep 7

      else
        log_info "Car is present and awake VIN:$vin, sending command"
        stateMQTTpub $vin 'true' 'binary_sensor/awake'

        # Send command to car
        set +e
        TESLACTRLOUT=$(timeout -k 1 -s SIGKILL $TC_KILL_TIMEOUT /usr/bin/tesla-control -ble -command-timeout ${TC_CMD_TIMEOUT}s -connect-timeout ${TC_CON_TIMEOUT}s $command 2>&1)
        EXIT_STATUS=$?
        set -e
        wait

        # If exit code is 137 then the tesla-control process had to be killed
        if [ $EXIT_STATUS -eq 137 ]; then
          log_warning "sendBLECommand (cmd): tesla_control process was killed. This may indicate that the bluetooth adapter is struggling to keep up with the rate of commands"
          log_warning "See https://github.com/tesla-local-control/tesla_ble_mqtt_core/issues/142"

        elif [ $EXIT_STATUS -eq 0 ]; then
          log_debug "sendBLECommand; $TESLACTRLOUT"
          log_info "Command $command was successfully delivered to vin:$vin"

          if [ $IMMEDIATE_UPDATE == "true" ] && [ $(echo $command | wc -w) -eq 2 ] && [ "${command%% *}" != "state" ]; then
            case "${command%% *}" in
            charging)
              stateTopic=switch/charge_enable_request
              value=${command##* }
              ;;
            climate)
              stateTopic=switch/is_climate_on
              value=${command##* }
              ;;
            sentry-mode)
              stateTopic=switch/sentry_mode
              value=${command##* }
              ;;
            steering-wheel-heater)
              stateTopic=switch/steering_wheel_heater
              value=${command##* }
              ;;
            charge-port)
              stateTopic=cover/charge_port_door_open
              value=${command##* }
              ;;
            trunk)
              stateTopic=cover/rear_trunk
              value=${command##* }
              ;;
            windows)
              stateTopic=cover/windows
              value=${command##* }
              ;;
            charging-set-amps)
              stateTopic=number/charge_current_request
              value=${command##* }
              ;;
            charging-set-limit)
              stateTopic=number/charge_limit_soc
              value=${command##* }
              ;;
            charging-set-amps-override)
              stateTopic=number/charge_current_request
              value=${command##* }
              ;;
            climate-set-temp)
              stateTopic=number/driver_temp_setting
              value=${command##* }
              ;;
            heater-seat-front-left)
              stateTopic=select/seat_heater_left
              value=${command##* }
              ;;
            heater-seat-front-right)
              stateTopic=select/seat_heater_right
              value=${command##* }
              ;;
            heater-seat-rear-left)
              stateTopic=select/seat_heater_rear_left
              value=${command##* }
              ;;
            heater-seat-rear-right)
              stateTopic=select/seat_heater_rear_right
              value=${command##* }
              ;;
            door_lock)
              stateTopic=binary_sensor/door_lock
              value=${command##* }
              ;;
            door_lock)
              stateTopic=binary_sensor/door_lock
              value=${command##* }
              ;;
            *)
              stateTopic=""
              value=""
              ;;
            esac
            if [ -z $stateTopic ]; then
              log_warning "No state_topic found for command $command for vin:$vin"
            else
              log_warning "Automatically updating state_topic: $stateTopic to value: $value for command: $command for vin:$vin"
            fi
          fi
          return 0

        elif [[ "$TESLACTRLOUT" == *"car could not execute command"* ]]; then
          log_warning "sendBLECommand; $TESLACTRLOUT"
          log_warning "Skipping command $command to vin:$vin, not retrying"
          return 10

        elif [[ "$TESLACTRLOUT" == *"context deadline exceeded"* ]]; then
          log_warning "teslaCtrlSendCommand; $TESLACTRLOUT"
          log_warning "Vehicle might be asleep, though it shouldn't be as it was previously awake"

        else
          log_error "tesla-control send command:$command to vin:$vin failed exit status $EXIT_STATUS"
          log_error "sendBLECommand; $TESLACTRLOUT"

        fi

      fi

    fi

    log_notice "sendBLECommand; Retrying...."

  done

  # Max retries
  log_warning "sendBLECommand; max retries unsuccessfully trying to send command $command to $vin"
  return 99
}

# Original function is deprecated. Now call sendBLECommand instead
teslaCtrlSendCommand() {
  sendBLECommand "$@"
}

#   teslaCtrlSendCommand. Deprecated
#teslaCtrlSendCommand() {
#  # Process in case of nested call (autowake)
#  if [ $# -eq 4 ]; then
#    log_debug "teslaCtrlSendCommand; Nested call: in. Set callMode and copy internal variables"
#    vin_previous=$vin
#    command_previous=$command
#    commandDescription_previous=$commandDescription
#    callMode="nested"
#  else
#    log_debug "teslaCtrlSendCommand; Standard call: in."
#    callMode="standard"
#  fi
#  # Set internal variables
#  vin=$1
#  command=$2
#  commandDescription=$3
#
#  # Prepare for calling tesla-control
#  export TESLA_VIN=$vin
#  export TESLA_KEY_FILE=$KEYS_DIR/${vin}_private.pem
#  export TESLA_KEY_NAME=$KEYS_DIR/${vin}_private.pem
#  # shellcheck disable=SC2016
#  TESLA_CONTROL_CMD='/usr/bin/tesla-control -ble -command-timeout ${TC_CMD_TIMEOUT}s -connect-timeout ${TC_CON_TIMEOUT}s $command 2>&1'
#
#  # Retry loop
#  max_retries=5
#  for sendCommandCount in $(seq $max_retries); do
#
#    log_notice "Attempt $sendCommandCount/${max_retries} sending $commandDescription to vin:$vin command:$command"
#    set +e
#    teslaCtrlOut=$(eval $TESLA_CONTROL_CMD)
#    EXIT_STATUS=$?
#    set -e
#    if [ $EXIT_STATUS -eq 0 ]; then
#      log_debug "teslaCtrlSendCommand; $teslaCtrlOut"
#      log_info "Command $command was successfully delivered to vin:$vin"
#      # Finalize in case of nested call (autowake)
#      if [[ "$callMode" == "nested" ]]; then
#        log_debug "teslaCtrlSendCommand; Nested call: out. Set callMode back to standard and revert internal variables"
#        vin=$vin_previous
#        command=$command_previous
#        commandDescription=$commandDescription_previous
#        callMode="standard"
#      else
#        log_debug "teslaCtrlSendCommand; Standard call: out."
#      fi
#      return 0
#    else
#      if [[ "$teslaCtrlOut" == *"car could not execute command"* ]]; then
#        log_warning "teslaCtrlSendCommand; $teslaCtrlOut"
#        log_warning "Skipping command $command to vin:$vin"
#        return 10
#      elif [[ "$teslaCtrlOut" == *"context deadline exceeded"* ]]; then
#        # TODO check that this situation appears only once (or few)
#        # to avoid getting into a loop if we cannot wake the car
#        # if this happens the "else" will never be triggered and the command will never exit
#        # it would be possible to parse the return code of teslaCtrlSendCommand to check that wake succeeded
#        log_debug "teslaCtrlSendCommand; txt deadline exc. - IN"
#        log_warning "teslaCtrlSendCommand; $teslaCtrlOut"
#        log_warning "Vehicle might be asleep"
#        log_notice "Trying to wake up car then launch the command again"
#        teslaCtrlSendCommand $vin "-domain vcsec wake" "Wake up vehicule" "internal"
#        log_debug "teslaCtrlSendCommand; txt deadline exc. - OUT"
#      else
#        log_error "tesla-control send command:$command to vin:$vin failed exit status $EXIT_STATUS."
#        log_error "teslaCtrlSendCommand; $teslaCtrlOut"
#        # Don't continue if we've reached max retries
#        [ $max_retries -eq $sendCommandCount ] &&
#          return 15
#        log_notice "teslaCtrlSendCommand; Retrying in $BLE_CMD_RETRY_DELAY seconds"
#      fi
#      sleep $BLE_CMD_RETRY_DELAY
#    fi
#  done
#
#  # Unreachable
#  return 99
#}

###
teslaCtrlSendKey() {
  vin=$1

  export TESLA_VIN=$vin
  # shellcheck disable=SC2016
  TESLA_ADD_KEY_CMD='timeout -k 1 -s SIGKILL 60 /usr/bin/tesla-control -ble -command-timeout 20s add-key-request $KEYS_DIR/${vin}_public.pem owner cloud_key 2>&1'

  log_info "Trying to deploy the public key to vin:$vin"

  max_retries=5
  for sendKeyCount in $(seq $max_retries); do
    log_notice "Attempt $sendKeyCount/${max_retries} to delivery the public key to vin $vin"
    set +e
    teslaCtrlOut=$(eval $TESLA_ADD_KEY_CMD)
    EXIT_STATUS=$?
    set -e
    wait

    # If exit code is 137 then the tesla-control process had to be killed
    if [ $EXIT_STATUS -eq 137 ]; then
      log_warning "poll_state: tesla_control process was killed. This may indicate that the bluetooth adapter is struggling to keep up with the rate of commands"
      log_warning "See https://github.com/tesla-local-control/tesla_ble_mqtt_core/issues/142"

    elif [ $EXIT_STATUS -eq 0 ]; then
      log_debug "teslaCtrlSendKey; $teslaCtrlOut"
      log_warning "KEY DELIVERED; IN YOUR CAR, CHECK THE CAR's CENTRAL SCREEN AND ACCEPT THE KEY USING YOUR NFC CARD"
      return 0
    else
      log_error "teslaCtrlSendKey; $teslaCtrlOut"
      log_error "Could not send the key; Is the car awake and sufficiently close to the bluetooth adapter?"
      # Don't continue if we've reached max retries
      [ $max_retries -eq $sendKeyCount ] &&
        return 15
      log_notice "teslaCtrlSendKey; Retrying..."
    fi
  done
  return 1
}

###
##
#   Is the car awake?
##
###
pingVehicle() {
  vin=$1

  log_debug "pingVehicle; entering vin:$vin"

  if teslaCtrlSendCommand $vin ping "Ping vehicle"; then
    log_debug "pingVehicle; ping vehicle succeeded vin:$vin"
    ret=0
  else
    log_debug "pingVehicle; Failed to ping vehicle vin:$vin"
    ret=2
  fi

  log_debug "pingVehicle; leaving vin:$vin return:$ret"

  return $ret

}

###
##
#   Loop for 5 minutes for key to be accepted
##
###
acceptKeyConfirmationLoop() {
  vin=$1
  log_debug "acceptKeyConfirmationLoop; entering vin:$vin"

  acceptKeyConfirmationLoopSeconds=300
  acceptKeyExpireTime=$(($(date +%s) + acceptKeyConfirmationLoopSeconds))

  log_info "acceptKeyConfirmationLoop; check if key was accepted by sending a ping command vin:$vin"
  # Retry loop
  # shellcheck disable=SC1073
  while [ "$(date +%s)" -lt $acceptKeyExpireTime ]; do
    if pingVehicle $vin; then
      log_info "acceptKeyConfirmationLoop; congratulation, the public key has been  accepted vin:$vin"
      log_debug "touch $KEYS_DIR/${vin}_pubkey_accepted"
      touch $KEYS_DIR/${vin}_pubkey_accepted
      log_debug "acceptKeyConfirmationLoop; leaving vin:$vin ret:0"
      return 0
    else
      log_notice "acceptKeyConfirmationLoop; sleeping 5 seconds before retrying key vin:$vin"
      sleep 5
    fi
  done
  log_debug "acceptKeyConfirmationLoop; leaving vin:$vin ret:1"
  return 1
}

###
##
#    Send the key to the car then check if it was accepted
##
###
deployKeyMain() {
  vin=$1

  log_debug "deployKeyMain; calling teslaCtrlSendKey()"

  if ! teslaCtrlSendKey $vin; then
    log_debug "deployKeyMain; key was not delivered"
    return 1
  fi

  log_debug "deployKeyMain; calling acceptKeyConfirmationLoop()"
  if acceptKeyConfirmationLoop $vin; then
    log_info "Setting up Home Assistant device's panel"
    setupPanelMain $vin
  else
    log_debug "deployKeyMain; key was not accepted"
    return 1
  fi

}

###
##
#   Tesla VIN to BLE Local Name
##
###
function vinToBLEln() {
  vin=$1
  ble_ln=""

  # BLE Local Name
  ble_ln="S$(echo -n ${vin} | sha1sum | cut -c 1-16)C"

  echo $ble_ln

}
