# shellcheck shell=dash
#
# discovery.sh
#

###
##
#
##
###
LastVIN=""
function configHADeviceEnvVars() {
  vin=$1

  [ "$LastVIN" == "$vin" ] &&
    log_debug "configHADeviceEnvVars() same LastVIN:$vin" &&
    return

  log_debug "configHADeviceEnvVars() entering vin:$vin"

  LastVIN=$1

  CAR_MODEL=${vin:3:1}

  DEVICE_ID=tesla_ble_${vin}
  DEVICE_NAME=Tesla_BLE_${vin}

  TOPIC_ROOT=tesla_ble/${vin}

  QOS_LEVEL=1

  log_debug "DEVICE_ID=$DEVICE_ID"
  log_debug "DEVICE_NAME=$DEVICE_NAME"
  log_debug "TOPIC_ROOT=$TOPIC_ROOT"
  log_debug "configHADeviceEnvVars() leaving vin:$vin"

}

###
##
#   setupHADevicePanelCardsMain
##
###
function setupHADevicePanelCardsMain() {
  vin=$1

  log_debug "setupHADevicePanelCardsMain() entering vin:$vin"
  configHADeviceEnvVars $vin

  # If detection is enable, show presence
  if [ $PRESENCE_DETECTION_TTL -gt 0 ] && [ -n "$BLE_MAC_LIST" ]; then
    log_debug "setupHADevicePanelCardsMain() vin:$vin presence detection enable"
    setupHADevicePresenceSensor $vin
  fi

  # Newly added car?
  if [ -f $KEYS_DIR/${vin}_pubkey_accepted ]; then
    log_debug "setupHADevicePanelCardsMain() found vehicle with pubkey deployed vin:$vin"
    setupHADeviceDeployKeyButton $vin
    setupHADeviceGenerateKeysButton $vin
    setupHADevicePanelControlCommands $vin 1
    setupHADevicePanelControlExtendedCommands $vin
    setupHADeviceScanBLElnButton $vin
  elif [ ! -f $KEYS_DIR/${vin}_private.pem ] && [ ! -f $KEYS_DIR/${vin}_public.pem ]; then

    log_debug "setupHADevicePanelCardsMain() found new vehicle, need to generate keys set vin:$vin"
    # Show button to Generate Keys
    setupHADeviceGenerateKeysButton $vin
    setupHADeviceScanBLElnButton $vin
    setupHADevicePanelControlCommands $vin 0

    # listen_to_mqtt call setupHADeviceDeployKeyButton once the keys are generated

  else
    log_debug "setupHADevicePanelCardsMain() found new vehicle, need to deploy public key vin:$vin"
    setupHADeviceDeployKeyButton $vin
    setupHADeviceGenerateKeysButton $vin
    setupHADeviceScanBLElnButton $vin
    setupHADevicePanelControlCommands $vin 0
  fi

  log_debug "setupHADevicePanelCardsMain() leaving vin:$vin"

}

# Tesla Control Commands (no arguments)
#
# Key,         Model,   Unique ID,Description
# 0 No Key       *
# 1 Accepted     S
#                3
#                X
#                Y
#                C
teslaControlCommands="\
1,X,autosecure-modelx,Close falcon-wing doors and lock vehicle
0,*,body-controller-state,Fetch limited car state information
1,*,charge-port-close,Close charge port
1,*,charge-port-open,Open charge port
1,*,charging-schedule-cancel,Cancel scheduled charge start
1,*,charging-start,Start charging
1,*,charging-stop,Stop charging
1,*,climate-off,Turn off climate control
1,*,climate-on,Turn on climate control
1,*,drive,Remote start car
1,*,flash-lights,Flash lights
1,*,frunk-open,Open car frunk
1,*,honk,Honk horn
0,*,list-keys,List public keys enrolled on car
1,*,lock,Lock car
1,*,media-toggle-playback,Toggle between play/pause
1,*,ping,Ping car
1,*,software-update-cancel,Cancel pending software update
1,*,software-update-start,Start software update after delay
1,*,tonneau-close,Close Cybertruck tonneau
1,C,tonneau-open,Open Cybertruck tonneau
1,C,tonneau-stop,Stop moving Cybertruck tonneau
1,*,trunk-close,Close car trunk
1,*,trunk-move,Toggle trunk open/closed
1,*,trunk-open,Open car trunk
1,*,unlock,Unlock car
0,*,wake,Wake up car
1,*,windows-close,Close all windows
1,*,windows-vent,Vent all windows"


# Function to process each command
processCommandList() {
    local keyState="$1"
    local model="$2"
    local uniqueID="$3"
    local description="$4"
    echo "Processing ID: $uniqueID with Description: $description"
    # Your processing code here
}


generateCommandJson() {
  UNIQUE_ID=$1
  DESCRIPTION="$2"

  PAYLOAD=$UNIQUE_ID

  # Using sed, output single line JSON
  echo '{
    "command_topic": "'${TOPIC_ROOT}'/command",
    "device": {
      "identifiers": [
      "'${DEVICE_ID}'"
      ],
      "manufacturer": "tesla-local-control",
      "model": "Tesla_BLE",
      "name": "'${DEVICE_NAME}'",
      "sw_version": "'${SW_VERSION}'"
    },
    "name": "'${DESCRIPTION}'",
    "payload_press": "'${PAYLOAD}'",
    "qos": "'${QOS_LEVEL}'",
    "unique_id": "'${DEVICE_ID}'_'${UNIQUE_ID}'"
  }' | sed ':a;N;$!ba;s/\n//g'
}


###
##
#   setupHADevicePanelControlCommands
##
###
function setupHADevicePanelControlCommands() {
  vin=$1
  carKeyState=$2

  configHADeviceEnvVars $vin

  # Read and process each line from the teslaControlCommands string
  echo "$teslaControlCommands" | while IFS=, read -r keyState model uniqueID description; do
    processCommandList "keyState" "model" "$uniqueID" "$description"
    if [ $carKeyState -ge $keyState ]; then
      if [ "$model" == "*" ] || [ $CAR_MODEL == $model ]; then
        commandJson=$(generateCommandJson $uniqueID "$description")
        log_debug "$commandJson"
        echo $commandJson | retryMQTTpub -t homeassistant/button/${DEVICE_ID}/$uniqueID/config -l
      else
        log_debug "Skipping; car model:$model description:$description"
      fi
    else
      log_debug "Skipping; key not accepted description:$description"
    fi
  done

}

###
##
#   setupHADevicePanelControlExtendedCommands
##
###
function setupHADevicePanelControlExtendedCommands() {
  vin=$1

  log_debug "setupHADeviceControlsCard() entering vin:$vin"
  configHADeviceEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/auto-seat-and-climate",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Auto Seat & Climate",
   "payload_press": "auto-seat-and-climate",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_auto_seat-climate"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/button/${DEVICE_ID}/auto-seat-and-climate/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-amps",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "icon": "mdi:current-ac",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "name": "Charging Current",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-amps",
   "unit_of_measurement": "A"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/number/${DEVICE_ID}/charging-set-amps/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-amps-override",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "entity_category": "diagnostic"
   "icon": "mdi:current-ac",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "name": "Charging Current",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-amps-override",
   "unit_of_measurement": "A"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/number/${DEVICE_ID}/charging-set-amps-override/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-limit",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "icon": "mdi:battery-90",
   "name": "Charging Limit",
   "unique_id": "'${DEV_ID}'_charging-set-limit",
   "min": "50",
   "max": "100",
   "mode": "slider",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-limit",
   "unit_of_measurement": "%"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/number/${DEVICE_ID}/charging-set-limit/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/climate-set-temp",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "icon": "mdi:temperature",
   "name": "Climate Temp",
   "min": "5",
   "max": "40",
   "mode": "slider",
   "qos": "'${QOS_LEVEL}'",
   "unit_of_measurement": "°C"
   "unique_id": "'${DEVICE_ID}'_climate-set-temp",
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/number/${DEVICE_ID}/climate-temp/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heater-seat-front-left",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "icon": "mdi:car-seat-heater",
   "name": "Heated Seat Front Left",
   "options": ["off", "low", "medium", "high"],
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_heater-seat-front-left"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/select/${DEVICE_ID}/heater-seat-front-left/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heater-seat-front-right",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "icon": "mdi:car-seat-heater",
   "name": "Heated Seat Front Right",
   "options": ["off", "low", "medium", "high"],
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_heater-seat-front-right"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/select/${DEVICE_ID}/heater-seat-front-right/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/sentry-mode",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "device_class": "switch",
   "name": "Sentry Mode",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_sentry-mode"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/switch/${DEVICE_ID}/sentry-mode/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/steering-wheel-heater",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Steering Wheel Heater",
   "device_class": "switch",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_steering-wheel-heater"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/switch/${DEVICE_ID}/steering-wheel-heater/config -l

  log_debug "Leaving setupHADeviceControlsCard() vin:$vin"
}

###
##
#   Setup Configuration Generate Keys Button
##
###
function setupHADeviceGenerateKeysButton() {
  vin=$1

  log_debug "setupHADeviceGenerateKeysButton() entering vin:$vin"
  configHADeviceEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "device_class": "update",
   "entity_category": "config",
   "name": "Generate Keys",
   "payload_press": "generate-keys",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_generate-keys"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/button/${DEVICE_ID}/generate-keys/config -l

  log_debug "setupHADeviceGenerateKeysButton() leaving vin:$vin"

}

###
##
#   Setup Vehicule's Presence Sensor
##
###
function setupHADevicePresenceSensor {
  vin=$1

  log_debug "setupHADevicePresenceSensor() entering vin:$vin"
  configHADeviceEnvVars $vin

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/presence",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "device_class": "presence",
   "name": "Presence",
   "unique_id": "'${DEVICE_ID}'_presence"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/binary_sensor/${DEVICE_ID}/presence/config -l

  log_debug "setupHADevicePresenceSensor() leaving vin:$vin"

}

###
##
#   Setup Configuration Deploy Key Button
##
###
function setupHADeviceDeployKeyButton() {
  vin=$1

  log_debug "setupHADeviceDeployKeyButton() entering vin:$vin"
  configHADeviceEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "device_class": "update",
   "entity_category": "config",
   "name": "Deploy Key",
   "payload_press": "deploy-key",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_deploy-key"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/button/${DEVICE_ID}/deploy-key/config -l

  log_debug "setupHADeviceDeployKeyButton() leaving vin:$vin"

}

###
##
#   Setup Scan BLE LN Button
##
###
function setupHADeviceScanBLElnButton() {
  vin=$1

  log_debug "setupHADeviceScanBLElnButton() entering vin:$vin"
  configHADeviceEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "device_class": "update",
   "entity_category": "diagnostic",
   "name": "Scan Bluetooth",
   "payload_press": "scan-bleln-macaddr",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_scan-bleln-macaddr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub -t homeassistant/button/${DEVICE_ID}/scan-bleln-macaddr/config -l

  log_debug "setupHADeviceScanBLElnButton() leaving vin:$vin"

}

###
##
#   Setup Device's Panel Cards for all VINS
##
###
setupHADeviceAllVINsLoop() {

  discardMessages=$1

  # Setup or skip HA auto discovery & Discard old MQTT messages
  for vin in $VIN_LIST; do

    # IF HA backend is enable, setup HA Auto Discover
    if [ "$ENABLE_HA_FEATURES" == "true" ]; then
      log_debug "Calling setupHADevicePanelCardsMain() $vin"
      setupHADevicePanelCardsMain $vin
    else
      log_info "HA backend is disable, skipping setup for HA Auto Discovery"
    fi

    # Discard or not awaiting messages
    if [ "$discardMessages" = "yes" ]; then
      log_notice "Discarding any unread MQTT messages for $vin"
      eval $MOSQUITTO_SUB_BASE -E -i tesla_ble_mqtt -t tesla_ble_mqtt/$vin/+
    fi
  done
}

###
##
#
##
###
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

  if [ -f $KEYS_DIR/private.pem ]; then
    log_notice "Renaming legacy keys"
    mv $KEYS_DIR/private.pem $KEYS_DIR/${vin}_private.pem
    mv $KEYS_DIR/public.pem $KEYS_DIR/${vin}_public.pem
  fi

}
