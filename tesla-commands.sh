# shellcheck shell=dash
#
# tesla.sh
#

###
##
#   teslaCtrlSendCommand
##
###
teslaCtrlSendCommand() {
  # Process in case of nested call (autowake)
  if [ $# -eq 4 ]; then
    log_debug "teslaCtrlSendCommand; Nested call: in. Set callMode and copy internal variables"
    vin_previous=$vin
    command_previous=$command
    commandDescription_previous=$commandDescription
    callMode="nested"
  else
    log_debug "teslaCtrlSendCommand; Standard call: in."
    callMode="standard"
  fi
  # Set internal variables
  vin=$1
  command=$2
  commandDescription=$3

  # Prepare for calling tesla-control
  export TESLA_VIN=$vin
  export TESLA_KEY_FILE=$KEYS_DIR/${vin}_private.pem
  export TESLA_KEY_NAME=$KEYS_DIR/${vin}_private.pem
  # shellcheck disable=SC2016
  TESLA_CONTROL_CMD='/usr/bin/tesla-control -ble -command-timeout 20s $command 2>&1'

  # Retry loop
  max_retries=5
  for sendCommandCount in $(seq $max_retries); do

    log_notice "Attempt $sendCommandCount/${max_retries} sending $commandDescription to vin:$vin command:$command"
    set +e
    teslaCtrlOut=$(eval $TESLA_CONTROL_CMD)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_debug "teslaCtrlSendCommand; $teslaCtrlOut"
      log_info "Command $command was successfully delivered to vin:$vin"
      # Finalize in case of nested call (autowake)
      if [[ "$callMode" == "nested" ]]; then
        log_debug "teslaCtrlSendCommand; Nested call: out. Set callMode back to standard and revert internal variables"
        vin=$vin_previous
        command=$command_previous
        commandDescription=$commandDescription_previous
        callMode="standard"
      else
        log_debug "teslaCtrlSendCommand; Standard call: out."
      fi
      return 0
    else
      if [[ "$teslaCtrlOut" == *"car could not execute command"* ]]; then
        log_warning "teslaCtrlSendCommand; $teslaCtrlOut"
        log_warning "Skipping command $command to vin:$vin"
        return 10
      elif [[ "$teslaCtrlOut" == *"context deadline exceeded"* ]]; then
        # TODO check that this situation appears only once (or few)
        # to avoid getting into a loop if we cannot wake the car
        # if this happen the "else" will never be triggered and the command will never exit
        log_debug "teslaCtrlSendCommand; txt deadline exc. - IN"
        log_warning "teslaCtrlSendCommand; $teslaCtrlOut"
        log_warning "Vehicle might be asleep"
        log_notice "Trying to wake up car then launch the command again"
        teslaCtrlSendCommand $vin "-domain vcsec wake" "Wake up vehicule" "internal"
        log_debug "teslaCtrlSendCommand; txt deadline exc. - OUT"
      else
        log_error "tesla-control send command:$command to vin:$vin failed exit status $EXIT_STATUS."
        log_error "teslaCtrlSendCommand; $teslaCtrlOut"
        # Don't continue if we've reached max retries
        [ $max_retries -eq $sendCommandCount ] &&
          return 15
        log_notice "teslaCtrlSendCommand; Retrying in $BLE_CMD_RETRY_DELAY seconds"
      fi
      sleep $BLE_CMD_RETRY_DELAY
    fi
  done

  # Unreachable
  return 99
}

###
##
#
##
###
teslaCtrlSendKey() {
  vin=$1

  export TESLA_VIN=$vin
  # shellcheck disable=SC2016
  TESLA_ADD_KEY_CMD='/usr/bin/tesla-control -ble -command-timeout 20s add-key-request $KEYS_DIR/${vin}_public.pem owner cloud_key 2>&1'

  log_info "Trying to deploy the public key to vin:$vin"

  max_retries=5
  for sendKeyCount in $(seq $max_retries); do
    log_notice "Attempt $sendKeyCount/${max_retries} to delivery the public key to vin $vin"
    set +e
    teslaCtrlOut=$(eval $TESLA_ADD_KEY_CMD)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_debug "teslaCtrlSendKey; $teslaCtrlOut"
      log_warning "KEY DELIVERED; IN YOUR CAR, CHECK THE CAR's CENTRAL SCREEN AND ACCEPT THE KEY USING YOUR NFC CARD"
      return 0
    else
      log_error "teslaCtrlSendKey; $teslaCtrlOut"
      log_error "Could not send the key; Is the car awake and sufficiently close to the bluetooth adapter?"
      # Don't continue if we've reached max retries
      [ $max_retries -eq $sendKeyCount ] &&
        return 15
      log_notice "teslaCtrlSendKey; Retrying in $BLE_CMD_RETRY_DELAY seconds"
      sleep $BLE_CMD_RETRY_DELAY
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

  if teslaCtrlSendCommand $vin ping "Ping vehicule"; then
    log_debug "pingVehicle; ping vehicule succeeded vin:$vin"
    ret=0
  else
    log_debug "pingVehicle; Failed to ping vehicule vin:$vin"
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
