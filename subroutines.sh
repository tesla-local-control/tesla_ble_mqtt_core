# shellcheck shell=dash
#
# subroutines.sh
#

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
  BLE_LN="$1"
  BLE_MAC="$2"
  macAddr="$3"

  CURRENT_TIME_EPOCH=$(date +%s)
  MATCH="($BLE_LN|$BLE_MAC)"

  if [ $BLE_MAC == "FF:FF:FF:FF:FF:FF" ]; then
    log_debug "check_presence; looking BLE_MAC for BLE_LN:$BLE_LN"
    if grepOutput=$(echo "${BLTCTL_OUT}" | grep $BLE_LN | tail -1 | grep -Eo $MAC_REGEX); then
      # return value to calling function
      eval "$macAddr=$grepOutput"
      log_info "check_presence; found BLE MAC addr:$grepOutput for BLE_LN:$BLE_LN"
    else
      log_debug "check_presence; did not find BLE MAC addr for BLE_LN:$BLE_LN"
      eval "$macAddr=$BLE_MAC"
    fi
  else
    eval "$macAddr=$BLE_MAC"
  fi

  if echo "${BLTCTL_OUT}" | grep -Eq "$MATCH"; then
    log_info "vin:$VIN ble_ln:$BLE_LN match:$MATCH presence detected"

    if [ $CURRENT_TIME_EPOCH -ge $PRESENCE_EXPIRE_TIME ]; then
      log_info "vin:$VIN ble_ln:$BLE_LN TTL expired, set presence ON"
      set +e
      # We need a function for mosquitto_pub w/ retry
      MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m ON 2>&1)
      EXIT_STATUS=$?
      set -e
      [ $EXIT_STATUS -ne 0 ] &&
        log_error "$(MQTT_OUT)" &&
        return
      log_debug "mqtt topic $MQTT_TOPIC succesfully updated to ON"
      # Update presence expire time
      EPOCH_EXPIRE_TIME=$((CURRENT_TIME_EPOCH + PRESENCE_DETECTION_TTL))
      log_debug "vin:$VIN ble_ln:$BLE_LN update presence expire time to $EPOCH_EXPIRE_TIME"
      PRESENCE_EXPIRE_TIME_LIST=$(replace_value_at_position "$PRESENCE_EXPIRE_TIME_LIST" \
        $position $EPOCH_EXPIRE_TIME)
    fi # END if expire time
  else
    log_debug "vin:$VIN ble_ln:$BLE_LN match:$MATCH presence not detected"
    if [ $CURRENT_TIME_EPOCH -ge $PRESENCE_EXPIRE_TIME ]; then
      log_info "vin:$VIN ble_ln:$BLE_LN presence has expired, setting presence OFF"
      set +e
      MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m OFF 2>&1)
      EXIT_STATUS=$?
      set -e
      [ $EXIT_STATUS -ne 0 ] &&
        log_error "$MQTT_OUT" &&
        return
      log_debug "mqtt topic $MQTT_TOPIC succesfully updated to OFF"
      # Update presence expire time
      EPOCH_EXPIRE_TIME=$((CURRENT_TIME_EPOCH + PRESENCE_DETECTION_TTL))
      log_debug "vin:$VIN ble_ln:$BLE_LN update presence expire time to $EPOCH_EXPIRE_TIME"
      PRESENCE_EXPIRE_TIME_LIST=$(replace_value_at_position "$PRESENCE_EXPIRE_TIME_LIST" \
        $position $EPOCH_EXPIRE_TIME)
    else
      log_info "vin:$VIN ble_ln:$BLE_LN presence not expired"
    fi # END if expire time
  fi   # END if ! MATCH
}

# Function
bluetoothctl_read() {

  # Read BLE data from bluetoothctl or an input file
  if [ -z $BLECTL_FILE_INPUT ]; then
    log_debug "bluetoothctl_read; check presence, launch bluetoothctl power on,devices,scan on"
    set +e
    BLTCTL_OUT=$({
      if [ $BLTCTL_COMMAND_DEVICES == "true" ]; then
        bltctlCommands="power on,devices,scan on"
      else
        bltctlCommands="power on,scan on"
      fi
      IFS=','
      for bltctlCommand in $bltctlCommands; do
        echo "$bltctlCommand"
        sleep 0.2
      done

      # scan for 10 seconds (Tesla adverstisement each ~9s)
      sleep 10

      echo "scan off"
      echo "exit"
    } | bluetoothctl)
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
}

# Function
listen_to_ble() {
  n_vins=$1
  macAddr=""

  while :; do
    bluetoothctl_read

    BLTCTL_COMMAND_DEVICES=false
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

      log_debug "VIN:$VIN"
      log_debug "PRESENCE_EXPIRE_TIME:$PRESENCE_EXPIRE_TIME"

      log_debug "listen_to_ble; calling check_presence() BLE_LN:$BLE_LN BLE_MAC:BLE_MAC"
      check_presence $BLE_LN $BLE_MAC macAddr
      log_debug "listen_to_ble; macAddr:$macAddr BLE_MAC:$BLE_MAC"

      # If BLE_MAC is default value & macAddr is not
      if [ "$macAddr" != "BLE_MAC" ]; then
        # Replace the MAC address for this car in BLE_MAC_LIST
        eval "BLE_MAC_LIST=\$(echo \$BLE_MAC_LIST | awk '{\$${position}=\"$macAddr\"; print}')"
        log_debug "listen_to_ble; BLE_MAC_LIST:$BLE_MAC_LIST"
        [ ! -f $KEYS_DIR/${VIN}_macaddr ] && echo $macAddr >$KEYS_DIR/${VIN}_macaddr
      fi

      # If macAddr is default, on next run request "bltctl devices"
      [ "$macAddr" == "FF:FF:FF:FF:FF:FF" ] && BLTCTL_COMMAND_DEVICES=true

    done
    sleep $PRESENCE_DETECTION_LOOP_DELAY
  done
}

### infoBluetoothAdapter
##
#   Get Bluetooth adapter information for diagnostic
##  Note: scan on in bltctlCommands must be the last command.
###
infoBluetoothAdapter() {

  log_debug "Launching bluetoothctl version,list,mgmt.info,show"
  set +e
  BLTCTL_OUT=$({
    bltctlCommands="version,list,mgmt.info,show"
    IFS=','
    for bltctlCommand in $bltctlCommands; do
      echo "##################################################################"
      echo "$bltctlCommand"
      sleep 0.2
    done

    echo "exit"
  } | bluetoothctl | sed -r 's/\x1b\[[0-9;]*m//g' | grep -Ev '(\[CHG]|\[DEL]|\[NEW]|^  )' | grep -E '(^Version|bluetooth|^Controller|^Advertis|^\t)')
  set -e

  log_notice "\n# INFO BLUETOOTH ADAPTER\n$BLTCTL_OUT\n##################################################################"

  bltctlVersion=$(echo "$BLTCTL_OUT" | grep ^Version | sed -e 's/^Version //g')
  bltctlMinVersion=5.63
  if awk -v n1="$bltctlMinVersion" -v n2="$bltctlVersion" 'BEGIN {exit !(n1 > n2)}'; then
    log_warning "Minimum recommended version of Bluez:$bltctlMinVersion; your system version:$bltctlVersion"
  fi

}
