# shellcheck shell=dash
#
# subroutines.sh
#

# Function
send_command() {
  vin=$1
  shift

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
        [ $max_retries -eq $count ] && break
        log_notice "Retrying in $BLE_CMD_RETRY_DELAY seconds"
      fi
      sleep $BLE_CMD_RETRY_DELAY
    fi
  done
}

# Function
# Tesla VIN to BLE Local Name
tesla_vin2ble_ln() {
  vin=$1
  ble_ln=""

  # BLE Local Name
  ble_ln="S$(echo -n ${vin} | sha1sum | cut -c 1-16)C"

  echo $ble_ln

}

# Function
replace_value_at_position() {

  original_list="$1"
  position=$(($2 - 1))
  new_value="$3"

  # Split the list into positional parameters
  set -- $original_list

  # Convert the positional parameters to an array-like format
  i=0
  new_list=""
  for word in "$@"; do
    if [ $i -eq $position ]; then
      new_list="$new_list $new_value"
    else
      new_list="$new_list $word"
    fi
    i=$((i + 1))
  done

  # Remove leading space
  new_list=${new_list# }

  # Print the new list
  echo "$new_list"
}

# Function
check_presence() {
  TYPE="$1" # BLE MAC, LN
  MATCH="$2"

  CURRENT_TIME_EPOCH=$(date +%s)

  if echo "${BLTCTL_OUT}" | grep -Eq "$MATCH"; then
    log_info "VIN $VIN $TYPE $MATCH presence detected"

    if [ $CURRENT_TIME_EPOCH -ge $PRESENCE_EXPIRE_TIME ]; then
      log_info "VIN $VIN $MATCH TTL expired, refresh MQTT topic presence ON"
      set +e
      # We need a function for mosquitto_pub w/ retry
      MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m ON 2>&1)
      EXIT_STATUS=$?
      set -e
      [ $EXIT_STATUS -ne 0 ] &&
        log_error "$(MQTT_OUT)" &&
        return
      log_info "mqtt topic $MQTT_TOPIC succesfully updated to ON"
    fi

    # Update presence expire time
    EPOCH_EXPIRE_TIME=$((CURRENT_TIME_EPOCH + PRESENCE_DETECTION_TTL))
    log_debug "VIN $VIN $MATCH update presence expire time to $EPOCH_EXPIRE_TIME"
    PRESENCE_EXPIRE_TIME_LIST=$(replace_value_at_position "$PRESENCE_EXPIRE_TIME_LIST" \
      $position $EPOCH_EXPIRE_TIME)
    # END if MATCH
  else
    log_notice "VIN $VIN $TYPE $MATCH presence not detected"
    if [ $CURRENT_TIME_EPOCH -ge $PRESENCE_EXPIRE_TIME ]; then
      log_info "VIN $VIN $TYPE $MATCH presence not detected, setting presence OFF"
      set +e
      MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m OFF 2>&1)
      EXIT_STATUS=$?
      set -e
      [ $EXIT_STATUS -ne 0 ] &&
        log_error "$MQTT_OUT" &&
        return
      log_info "mqtt topic $MQTT_TOPIC succesfully updated to OFF"
    else
      log_info "VIN $VIN $TYPE $MATCH presence not expired"
    fi # END if expired time
  fi   # END if ! MATCH
}

# Function
bluetoothctl_read() {

  # Read BLE data from bluetoothctl or an input file
  if [ -z $BLECTL_FILE_INPUT ]; then
    log_debug "Launching bluetoothctl to check for BLE presence"
    BLECTL_TIMEOUT=11
    set +e
    BLTCTL_OUT=$(bluetoothctl --timeout $BLECTL_TIMEOUT scan on 2>&1 | grep -v DEL)
    set -e
  else
    # Read from file, great for testing w/ no Bluetooth adapter
    # When reading from a file, the logic reads a continous section:
    #   - randomly pick a start line (startLine)
    #   - randomly pick maximum number of line to read (nPick between 0 and nPickMax)
    [ ! -f $BLECTL_FILE_INPUT ] &&
      log_fatal "blectl input file $BLECTL_FILE_INPUT not found" &&
      exit 30

    log_debug "Reading BLE presence data from file $BLECTL_FILE_INPUT"
    nPickMin=0  # min number of lines to pick
    nPickMax=35 # max number of lines to pick
    finputTotalLines=$(wc -l <"$BLECTL_FILE_INPUT")
    # nPick to be within the file line count and the nPickMax
    nPick=$((RANDOM % ((finputTotalLines < nPickMax ? \
      finputTotalLines : nPickMax) - nPickMin + 1) + nPickMin))
    startLine=$((RANDOM % (finputTotalLines - nPick + 1) + 1)) # Random starting line

    # Extract nPick lines starting from line startLine
    BLTCTL_OUT=$(sed -n "${startLine},$((startLine + nPick - 1))p" "$BLECTL_FILE_INPUT")
  fi
  log_debug "${BLTCTL_OUT}"
}

# Function
listen_to_ble() {
  n_vins=$1

  while :; do
    bluetoothctl_read

    for position in $(seq $n_vins); do
      set -- $BLE_LN_LIST
      BLE_LN=$(eval "echo \$${position}")
      set -- $BLE_MAC_LIST
      BLE_MAC=$(eval "echo \$${position}")
      set -- $PRESENCE_EXPIRE_TIME_LIST
      PRESENCE_EXPIRE_TIME=$(eval "echo \$${position}")
      set -- $VIN_LIST
      VIN=$(eval "echo \$${position}")

      MQTT_TOPIC="tesla_ble/$VIN/binary_sensor/presence"

      # Check the presence using both MAC Addr and BLE Local Name
      check_presence "BLE MAC & LN" "($BLE_MAC|$BLE_LN)"

    done
    sleep $PRESENCE_DETECTION_LOOP_DELAY
  done
}

# Function
send_key() {
  vin=$1

  max_retries=5
  for count in $(seq $max_retries); do
    echo "Attempt $count/${max_retries}"
    log_notice "Sending key to vin $vin, attempt $count/${max_retries}"
    set +e
    tesla-control -ble -vin $vin add-key-request /share/tesla_ble_mqtt/${vin}_public.pem owner cloud_key
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_notice "KEY SENT TO VEHICLE: PLEASE CHECK YOU TESLA'S SCREEN AND ACCEPT WITH YOUR CARD"
      break
    else
      log_notice "COULD NOT SEND THE KEY. Is the car awake and sufficiently close to the bluetooth device?"
      sleep $BLE_CMD_RETRY_DELAY
    fi
  done
}

# Function
delete_legacies() {
  vin=$1

  log_notice "Deleting Legacy MQTT Topics"
  eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/tesla_ble/sw-heater/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/tesla_ble/sentry-mode/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/select/tesla_ble/heated_seat_left/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/select/tesla_ble/heated_seat_right/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/binary_sensor/tesla_ble/presence/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/number/tesla_ble/charging-set-amps/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/number/tesla_ble/charging-set-limit/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/number/tesla_ble/climate-temp/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/generate_keys/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/deploy_key/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/scan_bluetooth/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/wake/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/flash-lights/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/honk/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/lock/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/unlock/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/auto-seat-climate/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-on/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-off/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/frunk-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-start/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-stop/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-vent/config -n

  if [ -f /share/tesla_ble_mqtt/private.pem ]; then
    log_notice "Renaming legacy keys"
    mv /share/tesla_ble_mqtt/private.pem /share/tesla_ble_mqtt/${vin}_private.pem
    mv /share/tesla_ble_mqtt/public.pem /share/tesla_ble_mqtt/${vin}_public.pem
  fi

}

### scanBLEforMACaddr
##
#   Uses BLE Local Name derived from the VIN to match a MAC addr in the output
##  of the command bluetoothctl "devices" and "scan on"
###
scanBLEforMACaddr() {
  # copied from legacy "scan_bluetooth" function. To decide if still relevant
  # note there is this PR https://github.com/tesla-local-control/tesla-local-control-addon/pull/32
  # quite old, but has the principles for auto populating the BLE MAC Address with only the VIN
  vin=$1

  mac_regex='([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'

  ble_ln=$(tesla_vin2ble_ln $vin)

  log_info "Looking for vin:$vin in the BLE cache that matches ble_ln:$ble_ln"
  if ! bltctl_out=$(bluetoothctl --timeout 2 devices | grep $ble_ln | grep -Eo $mac_regex); then
    log_notice "Couldn't find a match in the cache for ble_ln:$ble_ln for vin:$vin"
    # Look for a BLE adverstisement matching ble_ln
    log_notice "Scanning (10 seconds) for BLE advertisement that matches ble_ln:$ble_ln for vin:$vin"
    if ! bltctl_out=$(bluetoothctl --timeout 10 "scan on" | grep $ble_ln | grep -Eo $mac_regex); then
      log_notice "Couldn't find a BLE advertisement for ble_ln:$ble_ln vin:$vin"
      return 1
    fi
  fi
  echo $bltctl_out
  return 0
}
