#!/bin/ash

send_command() {
  vin=$1
  shift
  for i in $(seq 5); do
    log_notice "Sending command $@ to vin $vin, attempt $i/5"
    set +e
    tesla_ctrl_out=$(tesla-control -vin $vin -ble -key-name /share/tesla_blemqtt/${vin}_private.pem -key-file /share/tesla_ble_mqtt/${vin}_private.pem $@ 2>&1)
    EXIT_STATUS=$?
    set -e
    if [ $EXIT_STATUS -eq 0 ]; then
      log_info "tesla-control send command succeeded"
      break
    else
       if [[ "$tesla_ctrl_out" == *"Failed to execute command: car could not execute command"* ]]; then
        log_error "$tesla_ctrl_out"
        log_notice "Skipping command $@ to vin $vin"
        break
       else
         log_error "tesla-control send command failed exit status $EXIT_STATUS."
         log_info "$tesla_ctrl_out"
         log_notice "Retrying in $BLE_CMD_RETRY_DELAY seconds"
       fi
       sleep $BLE_CMD_RETRY_DELAY
    fi
  done
}


# Tesla VIN to BLE Local Name
tesla_vin2ble_ln() {
  vin=$1
  ble_ln=""

  log_debug "Calculating BLE Local Name for Tesla VIN $vin"
  VIN_HASH="$(echo -n ${vin} | sha1sum)"
  # BLE Local Name
  ble_ln="S${VIN_HASH:0:16}C"
  log_debug "BLE Local Name for Tesla VIN $vin is $ble_ln"

  echo $ble_ln

}


ble_scanning() {
  n_cars={$1:-3}

  # Read BLE data from bluetoothctl or an input file
  if [ -z $BLECTL_FILE_INPUT ]; then
    log_notice "Launching bluetoothctl to check for BLE presence"
    BLECTL_TIMEOUT=11
    set +e
    BLTCTL_OUT=$(bluetoothctl --timeout $BLECTL_TIMEOUT scan on 2>&1 | grep -v DEL)
    set -e
  else
    [ ! -f $BLECTL_FILE_INPUT ] \
      && log_fatal "blectl input file $BLECTL_FILE_INPUT not found" \
      && exit 30
    log_notice "Reading BLE presence data from file $BLECTL_FILE_INPUT"
    nPickMin=0  # min number of lines to pick
    nPickMax=50 # max number of lines to pick
    nPick=$((RANDOM % (total_lines - nPickMax + nPickMin) + nPickMin))
    finputTotalLines=$(wc -l < "$BLECTL_FILE_INPUT")
    startLine=$((RANDOM % (finputTotalLines - nPick + 1) + 1)) # Random starting line

    # Extract nPick lines starting from line startLine
    BLTCTL_OUT=$(sed -n "${startLine},$((startLine + nPick - 1))p" "$BLECTL_FILE_INPUT")
  fi
  log_debug "${BLTCTL_OUT}"

  for count in $(seq $n_cars); do
    BLE_LN=$(eval echo "echo \$BLE_LN${count}")
    BLE_MAC=$(eval "echo \$BLE_MAC${count}")
    PRESENCE_EXPIRE_TIME=$(eval "echo \$PRESENCE_EXPIRE_TIME${count}")
    VIN=$(eval "echo \$VIN${count}")

    MQTT_TOPIC="tesla_ble/$VIN/binary_sensor/presence"

    if echo "$(BLTCTL_OUT)" | grep -q $BLE_MAC; then
      log_info "BLE MAC $BLE_MAC presence detected"
      EPOCH_TIME=$(date +%s)
      # We need a function for mosquitto_pub w/ retry
      if [ $EPOCH_TIMW < $PRESENCE_EXPIRE_TIME ]; then
        log_info "Tesla VIN $VIN ($BLE_MAC) TTL expired, update mqtt topic with presence ON"
        set +e
        MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m ON 2>&1)
        EXIT_CODE=$?
        set -e
        [ $EXIT_CODE -ne 0 ] \
          && log_error "$(MQTT_OUT)" \
          && continue
        log_info "mqtt topic "$MQTT_TOPIC" succesfully updated to ON"

        # Updating Presence Expire Time in Epoch
        EPOCH_TIMW=$(date +%s)
        EPOCH_EXPIRE_TIME=$(expr EPOCH_TIME + $BLE_PRESENCE_TTL)
        PRESENCE_EXPIRE_TIME${count}=$EPOCH_EXPIRE_TIME
        log_debug "Tesla VIN $VIN ($BLE_MAC) update Presence Expire Time to $EPOCH_EXPIRE_TIME"
      else
        log_info "Tesla VIN $VIN ($BLE_MAC) TTL has not expires at $PRESENCE_EXPIRE_TIME"
      fi
    elif echo "$(BLTCTL_OUT)" | grep -q ${BLE_LN}; then
      log_info "BLE_LN $BLE_LN presence detected"
      EPOCH_TIME=$(date +%s)
      # We need a function for mosquitto_pub w/ retry
      if [ $EPOCH_TIMW < $PRESENCE_EXPIRE_TIME ]; then
        log_info "TESLA VIN $VIN ($BLE_MAC) TTL expired, update mqtt topic with presence ON"
        # We need a function for mosquitto_pub w/ retry
        set +e
        MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m ON 2>&1)
        EXIT_CODE=$?
        set -e
        [ $EXIT_CODE -ne 0 ] \
          && log_error "$(MQTT_OUT)" \
          && continue

        # Updating Presence Expire Time in Epoch
        EPOCH_TIMW=$(date +%s)
        EPOCH_EXPIRE_TIME=$(expr EPOCH_TIME + $BLE_PRESENCE_TTL)
        PRESENCE_EXPIRE_TIME${count}=$(expr EPOCH_TIME + $BLE_PRESENCE_TTL)
        log_debug "Tesla VIN $VIN $BLE_MAC update Presence Expire Time to $EPOCH_EXPIRE_TIME"
      else
        log_info "Tesla VIN $VIN ($BLE_MAC) TTL has not expires at $PRESENCE_EXPIRE_TIME"
      fi
    else
      log_info "Tesla VIN $VIN and MAC $BLE_MAC presence not detected, setting presence OFF"
      set +e
      MQTT_OUT=$(eval $MOSQUITTO_PUB_BASE --nodelay -t "$MQTT_TOPIC" -m OFF 2>&1)
      set -e
      [ $EXIT_CODE -ne 0 ] \
        && log_error "$(MQTT_OUT)" \
        && continue
      log_info "mqtt topic "$MQTT_TOPIC" succesfully updated to OFF"
    fi
  done
}



send_key() {
  vin=$1

  for i in $(seq 5); do
    echo "Attempt $i/5"
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



delete_legacies(){
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
