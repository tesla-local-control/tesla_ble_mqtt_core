#!/bin/ash

send_command() {
 vin=$1
 shift
 for i in $(seq 5); do
  log_notice "Sending command $@ to vin $vin, attempt $i/5"
  set +e
  message=$(tesla-control -vin $vin -ble -key-name /share/tesla_ble_mqtt/${vin}_private.pem -key-file /share/tesla_ble_mqtt/${vin}_private.pem $@ 2>&1)
  EXIT_STATUS=$?
  set -e
  if [ $EXIT_STATUS -eq 0 ]; then
    log_info "tesla-control send command succeeded"
    break
  else
	if [[ $message == *"Failed to execute command: car could not execute command"* ]]; then
	 log_warning $message
	 log_warning "Skipping command $@ to vin $vin"
	 break
	else
     log_error "tesla-control send command failed exit status $EXIT_STATUS."
	 log_error $message
	 log_notice "Retrying in $SEND_CMD_RETRY_DELAY seconds"
	fi
    sleep $SEND_CMD_RETRY_DELAY
  fi
 done
}

listen_to_ble() {
 log_notice "Listening to BLE for presence"
 log_warning "Needs updating for multi-car, only supports TESLA_VIN1 at this time. Doesn't support deprecated TESLA_VIN usage"
 PRESENCE_TIMEOUT=5
 set +e
 bluetoothctl --timeout $PRESENCE_TIMEOUT scan on | grep $BLE_MAC1
 EXIT_STATUS=$?
 set -e
 if [ $EXIT_STATUS -eq 0 ]; then
   echo "$BLE_MAC1 presence detected"
   eval $MOSQUITTO_SUB --nodelay -t tesla_ble_mqtt/$TESLA_VIN1/binary_sensor/presence -m ON
 else
   echo "$BLE_MAC1 presence not detected"
   eval $MOSQUITTO_SUB --nodelay -t tesla_ble_mqtt/$TESLA_VIN1/binary_sensor/presence -m OFF
 fi
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
    sleep $SEND_CMD_RETRY_DELAY
  fi
 done
}

scan_bluetooth(){
  VIN_HASH=`echo -n ${TESLA_VIN} | sha1sum`
  BLE_ADVERT=S${VIN_HASH:0:16}C
  log_notice "Calculating BLE Advert ${BLE_ADVERT} from VIN"
  log_notice "Scanning Bluetooth for $BLE_ADVERT, wait 10 secs"
  bluetoothctl --timeout 10 scan on | grep $BLE_ADVERT
  log_warning "More work needed on this"
}

delete_legacies(){
  log_notice "Deleting Legacy MQTT Topics"
  eval $MOSQUITTO_SUB -t homeassistant/switch/tesla_ble/sw-heater/config -n
  eval $MOSQUITTO_SUB -t homeassistant/switch/tesla_ble/sentry-mode/config -n
  eval $MOSQUITTO_SUB -t homeassistant/select/tesla_ble/heated_seat_left/config -n
  eval $MOSQUITTO_SUB -t homeassistant/select/tesla_ble/heated_seat_right/config -n
  eval $MOSQUITTO_SUB -t homeassistant/binary_sensor/tesla_ble/presence/config -n
  eval $MOSQUITTO_SUB -t homeassistant/number/tesla_ble/charging-set-amps/config -n
  eval $MOSQUITTO_SUB -t homeassistant/number/tesla_ble/charging-set-limit/config -n
  eval $MOSQUITTO_SUB -t homeassistant/number/tesla_ble/climate-temp/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/generate_keys/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/deploy_key/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/scan_bluetooth/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/wake/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/flash-lights/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/honk/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/lock/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/unlock/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/auto-seat-climate/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/climate-on/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/climate-off/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/trunk-open/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/trunk-close/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/frunk-open/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/charging-start/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/charging-stop/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/charge-port-open/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/charge-port-close/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/windows-close/config -n
  eval $MOSQUITTO_SUB -t homeassistant/button/tesla_ble/windows-vent/config -n

  if [ -f /share/tesla_ble_mqtt/private.pem ]; then
    log_notice "Renaming legacy keys"
    mv /share/tesla_ble_mqtt/private.pem /share/tesla_ble_mqtt/${TESLA_VIN1}_private.pem
    mv /share/tesla_ble_mqtt/public.pem /share/tesla_ble_mqtt/${TESLA_VIN1}_public.pem
  fi

}
