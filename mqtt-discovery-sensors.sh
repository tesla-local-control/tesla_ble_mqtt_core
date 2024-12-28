# shellcheck shell=dash
#
# mqtt-discovery-sensors.sh
#

# Presence
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

# Charge State Sensors
function setupChargeStateSensors {
  vin=$1

  log_debug "setupChargeStateSensors() entering vin:$vin"
  configHADeviceEnvVars $vin

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/number/charge_state",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "device_class": "battery",
   "platform": "number",
   "icon": "mdi:battery-80",
   "name": "Battery Level",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charge_state"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/number/${DEVICE_ID}/charge_state/config -l

  log_debug "setupChargeStateSensors() leaving vin:$vin"

}