#
# discovery.sh
#

function setup_auto_discovery() {
 vin=$1
 log_notice "Setting up HA auto discovery for vin $vin"

 DEV_ID=tesla_ble_${vin}
 DEV_NAME=Tesla_BLE_${vin}

 TOPIC_ROOT=tesla_ble/${vin}
 SW_VERSION=0.0.10f

 log_debug "DEV_ID=$DEV_ID"
 log_debug "DEV_NAME=$DEV_NAME"
 log_debug "TOPIC_ROOT=$TOPIC_ROOT"

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
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/binary_sensor/${DEV_ID}/presence/config -l

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
   "payload_press": "generate_keys",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_generate_keys",
   "entity_category": "config",
   "sw_version": "'${SW_VERSION}'"
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/generate_keys/config -l

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
   "payload_press": "deploy_key",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_deploy_key",
   "entity_category": "config",
   "sw_version": "'${SW_VERSION}'"
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/deploy_key/config -l

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
   "name": "Scan Bluetooth",
   "payload_press": "scan_bluetooth",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_scan_bluetooth",
   "entity_category": "diagnostic",
   "sw_version": "'${SW_VERSION}'"
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/scan_bluetooth/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Wake Car",
   "payload_press": "wake",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_wake",
   "sw_version": "'${SW_VERSION}'"
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/wake/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Flash Lights",
   "payload_press": "flash-lights",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_flash_lights",
   "sw_version": "'${SW_VERSION}'"
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/flash-lights/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Honk",
   "payload_press": "honk",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_honk",
   "sw_version": "'${SW_VERSION}'"
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/honk/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Lock Car",
   "payload_press": "lock",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_lock",
   "sw_version": "'${SW_VERSION}'"
  }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/lock/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Unlock Car",
   "payload_press": "unlock",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_unlock",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/unlock/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/auto-seat-and-climate",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Auto Seat & Climate",
   "payload_press": "auto-seat-and-climate",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_auto_seat-climate",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/auto-seat-climate/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Climate Off",
   "payload_press": "climate-off",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_climate-off",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/climate-off/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Climate On",
   "payload_press": "climate-on",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_climate-on",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/climate-on/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Open Trunk",
   "payload_press": "trunk-open",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_trunk-open",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/trunk-open/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Close Trunk",
   "payload_press": "trunk-close",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_trunk-close",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/trunk-close/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Open Frunk",
   "payload_press": "frunk-open",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_frunk-open",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/frunk-open/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Start Charging",
   "payload_press": "charging-start",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charging-start",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charging-start/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Stop Charging",
   "payload_press": "charging-stop",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charging-stop",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charging-stop/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Open Charge Port",
   "payload_press": "charge-port-open",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charge-port-open",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charge-port-open/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Close Charge Port",
   "payload_press": "charge-port-close",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_charge-port-close",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/charge-port-close/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Close Windows",
   "payload_press": "windows-close",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_windows-close",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/windows-close/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Vent Windows",
   "payload_press": "windows-vent",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_windows-vent",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/button/${DEV_ID}/windows-vent/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-amps",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Charging Current",
   "unique_id": "'${DEV_ID}'_charging-set-amps",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "unit_of_measurement": "A",
   "qos": 1,
   "icon": "mdi:current-ac",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/charging-set-amps/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-amps-override",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Charging Current",
   "unique_id": "'${DEV_ID}'_charging-set-amps-override",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "unit_of_measurement": "A",
   "qos": 1,
   "icon": "mdi:current-ac",
   "entity_category": "diagnostic",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/charging-set-amps-override/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-limit",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Charging Limit",
   "unique_id": "'${DEV_ID}'_charging-set-limit",
   "min": "0",
   "max": "100",
   "mode": "slider",
   "unit_of_measurement": "%",
   "qos": 1,
   "icon": "mdi:battery-90",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/charging-set-limit/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/climate-set-temp",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Climate Temp",
   "unique_id": "'${DEV_ID}'_climate-set-temp",
   "min": "5",
   "max": "40",
   "mode": "slider",
   "unit_of_measurement": "°C",
   "qos": 1,
   "icon": "mdi:temperature",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/number/${DEV_ID}/climate-temp/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/sw-heater",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Steering Wheel Heater",
   "device_class": "switch",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_sw_heater",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/${DEV_ID}/sw-heater/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/sentry-mode",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Sentry Mode",
   "device_class": "switch",
   "qos": 1,
   "unique_id": "'${DEV_ID}'_sentry-mode",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/${DEV_ID}/sentry-mode/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heated_seat_left",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Heated Seat Left",
   "options": ["off", "low", "medium", "high"],
   "qos": 1,
   "icon": "mdi:car-seat-heater",
   "unique_id": "'${DEV_ID}'_heated_seat_left",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/select/${DEV_ID}/heated_seat_left/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heated_seat_right",
   "device": {
    "identifiers": [
    "'${DEV_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEV_NAME}'"
   },
   "name": "Heated Seat Right",
   "options": ["off", "low", "medium", "high"],
   "qos": 1,
   "icon": "mdi:car-seat-heater",
   "unique_id": "'${DEV_ID}'_heated_seat_right",
   "sw_version": "'${SW_VERSION}'"
   }' | eval $MOSQUITTO_PUB_BASE -t homeassistant/select/${DEV_ID}/heated_seat_right/config -l

}
