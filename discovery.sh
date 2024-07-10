# shellcheck shell=dash
#
# discovery.sh
#
vinLast=""

function setupHAAutoDiscoveryEnvVars() {
  vin=$1

  log_debug "Entering setupHAAutoDiscoveryEnvVars() vin:$vin"

  [ "$vinLast" == "$vin" ] && return
  vinLast=$1

  DEV_ID=tesla_ble_${vin}
  DEV_NAME=Tesla_BLE_${vin}

  TOPIC_ROOT=tesla_ble/${vin}

  log_debug "DEV_ID=$DEV_ID"
  log_debug "DEV_NAME=$DEV_NAME"
  log_debug "TOPIC_ROOT=$TOPIC_ROOT"

  log_debug "Leaving setupHAAutoDiscoveryEnvVars() vin:$vin"

}

function setupHAAutoDiscoveryMain() {

  vin=$1
  keysDir=/share/tesla_ble_mqtt

  log_debug "Entering setupHAAutoDiscoveryMain() vin:$vin"

  setupHAAutoDiscoveryEnvVars $vin

  # If detection is enable, show presence
  if [ $PRESENCE_DETECTION_TTL -gt 0 ] && [ -n "$BLE_MAC_LIST" ]; then
    log_debug "setupHAAutoDiscoveryMain() vin:$vin presence detection enable"
    setupHAPresence $vin
  fi

  # Newly added car?
  if [ ! -f $keysDir/${vin}_private.pem ] && [ ! -f $keysDir/${vin}_public.pem ]; then

    log_debug "setupHAAutoDiscoveryMain() vin:$vin newly added car, adding Generate Key menu"
    # Show button to Generate Keys
    setupHAGenerateKeys $vin

    # listen_to_mqtt call setupHADeployKey once the keys are generated

  else
    log_debug "setupHAAutoDiscoveryMain() vin:$vin old car"
    setupHADeployKey $vin
    setupHAGenerateKeys $vin
    setupHAAutoDiscovery $vin
  fi

  log_debug "Leaving setupHAAutoDiscoveryMain() vin:$vin"

}

function setupHAAutoDiscovery() {

  log_debug "Entering setupHAAutoDiscovery() vin:$vin"

  vin=$1
  setupHAAutoDiscoveryEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "device_class": "update",
   "name": "Scan Bluetooth",
   "payload_press": "scan-bleln-macaddr",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_scan-bleln-macaddr",
   "entity_category": "diagnostic"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/scan-bleln-macaddr/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Wake Car",
   "payload_press": "wake",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_wake"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/wake/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Flash Lights",
   "payload_press": "flash-lights",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_flash-lights"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/flash-lights/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Honk",
   "payload_press": "honk",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_honk"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/honk/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Lock Car",
   "payload_press": "lock",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_lock"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/lock/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Unlock Car",
   "payload_press": "unlock",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_unlock"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/unlock/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/auto-seat-and-climate",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Auto Seat & Climate",
   "payload_press": "auto-seat-and-climate",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_auto_seat-climate"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/auto-seat-and-climate/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Climate Off",
   "payload_press": "climate-off",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_climate-off"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/climate-off/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Climate On",
   "payload_press": "climate-on",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_climate-on"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/climate-on/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Open Trunk",
   "payload_press": "trunk-open",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_trunk-open"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/trunk-open/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Close Trunk",
   "payload_press": "trunk-close",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_trunk-close"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/trunk-close/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Open Frunk",
   "payload_press": "frunk-open",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_frunk-open"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/frunk-open/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Start Charging",
   "payload_press": "charging-start",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charging-start"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charging-start/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Stop Charging",
   "payload_press": "charging-stop",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charging-stop"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charging-stop/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Open Charge Port",
   "payload_press": "charge-port-open",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charge-port-open"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charge-port-open/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Close Charge Port",
   "payload_press": "charge-port-close",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charge-port-close"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charge-port-close/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Close Windows",
   "payload_press": "windows-close",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_windows-close"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/windows-close/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Vent Windows",
   "payload_press": "windows-vent",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_windows-vent"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/windows-vent/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-amps",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Charging Current",
   "unique_id": "'${DEV_ID}'_charging-set-amps",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "unit_of_measurement": "A",
   "qos": 1,
   "icon": "mdi:current-ac"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/charging-set-amps/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-amps-override",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Charging Current",
   "unique_id": "'${DEV_ID}'_charging-set-amps-override",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "unit_of_measurement": "A",
   "qos": 1,
   "icon": "mdi:current-ac",
   "entity_category": "diagnostic"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/charging-set-amps-override/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-limit",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Charging Limit",
   "unique_id": "'${DEV_ID}'_charging-set-limit",
   "min": "0",
   "max": "100",
   "mode": "slider",
   "unit_of_measurement": "%",
   "qos": 1,
   "icon": "mdi:battery-90"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/charging-set-limit/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/climate-set-temp",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Climate Temp",
   "unique_id": "'${DEV_ID}'_climate-set-temp",
   "min": "5",
   "max": "40",
   "mode": "slider",
   "unit_of_measurement": "°C",
   "qos": 1,
   "icon": "mdi:temperature"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/climate-temp/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/steering-wheel-heater",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Steering Wheel Heater",
   "device_class": "switch",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_steering-wheel-heater"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/${DEV_ID}/steering-wheel-heater/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/sentry-mode",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Sentry Mode",
   "device_class": "switch",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_sentry-mode"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/${DEV_ID}/sentry-mode/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heater-seat-front-left",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Heated Seat Front Left",
   "options": ["off", "low", "medium", "high"],
   "qos": 1,
   "icon": "mdi:car-seat-heater",
   "unique_id": "'${DEV_ID}'_heater-seat-front-left"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/select/${DEV_ID}/heater-seat-front-left/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heater-seat-front-right",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "name": "Heated Seat Front Right",
   "options": ["off", "low", "medium", "high"],
   "qos": 1,
   "icon": "mdi:car-seat-heater",
   "unique_id": "'${DEV_ID}'_heater-seat-front-right"
   }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/select/${DEV_ID}/heater-seat-front-right/config -l

  log_debug "Leaving setupHAAutoDiscovery() vin:$vin"
}

setupHAGenerateKeys() {
  log_debug "Entering setupHAGenerateKeys() vin:$vin"

  vin=$1
  setupHAAutoDiscoveryEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "device_class": "update",
   "name": "Generate Keys",
   "payload_press": "generate-keys",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_generate-keys",
   "entity_category": "config",
   "sw_version": "'${SW_VERSION}'"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/generate-keys/config -l

  log_debug "Leaving setupHAGenerateKeys() vin:$vin"

}

# Basic Setup when keys haven't been generated yet
function setupHAPresence {
  log_debug "Entering setupHAPresence() vin:$vin"

  vin=$1
  setupHAAutoDiscoveryEnvVars $vin

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/presence",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "device_class": "presence",
   "name": "Presence",
   "unique_id": "'${DEV_ID}'_presence",
   "sw_version": "'${SW_VERSION}'"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/binary_sensor/${DEV_ID}/presence/config -l

  log_debug "Leaving setupHAPresence() vin:$vin"

}

function setupHADeployKey() {

  log_debug "Entering setupHADeployKey() vin:$vin"
  vin=$1
  setupHAAutoDiscoveryEnvVars $vin

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "device_class": "update",
   "name": "Deploy Key",
   "payload_press": "deploy-key",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_deploy-key",
   "entity_category": "config",
   "sw_version": "'${SW_VERSION}'"
  }' | sed ':a;N;$!ba;s/\n//g' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/deploy-key/config -l

  log_debug "Leaving setupHADeployKey() vin:$vin"

}
