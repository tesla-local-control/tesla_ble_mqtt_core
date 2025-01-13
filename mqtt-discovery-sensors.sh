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
   "state_topic": "'${TOPIC_ROOT}'/sensor/charger_voltage",
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
   "icon": "mdi:sine-wave",
   "name": "Charger Voltage",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "voltage",
   "unit_of_measurement": "V",
   "suggested_display_precision": "0",
   "unique_id": "'${DEVICE_ID}'_charger_voltage",
   "enabled_by_default": "false"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charger_voltage/config -l

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
   "state_topic": "'${TOPIC_ROOT}'/sensor/charge_range_added",
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
   "icon": "mdi:map-marker-distance",
   "name": "Charge Range Added",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "distance",
   "unit_of_measurement": "mi",
   "suggested_display_precision": "0",
   "unique_id": "'${DEVICE_ID}'_charge_range_added"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charge_range_added/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/sensor/charge_speed",
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
   "icon": "mdi:speedometer",
   "name": "Charge Speed",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "speed",
   "unit_of_measurement": "mph",
   "suggested_display_precision": "0",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_charge_speed"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charge_speed/config -l

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
  "icon": "mdi:thermometer-lines",
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
    "icon": "mdi:thermometer",
    "name": "Outside Temp",
    "qos": "'${QOS_LEVEL}'",
    "device_class": "temperature",
    "unit_of_measurement": "°C",
    "suggested_display_precision": "1",   
    "unique_id": "'${DEVICE_ID}'_outside_temp"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/outside_temp/config -l

  echo '{
    "state_topic": "'${TOPIC_ROOT}'/sensor/passenger_temp",
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
    "name": "Passenger Temp Setting",
    "qos": "'${QOS_LEVEL}'",
    "device_class": "temperature",
    "unit_of_measurement": "°C",
    "suggested_display_precision": "1",   
    "unique_id": "'${DEVICE_ID}'_passenger_temp",
    "enabled_by_default": "false"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/passenger_temp/config -l

  echo '{
    "state_topic": "'${TOPIC_ROOT}'/sensor/charge_cable",
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
    "icon": "mdi:cable-data",
    "name": "Charge Cable",
    "qos": "'${QOS_LEVEL}'",
    "unique_id": "'${DEVICE_ID}'_charge_cable"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/charge_cable/config -l

  echo '{
    "state_topic": "'${TOPIC_ROOT}'/sensor/odometer",
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
    "icon": "mdi:counter",
    "name": "Odometer",
    "qos": "'${QOS_LEVEL}'",
    "unique_id": "'${DEVICE_ID}'_odometer"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/sensor/${DEVICE_ID}/odometer/config -l

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
   "name": "Battery Heater",
   "payload_on": "true",
   "payload_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_battery_heater_on"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/battery_heater_on/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/frunk_open",
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
   "icon": "mdi:car-select",
   "name": "Front Trunk",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "door",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_frunk_open"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/frunk_open/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/window_open_driver_front",
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
   "icon": "mdi:car-door",
   "name": "Window Driver Front",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "window",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_window_open_df"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/window_open_driver_front/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/window_open_pass_front",
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
   "icon": "mdi:car-door",
   "name": "Window Passenger Front",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "window",   
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_window_open_pf"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/window_open_pass_front/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/window_open_driver_rear",
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
   "icon": "mdi:car-door",
   "name": "Window Driver Rear",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "window",   
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_window_open_dr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/window_open_driver_rear/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/window_open_pass_rear",
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
   "icon": "mdi:car-door",
   "name": "Window Passenger Rear",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "window",   
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_window_open_pr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/window_open_pass_rear/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/door_open_driver_front",
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
   "icon": "mdi:car-door",
   "name": "Door Driver Front",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "door",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",   
   "unique_id": "'${DEVICE_ID}'_door_open_df"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/door_open_driver_front/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/door_open_pass_front",
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
   "icon": "mdi:car-door",
   "name": "Door Passenger Front",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "door",   
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",   
   "unique_id": "'${DEVICE_ID}'_door_open_pf"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/door_open_pass_front/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/door_open_driver_rear",
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
   "icon": "mdi:car-door",
   "name": "Door Driver Rear",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "door",   
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",   
   "unique_id": "'${DEVICE_ID}'_door_open_dr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/door_open_driver_rear/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/door_open_pass_rear",
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
   "icon": "mdi:car-door",
   "name": "Door Passenger Rear",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "door",   
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",   
   "unique_id": "'${DEVICE_ID}'_door_open_pr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/door_open_pass_rear/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/door_lock",
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
   "icon": "mdi:car-door-lock",
   "name": "Door Lock",
   "payload_on": "true",
   "payload_off": "false",
   "device_class": "lock",   
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_window_open_pr"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/door_lock/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/front_defrost",
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
   "icon": "mdi:car-defrost-front",
   "name": "Front Defroster",
   "payload_on": "true",
   "payload_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_front_defrost"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/front_defrost/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/rear_defrost",
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
   "icon": "mdi:car-defrost-rear",
   "name": "Rear Defroster",
   "payload_on": "true",
   "payload_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_rear_defrost"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/rear_defrost/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/wiper_heater",
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
   "icon": "mdi:car-windshield-outline",
   "name": "Wiper Heater",
   "payload_on": "true",
   "payload_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_wiper_heater"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/wiper_heater/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/mirror_heater",
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
   "icon": "mdi:car-door",
   "name": "Mirror Heater",
   "payload_on": "true",
   "payload_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_mirror_heater"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/mirror_heater/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/awake",
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
   "icon": "mdi:sleep-off",
   "name": "Awake",
   "payload_on": "true",
   "payload_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_awake"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/awake/config -l

  echo '{
   "state_topic": "'${TOPIC_ROOT}'/binary_sensor/presence_bc",
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
   "name": "Presence BC",
   "payload_on": "true",
   "payload_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "device_class": "presence",
   "icon": "mdi:car-connected",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_presence_bc"
  }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/presence_bc/config -l

  # Status is only Disengaged for short time, it gets reengaged soon after even with no charger plugged in. Not useful
  # echo '{
  #  "state_topic": "'${TOPIC_ROOT}'/binary_sensor/charge_port_latch",
  #  "device": {
  #   "identifiers": [
  #   "'${DEVICE_ID}'"
  #   ],
  #   "manufacturer": "tesla-local-control",
  #   "model": "Tesla_BLE",
  #   "name": "'${DEVICE_NAME}'",
  #   "sw_version": "'${SW_VERSION}'"
  #  },
  #  "platform": "binary_sensor",
  #  "icon": "mdi:lock-question",
  #  "name": "Charge Port Latch",
  #  "qos": "'${QOS_LEVEL}'",
  #  "device_class": "lock",
  #  "unique_id": "'${DEVICE_ID}'_charge_port_latch"
  # }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 36 10 -t homeassistant/binary_sensor/${DEVICE_ID}/charge_port_latch/config -l

  log_debug "setupChargeStateSensors() leaving vin:$vin"

}
