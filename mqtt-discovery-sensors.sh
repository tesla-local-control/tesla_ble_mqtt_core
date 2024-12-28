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
   "state_topic": "'${TOPIC_ROOT}'/sensor/charge_state",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:battery-80",
   "name": "Battery Level",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "battery",
   "unit_of_measurement": "%",
   "suggested_display_precision": "0",
   "unique_id": "'${DEVICE_ID}'_charge_state"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charge_state/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/battery_range",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:ruler-square-compass",
   "name": "Battery Range",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "distance",
   "unit_of_measurement": "mi",
   "suggested_display_precision": "0",
   "unique_id": "'${DEVICE_ID}'_battery_range"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/battery_range/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/charger_power",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:battery-arrow-up",
   "name": "Charger Power",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "power",
   "unit_of_measurement": "kW",
   "suggested_display_precision": "1",   
   "unique_id": "'${DEVICE_ID}'_charger_power"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charger_power/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/charger_actual_current",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:current-ac",
   "name": "Charger Actual Current",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "current",
   "unit_of_measurement": "A",
   "suggested_display_precision": "0",   
   "unique_id": "'${DEVICE_ID}'_charger_actual_current"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charger_actual_current/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/charge_energy_added",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:battery-plus-variant",
   "name": "Charge Energy Added",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "energy",
   "unit_of_measurement": "kWh",
   "suggested_display_precision": "1",   
   "unique_id": "'${DEVICE_ID}'_charge_energy_added"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charge_energy_added/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/tpms_pressure_fl",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:car-tire-alert",
   "name": "Tyre Pressure Front Left",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "pressure",
   "unit_of_measurement": "bar",
   "suggested_display_precision": "1",   
   "unique_id": "'${DEVICE_ID}'_tpms_pressure_fl"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/tpms_pressure_fl/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/tpms_pressure_fr",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:car-tire-alert",
   "name": "Tyre Pressure Front Right",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "pressure",
   "unit_of_measurement": "bar",
   "suggested_display_precision": "1",   
   "unique_id": "'${DEVICE_ID}'_tpms_pressure_fr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/tpms_pressure_fr/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/tpms_pressure_rl",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:car-tire-alert",
   "name": "Tyre Pressure Rear Left",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "pressure",
   "unit_of_measurement": "bar",
   "suggested_display_precision": "1",   
   "unique_id": "'${DEVICE_ID}'_tpms_pressure_rl"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/tpms_pressure_rl/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/tpms_pressure_rr",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "sensor",
   "icon": "mdi:car-tire-alert",
   "name": "Tyre Pressure Rear Right",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "pressure",
   "unit_of_measurement": "bar",
   "suggested_display_precision": "1",   
   "unique_id": "'${DEVICE_ID}'_tpms_pressure_rr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/tpms_pressure_rr/config -l

  if [ $TEMPERATURE_UNIT_FAHRENHEIT = "true" ]; then
    echo '{
    "state_topic": "'${TOPIC_ROOT}'/sensor/inside_temp",
    "device": {
     "identifiers": [
     "'${DEVICE_ID}'"
     ],
     "manufacturer": "tesla-local-control",
     "model": "Tesla_BLE",
     "name": "'${DEVICE_NAME}'",
     "sw_version": "'${SW_VERSION}'"
    },
    "platform": "sensor",
    "icon": "mdi:thermometer",
    "name": "Inside Temp",
    "qos": "'${QOS_LEVEL}'",
    "device_class": "temperature",
    "unit_of_measurement": "°C",
    "suggested_display_precision": "1",   
    "unique_id": "'${DEVICE_ID}'_inside_temp"
    }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/inside_temp/config -l

    echo '{
    "state_topic": "'${TOPIC_ROOT}'/sensor/outside_temp",
    "device": {
     "identifiers": [
     "'${DEVICE_ID}'"
        ],
     "manufacturer": "tesla-local-control",
     "model": "Tesla_BLE",
     "name": "'${DEVICE_NAME}'",
     "sw_version": "'${SW_VERSION}'"
    },
    "platform": "sensor",
    "icon": "mdi:thermometer-lines",
    "name": "Outside Temp",
    "qos": "'${QOS_LEVEL}'",
    "device_class": "temperature",
    "unit_of_measurement": "°C",
    "suggested_display_precision": "1",   
    "unique_id": "'${DEVICE_ID}'_outside_temp"
    }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/outside_temp/config -l      

  else
     echo '{
    "state_topic": "'${TOPIC_ROOT}'/sensor/inside_temp",
    "device": {
     "identifiers": [
     "'${DEVICE_ID}'"
     ],
     "manufacturer": "tesla-local-control",
     "model": "Tesla_BLE",
     "name": "'${DEVICE_NAME}'",
     "sw_version": "'${SW_VERSION}'"
    },
    "platform": "sensor",
    "icon": "mdi:thermometer",
    "name": "Inside Temp",
    "qos": "'${QOS_LEVEL}'",
    "device_class": "temperature",
    "unit_of_measurement": "°F",
    "suggested_display_precision": "1",   
    "unique_id": "'${DEVICE_ID}'_inside_temp"
    }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/inside_temp/config -l

    echo '{
    "state_topic": "'${TOPIC_ROOT}'/sensor/outside_temp",
    "device": {
     "identifiers": [
     "'${DEVICE_ID}'"
        ],
     "manufacturer": "tesla-local-control",
     "model": "Tesla_BLE",
     "name": "'${DEVICE_NAME}'",
     "sw_version": "'${SW_VERSION}'"
    },
    "platform": "sensor",
    "icon": "mdi:thermometer-lines",
    "name": "Outside Temp",
    "qos": "'${QOS_LEVEL}'",
    "device_class": "temperature",
    "unit_of_measurement": "°F",
    "suggested_display_precision": "1",   
    "unique_id": "'${DEVICE_ID}'_outside_temp"
    }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/outside_temp/config -l     
  fi

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/battery_heater_on",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "binary_sensor",
   "icon": "mdi:heat-wave",
   "name": "Battery Heater On",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "heat", 
   "unique_id": "'${DEVICE_ID}'_battery_heater_on"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/battery_heater_on/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/charge_port_latch",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "platform": "binary_sensor",
   "icon": "mdi:lock-question",
   "name": "Charge Port Latch",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "lock", 
   "unique_id": "'${DEVICE_ID}'_charge_port_latch"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/charge_port_latch/config -l

  log_debug "setupChargeStateSensors() leaving vin:$vin"

}