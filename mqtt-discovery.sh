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

  CAR_MODEL=$(echo "$vin" | cut -c 4)

  DEVICE_ID=tesla_ble_${vin}
  DEVICE_NAME=Tesla_BLE_${vin}

  TOPIC_ROOT=tesla_ble/${vin}

  QOS_LEVEL=0

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
  if [ $PRESENCE_DETECTION_TTL -gt 0 ]; then
    log_debug "setupHADevicePanelCardsMain() vin:$vin presence detection enable"
    setupHADevicePresenceSensor $vin

    [ -f $KEYS_DIR/${vin}_presence ] &&
      lastPresenceValue=$(cat $KEYS_DIR/${vin}_presence) &&
      presenceMQTTpub $vin $lastPresenceValue

  fi

  # Newly added car?
  if [ -f $KEYS_DIR/${vin}_pubkey_accepted ]; then
    log_debug "setupHADevicePanelCardsMain() found vehicle with pubkey deployed vin:$vin"
    setupHADeviceDeployKeyButton $vin
    setupHADeviceReGenerateKeysButton $vin
    setupHADeviceInfoBTadapter $vin
    setupHADevicePanelControlCommands $vin
    setupHADevicePanelControlExtendedCommands $vin
  elif [ ! -f $KEYS_DIR/${vin}_private.pem ] && [ ! -f $KEYS_DIR/${vin}_public.pem ]; then

    log_debug "setupHADevicePanelCardsMain() found new vehicle, need to generate keys set vin:$vin"
    # Show button to Generate Keys
    setupHADeviceGenerateKeysButton $vin
    setupHADeviceInfoBTadapter $vin

    # listen_to_mqtt call setupHADeviceDeployKeyButton once the keys are generated

  else
    log_debug "setupHADevicePanelCardsMain() found new vehicle, need to deploy public key vin:$vin"
    setupHADeviceGenerateKeysButton $vin
    setupHADeviceDeployKeyButton $vin
    setupHADeviceInfoBTadapter $vin
  fi

  log_debug "setupHADevicePanelCardsMain() leaving vin:$vin"

}

# Tesla Control Commands (no arguments)
#
# Key,         Model,   mdi:icon, Unique ID,Description
# 0 No Key       *
# 1 Accepted     S
#                3
#                X
#                Y
#                C
teslaControlCommands="\
1,X,autosecure-modelx,car-door-lock,Close falcon-wing doors and lock vehicle
0,*,body-controller-state,download,Fetch limited car state information
1,*,charge-port-close,,Close charge port
1,*,charge-port-open,,Open charge port
1,*,charging-schedule-cancel,Cancel scheduled charge start
1,*,charging-start,flash,Start charging
1,*,charging-stop,flash-off,Stop charging
1,*,climate-off,fan-off,Turn off climate control
1,*,climate-on,fan,Turn on climate control
1,*,drive,car-wireless,Remote start car
1,*,flash-lights,lightbulb-on,Flash lights
1,*,frunk-open,,Open car frunk
1,*,honk,bugle,Honk horn
0,*,list-keys,cloud-key,List public keys enrolled on car
1,*,lock,car-door-lock,Lock car
1,*,media-toggle-playback,motion-play,Toggle between play/pause
1,*,ping,check-network,Ping car
1,*,software-update-cancel,close-circle,Cancel pending software update
1,*,software-update-start,update,Start software update after delay
1,C,tonneau-close,shutter,Close Cybertruck tonneau
1,C,tonneau-open,shutter,Open Cybertruck tonneau
1,C,tonneau-stop,shutter,Stop moving Cybertruck tonneau
1,*,trunk-close,,Close car trunk
1,*,trunk-move,,Toggle trunk open/closed
1,*,trunk-open,,Open car trunk
1,*,unlock,lock-open,Unlock car
0,*,wake,hand-wave,Wake up car
1,*,windows-close,window-closed,Close all windows
1,*,windows-vent,window-open,Vent all windows"

generateCommandJson() {
  UNIQUE_ID=$1
  MDI_ICON=$2
  DESCRIPTION="$4"

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
    "icon": "'${MDI_ICON}'",
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
  echo "$teslaControlCommands" | while IFS=, read -r keyState model uniqueID mdiIcon description; do
    if [ $carKeyState -ge $keyState ]; then
      if [ "$model" == "*" ] || [ $CAR_MODEL == $model ]; then
        commandJson=$(generateCommandJson $uniqueID "$mdiIcon" "$description")
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

  log_debug "setupHADevicePanelControlExtendedCommands() entering vin:$vin"
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
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/auto-seat-and-climate/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charge-port",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Charge port",
   "device_class": "door",
   "payload_open": "open",
   "payload_close": "close",
   "payload_stop": null,
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charge-port"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/charge-port/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Charger",
   "device_class": "switch",
   "payload_on": "start",
   "payload_off": "stop",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/charging/config -l

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
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/charging-set-amps/config -l

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
   "name": "Charging Current single",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-amps-override",
   "unit_of_measurement": "A"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/charging-set-amps-override/config -l

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
   "unique_id": "'${DEVICE_ID}'_charging-set-limit",
   "min": "50",
   "max": "100",
   "mode": "slider",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-limit",
   "unit_of_measurement": "%"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/charging-set-limit/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/climate",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Climate",
   "device_class": "switch",
   "payload_on": "on",
   "payload_off": "off",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_climate"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/climate/config -l

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
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/climate-temp/config -l

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
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/select/${DEVICE_ID}/heater-seat-front-left/config -l

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
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/select/${DEVICE_ID}/heater-seat-front-right/config -l

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
   "name": "Sentry Mode",
   "device_class": "switch",
   "payload_on": "on",
   "payload_off": "off",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_sentry-mode"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/sentry-mode/config -l

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
   "payload_on": "on",
   "payload_off": "off",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_steering-wheel-heater"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/steering-wheel-heater/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/trunk",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Trunk",
   "device_class": "door",
   "payload_open": "open",
   "payload_close": "close",
   "payload_stop": null,
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_trunk"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/trunk/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/windows",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Windows",
   "device_class": "awning",
   "payload_open": "vent",
   "payload_close": "close",
   "payload_stop": null,
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_windows"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/windows/config -l

  log_debug "Leaving setupHADevicePanelControlExtendedCommands() vin:$vin"
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
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/generate-keys/config -l

  log_debug "setupHADeviceGenerateKeysButton() leaving vin:$vin"

}

###
##
#   Setup Configuration ReGenerate Keys Button
##
###
function setupHADeviceReGenerateKeysButton() {
  vin=$1

  log_debug "setupHADeviceReGenerateKeysButton() entering vin:$vin"
  configHADeviceEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'"
   },
   "device_class": "update",
   "name": "ReGenerate Keys",
   "payload_press": "generate-keys",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_regenerate-keys",
   "entity_category": "config",
   "sw_version": "'${SW_VERSION}'"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/regenerate-keys/config -l

  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble_${vin}/generate-keys/config -n

  log_debug "setupHADeviceReGenerateKeysButton() leaving vin:$vin"

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
   "icon": "mdi:car-connected",
   "name": "Presence",
   "qos": "1",
   "unique_id": "'${DEVICE_ID}'_presence"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/presence/config -l

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
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/deploy-key/config -l

  log_debug "setupHADeviceDeployKeyButton() leaving vin:$vin"

}

###
##
#   Setup Info Bluetooth Adapter
##
###
function setupHADeviceInfoBTadapter() {
  vin=$1

  log_debug "setupHADeviceInfoBTadapter() entering vin:$vin"
  configHADeviceEnvVars $vin

  # TODO TEPORARILY - To be removed
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble_${vin}/scan-bleln-macaddr/config -n

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
   "name": "Info Bluetooth Adapter",
   "payload_press": "info-bt-adapter",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_info-bt-adapter",
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/info-bt-adapter/config -l

  log_debug "setupHADeviceInfoBTadapter() leaving vin:$vin"

}

###
##
#   Setup Device's Panel Cards for all VINS
##
###
setupHADeviceAllVINsLoop() {

  # Setup or skip HA auto discovery & Discard old MQTT messages
  for vin in $VIN_LIST; do

    # IF HA backend is enable, setup HA Auto Discover
    if [ "$ENABLE_HA_FEATURES" == "true" ]; then
      log_debug "setupHADeviceAllVINsLoop; calling setupHADevicePanelCardsMain() $vin"
      setupHADevicePanelCardsMain $vin
    else
      log_info "setupHADeviceAllVINsLoop; HA backend is disable, skipping setup for HA Auto Discovery"
    fi
  done

  # Discard /config messages
  topic=tesla_ble/$vin/config
  log_notice "setupHADeviceAllVINsLoop; Discarding any unread MQTT messages for topic:$topic"
  eval $MOSQUITTO_SUB_BASE -E -i tesla_ble_mqtt -t $topic
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
  eval $MOSQUITTO_PUB_BASE -t homeassistant/binary_sensor/tesla_ble/presence/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/auto-seat-climate/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-start/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-stop/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/number/tesla_ble/charging-set-amps/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/number/tesla_ble/charging-set-limit/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-off/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-on/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/number/tesla_ble/climate-temp/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/deploy_key/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/flash-lights/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/frunk-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/generate_keys/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/select/tesla_ble/heated_seat_left/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/select/tesla_ble/heated_seat_right/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/honk/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/lock/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/unlock/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/tesla_ble/sentry-mode/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/scan_bluetooth/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/tesla_ble/sw-heater/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/wake/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-vent/config -n

  # TODO TEMPORARILY
  if [ -f $KEYS_DIR/private.pem ]; then
    log_notice "Renaming legacy keys"
    mv $KEYS_DIR/private.pem $KEYS_DIR/${vin}_private.pem
    mv $KEYS_DIR/public.pem $KEYS_DIR/${vin}_public.pem
  fi

}

delete_legacies_singles() {
  vin=$1

  log_notice "Deleting single MQTT entities topics"
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-off/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-on/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-start/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-stop/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-vent/config -n

}
