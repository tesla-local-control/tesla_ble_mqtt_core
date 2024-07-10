# shellcheck shell=dash
#
# tesla.sh
#


sendKeyMain() {
  vin=$1

  sendkeyLoop()

}



# Function
send_key() {
  vin=$1

  TESLA_ADD_KEY_CMD='/usr/bin/tesla-control -vin $vin -ble add-key-request /share/tesla_ble_mqtt/${vin}_public.pem owner cloud_key 2>&1'

  max_retries=5
  for sendKeyCount in $(seq $max_retries); do
    log_notice "Attempt $sendKeyCount/${max_retries} to delivery the public key to vin $vin"
    set +e
    tesla_ctrl_out=$(eval $TESLA_ADD_KEY_CMD)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_notice "$tesla_ctrl_out"
      log_warning "KEY DELIVERED; IN YOUR CAR, CHECK THE LCD SCREEN AND ACCEPT THE KEY USING YOUR NFC CARD"
      return 0
    else
      log_error "$tesla_ctrl_out"
      log_error "Could not send the key; Is the car awake and sufficiently close to the bluetooth adapter?"
      sleep $BLE_CMD_RETRY_DELAY
    fi
  done
  return 1
}


###
##
#   tesla-control-main-loop
##
###
tesla-control-main() {
  vin=$1
  cmd=$2
  shift; shift
  args="$@"

  TESLA_CONTROL_CMD='/usr/bin/tesla-control -vin $vin -ble -key-name /share/tesla_blemqtt/${vin}_private.pem -key-file /share/tesla_ble_mqtt/${vin}_private.pem $@ 2>&1'


  # add a retry loop
  max_retries=5
  for tesla_ctrl_count in $(seq $max_retries); do

    log_notice "Sending command $* to vin $vin, attempt $tesla_ctrl_count/${max_retries}"
    log_notice "Sending to vin:$vin command:$cmd $@, attempt $tesla_ctrl_count/${max_retries}""
    set +e
    # shellcheck disable=SC2068
    tesla_ctrl_out=$(eval $TESLA_CONTROL_CMD)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_info "tesla-control command was successfully delivered to vin:$vin"
      break
    else
      if [[ "$tesla_ctrl_out" == *"Failed to execute command: car could not execute command"* ]]; then
        log_warning "$tesla_ctrl_out"
        log_warning "Skipping command $* to vin:$vin"
        break
      else
        log_error "tesla-control send command failed exit status $EXIT_STATUS."
        log_error "$tesla_ctrl_out"
        # Don't continue if we've reached max retries
        [ $max_retries -eq $tesla_ctrl_count ] && break
        log_notice "Retrying in $BLE_CMD_RETRY_DELAY seconds"
      fi
      sleep $BLE_CMD_RETRY_DELAY
    fi
  done

}



###
##
#
##
###
function tesla-control-main() {
  vin=$1
  shift

  TESLA_CONTROL_CMD='/usr/bin/tesla-control -vin $vin -ble -key-name /share/tesla_blemqtt/${vin}_private.pem -key-file /share/tesla_ble_mqtt/${vin}_private.pem $@ 2>&1'

  max_retries=5
  for count in $(seq $max_retries); do
    log_notice "Sending command $* to vin $vin, attempt $count/${max_retries}"
    set +e
    # shellcheck disable=SC2068
    tesla_ctrl_out=$(tesla-control -vin $vin -ble -key-name /share/tesla_blemqtt/${vin}_private.pem -key-file /share/tesla_ble_mqtt/${vin}_private.pem $@ 2>&1)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_info "tesla-control send command succeeded"
      break
    else
      if [[ "$tesla_ctrl_out" == *"Failed to execute command: car could not execute command"* ]]; then
        log_warning "$tesla_ctrl_out"
        log_warning "Skipping command $* to vin $vin"
        break
      else
        log_error "tesla-control send command failed exit status $EXIT_STATUS."
        log_error "$tesla_ctrl_out"
        # Don't continue if we've reached max retries
        [ $max_retries -eq $tesla_ctrl_count ] && break
        log_notice "Retrying in $BLE_CMD_RETRY_DELAY seconds"
      fi
      sleep $BLE_CMD_RETRY_DELAY
    fi
  done
}



###
##
#   Tesla VIN to BLE Local Name
##
###
function tesla_vin2ble_ln() {
  vin=$1
  ble_ln=""

  # BLE Local Name
  ble_ln="S$(echo -n ${vin} | sha1sum | cut -c 1-16)C"

  echo $ble_ln

}
