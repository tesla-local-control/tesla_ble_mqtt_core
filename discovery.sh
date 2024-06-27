#!/bin/ash

setup_auto_discovery() {
 log_notice "Setting up HA auto discovery for $1"

 TOPIC_ROOT=tesla_ble_mqtt/$1
 TOPIC_ID=$TOPIC_ROOT

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/binary_sensor/${TOPIC_ID}/presence/config -m \
  '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/presence",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "device_class": "presence",
   "name": "Presence",
   "unique_id": "'${TOPIC_ID}'_presence"
  }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/generate_keys/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "device_class": "update",
   "name": "Generate Keys",
   "payload_press": "generate_keys",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_generate_keys"
  }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/deploy_key/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "device_class": "update",
   "name": "Deploy Key",
   "payload_press": "deploy_key",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_deploy_key"
  }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/scan_bluetooth/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/config",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "device_class": "update",
   "name": "Scan Bluetooth",
   "payload_press": "scan_bluetooth",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_scan_bluetooth"
  }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/wake/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Wake Car",
   "payload_press": "wake",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_wake"
  }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/flash-lights/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Flash Lights",
   "payload_press": "flash-lights",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_flash_lights"
  }'

  mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/honk/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Honk",
   "payload_press": "honk",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_honk"
  }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/lock/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Lock Car",
   "payload_press": "lock",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_lock"
  }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/unlock/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Unlock Car",
   "payload_press": "unlock",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_unlock"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/auto-seat-climate/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/auto-seat-and-climate",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Auto Seat & Climate",
   "payload_press": "auto-seat-and-climate",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_auto_seat-climate"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/climate-off/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Climate Off",
   "payload_press": "climate-off",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_climate-off"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/climate-on/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Climate On",
   "payload_press": "climate-on",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_climate-on"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/trunk-open/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Open Trunk",
   "payload_press": "trunk-open",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_trunk-open"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/trunk-close/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Close Trunk",
   "payload_press": "trunk-close",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_trunk-close"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/frunk-open/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Open Frunk",
   "payload_press": "frunk-open",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_frunk-open"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/charging-start/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Start Charging",
   "payload_press": "charging-start",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_charging-start"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/charging-stop/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Stop Charging",
   "payload_press": "charging-stop",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_charging-stop"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/charge-port-open/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Open Charge Port",
   "payload_press": "charge-port-open",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_charge-port-open"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/charge-port-close/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Close Charge Port",
   "payload_press": "charge-port-close",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_charge-port-close"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/windows-close/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Close Windows",
   "payload_press": "windows-close",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_windows-close"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/button/${TOPIC_ID}/windows-vent/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/command",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Vent Windows",
   "payload_press": "windows-vent",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_windows-vent"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/number/${TOPIC_ID}/charging-set-amps/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/charging-amps",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Charging Current",
   "unique_id": "'${TOPIC_ID}'_charging-set-amps",
   "min": "0",
   "max": "48",
   "mode": "slider",
   "unit_of_measurement": "A",
   "qos": 1,
   "icon": "mdi:current-ac"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/number/${TOPIC_ID}/charging-set-limit/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-limit",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Charging Limit",
   "unique_id": "'${TOPIC_ID}'_charging-set-limit",
   "min": "0",
   "max": "100",
   "mode": "slider",
   "unit_of_measurement": "%",
   "qos": 1,
   "icon": "mdi:battery-90"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/number/${TOPIC_ID}/climate-temp/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/climate-set-temp",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Climate Temp",
   "unique_id": "'${TOPIC_ID}'_climate-set-temp",
   "min": "5",
   "max": "40",
   "mode": "slider",
   "unit_of_measurement": "°C",
   "qos": 1,
   "icon": "mdi:temperature"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/switch/${TOPIC_ID}/sw-heater/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/sw-heater",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Steering Wheel Heater",
   "device_class": "switch",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_sw_heater"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/switch/${TOPIC_ID}/sentry-mode/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/sentry-mode",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Sentry Mode",
   "device_class": "switch",
   "qos": 1,
   "unique_id": "'${TOPIC_ID}'_sentry-mode"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/select/${TOPIC_ID}/heated_seat_left/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/heated_seat_left",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Heated Seat Left",
   "options": ["off", "low", "medium", "high"],
   "qos": 1,
   "icon": "mdi:car-seat-heater",
   "unique_id": "'${TOPIC_ID}'_heated_seat_left"
   }'

 mosquitto_pub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" -t homeassistant/select/${TOPIC_ID}/heated_seat_right/config -m \
  '{
   "command_topic": "'${TOPIC_ROOT}'/heated_seat_right",
   "device": {
    "identifiers": ["tesla_ble_mqtt"],
    "manufacturer": "tesla_ble_mqtt",
    "model": "Tesla BLE",
    "name": "Tesla_BLE_MQTT"
   },
   "name": "Heated Seat Right",
   "options": ["off", "low", "medium", "high"],
   "qos": 1,
   "icon": "mdi:car-seat-heater",
   "unique_id": "'${TOPIC_ID}'_heated_seat_right"
   }'

 }

