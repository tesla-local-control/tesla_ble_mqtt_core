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

  QOS_LEVEL=1

  log_debug "DEVICE_ID=$DEVICE_ID"
  log_debug "DEVICE_NAME=$DEVICE_NAME"
  log_debug "TOPIC_ROOT=$TOPIC_ROOT"
  log_debug "configHADeviceEnvVars() leaving vin:$vin"

}

###
##
#   setupPanelMain
##
###
function setupPanelMain() {
  vin=$1

  log_debug "setupPanelMain() entering vin:$vin"
  configHADeviceEnvVars $vin

  # If detection is enable, show presence
  if [ $PRESENCE_DETECTION_TTL -gt 0 ]; then
    log_debug "setupPanelMain() vin:$vin presence detection enable"
    setupPresenceSensor $vin

    [ -f $KEYS_DIR/${vin}_presence ] &&
      lastPresenceValue=$(cat $KEYS_DIR/${vin}_presence) &&
      presenceMQTTpub $vin $lastPresenceValue

  fi

  # Newly added car?
  if [ -f $KEYS_DIR/${vin}_pubkey_accepted ]; then
    log_debug "setupPanelMain() found vehicle with pubkey deployed vin:$vin"
    setupDeployKeyButton $vin
    setupReGenerateKeysButton $vin
    setupDiagnostic $vin
    setupButtonControls $vin 1
    setupExtendedControls $vin
  elif [ ! -f $KEYS_DIR/${vin}_private.pem ] && [ ! -f $KEYS_DIR/${vin}_public.pem ]; then

    log_debug "setupPanelMain() found new vehicle, need to generate keys set vin:$vin"
    # Show button to Generate Keys
    setupGenerateKeysButton $vin
    setupDiagnostic $vin
    setupButtonControls $vin 0

    # listen_to_mqtt call setupDeployKeyButton once the keys are generated

  else
    log_debug "setupPanelMain() found new vehicle, need to deploy public key vin:$vin"
    setupGenerateKeysButton $vin
    setupDeployKeyButton $vin
    setupButtonControls $vin 0
    setupDiagnostic $vin
  fi

  log_debug "setupPanelMain() leaving vin:$vin"

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
1,X,autosecure-modelx,mdi:car-door-lock,Close falcon-wing doors and lock vehicle
1,*,auto-seat-and-climate,mdi:fan-auto,Set climate mode to auto
1,*,charging-schedule-cancel,mdi:timer-cancel-outline,Cancel scheduled charge start
1,*,drive,car-wireless,mdi:car-wireless,Remote start car
1,*,flash-lights,mdi:car-light-high,Flash lights
1,*,frunk-open,mdi:car-select,Open car frunk
1,*,honk,mdi:bugle,Honk horn
1,*,lock,mdi:car-door-lock,Lock car
2,*,media-toggle-playback,mdi:motion-play,Toggle between play/pause
1,*,ping,mdi:check-network,Ping car
2,*,software-update-cancel,mdi:close-circle,Cancel pending software update
2,*,software-update-start,mdi:update,Start software update after delay
1,C,tonneau-close,mdi:shutter,Close Cybertruck tonneau
1,C,tonneau-open,mdi:shutter,Open Cybertruck tonneau
1,C,tonneau-stop,mdi:shutter,Stop moving Cybertruck tonneau
1,*,unlock,mdi:lock-open,Unlock car
0,*,wake,mdi:hand-wave,Wake up car"

generateCommandJson() {
  UNIQUE_ID=$1
  MDI_ICON=$2
  DESCRIPTION="$3"

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
#   setupButtonControls
##
###
function setupButtonControls() {
  vin=$1
  carKeyState=$2

  configHADeviceEnvVars $vin

  log_debug "setupButtonControls; vin:$vin carKeyState:$carKeyState"

  # Read and process each line from the teslaControlCommands string
  echo "$teslaControlCommands" | while IFS=, read -r keyState model uniqueID mdiIcon description; do
    if [ $carKeyState -ge $keyState ]; then
      if [ "$model" == "*" ] || [ $CAR_MODEL == $model ]; then
        commandJson=$(generateCommandJson $uniqueID "$mdiIcon" "$description")
        log_debug "$commandJson"
        echo $commandJson | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/$uniqueID/config -l
      else
        log_debug "setupButtonControls; skipping car model:$model description:$description"
      fi
    else
      log_debug "setupButtonControls; skipping no key accepted description:$description"
    fi
  done

}

###
##
#   setupExtendedControls
##
###
function setupExtendedControls() {
  vin=$1

  log_debug "setupExtendedControls() entering vin:$vin"
  configHADeviceEnvVars $vin

  # Switches

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
   "icon": "mdi:flash",
   "name": "Charger",
   "device_class": "switch",
   "payload_on": "start",
   "payload_off": "stop",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/charging/config -l

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
   "icon": "mdi:fan",
   "name": "Climate",
   "device_class": "switch",
   "payload_on": "on",
   "payload_off": "off",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_climate"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/climate/config -l

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
   "icon": "mdi:cctv",
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
   "icon": "mdi:steering",
   "name": "Steering Wheel Heater",
   "device_class": "switch",
   "payload_on": "on",
   "payload_off": "off",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_steering-wheel-heater"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/steering-wheel-heater/config -l

  # Covers

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
   "icon": "mdi:ev-plug-tesla",
   "name": "Charge port",
   "device_class": "door",
   "payload_open": "open",
   "payload_close": "close",
   "payload_stop": null,
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charge-port"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/charge-port/config -l

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
   "icon": "mdi:car-back",
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
   "icon": "mdi:car-door",
   "name": "Windows",
   "device_class": "awning",
   "payload_open": "vent",
   "payload_close": "close",
   "payload_stop": null,
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_windows"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/windows/config -l

  # Number

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
   "icon": "mdi:current-ac",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "name": "Charging Current single",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-amps-override",
   "entity_category": "diagnostic",
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
   "min": "50",
   "max": "100",
   "mode": "slider",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-limit",
   "unit_of_measurement": "%"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/charging-set-limit/config -l

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
   "unique_id": "'${DEVICE_ID}'_climate-set-temp"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/climate-temp/config -l

  # Select

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

  log_debug "Leaving setupExtendedControls() vin:$vin"
}

###
##
#   Setup Configuration Generate Keys Button
##
###
function setupGenerateKeysButton() {
  vin=$1

  log_debug "setupGenerateKeysButton() entering vin:$vin"
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

  log_debug "setupGenerateKeysButton() leaving vin:$vin"

}

###
##
#   Setup Configuration ReGenerate Keys Button
##
###
function setupReGenerateKeysButton() {
  vin=$1

  log_debug "setupReGenerateKeysButton() entering vin:$vin"
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

  # Delete Generate Keys
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble_${vin}/generate-keys/config -n

  log_debug "setupReGenerateKeysButton() leaving vin:$vin"

}

###
##
#   Setup Vehicule's Presence Sensor
##
###
function setupPresenceSensor {
  vin=$1

  log_debug "setupPresenceSensor() entering vin:$vin"
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

  log_debug "setupPresenceSensor() leaving vin:$vin"

}

###
##
#   Setup Configuration Deploy Key Button
##
###
function setupDeployKeyButton() {
  vin=$1

  log_debug "setupDeployKeyButton() entering vin:$vin"
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

  log_debug "setupDeployKeyButton() leaving vin:$vin"

}

###
##
#   Setup Info Bluetooth Adapter
##
###
function setupDiagnostic() {
  vin=$1

  log_debug "setupDiagnostic() entering vin:$vin"
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
    "name": "Car state information",
    "payload_press": "body-controller-state",
    "qos": "'${QOS_LEVEL}'",
    "unique_id": "'${DEVICE_ID}'_body-controller-state"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/body-controller-state/config -l

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
    "unique_id": "'${DEVICE_ID}'_info-bt-adapter"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/info-bt-adapter/config -l

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
   "icon": "mdi:cloud-key",
   "name": "List public keys enrolled on car",
   "entity_category": "diagnostic",
   "payload_press": "list-keys",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_list-keys"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/list-keys/config -l

  log_debug "setupDiagnostic() leaving vin:$vin"

}

###
##
#   Setup Device's Panel Cards for all VINS
##
###
setupHADiscoveryAllVINsMain() {

  # Setup or skip HA auto discovery & Discard old MQTT messages
  for vin in $VIN_LIST; do

    # IF HA backend is enable, setup HA Auto Discover
    if [ "$ENABLE_HA_FEATURES" == "true" ]; then
      log_debug "setupHADiscoveryAllVINsMain; calling setupPanelMain() $vin"
      setupPanelMain $vin
    else
      log_info "setupHADiscoveryAllVINsMain; HA backend is disable, skipping setup for HA Auto Discovery"
    fi
  done

  # Discard /config messages
  topic=tesla_ble/$vin/config
  log_notice "setupHADiscoveryAllVINsMain; Discarding any unread MQTT messages for topic:$topic"
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

  log_notice "delete_legacies; deleting legacy MQTT topics"
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
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble_${vin}/scan-bleln-macaddr/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/tesla_ble/sw-heater/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/wake/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-vent/config -n

  # TODO TEMPORARILY
  if [ -f $KEYS_DIR/private.pem ]; then
    log_notice "delete_legacies; renaming legacy keys"
    mv $KEYS_DIR/private.pem $KEYS_DIR/${vin}_private.pem
    mv $KEYS_DIR/public.pem $KEYS_DIR/${vin}_public.pem
  fi

}

delete_legacies_singles() {
  vin=$1

  log_notice "delete_legacies_singles; deleting legacy single MQTT entities topics"
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-on/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/climate-off/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/trunk-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-start/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charging-stop/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/charge-port-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-vent/config -n

}
