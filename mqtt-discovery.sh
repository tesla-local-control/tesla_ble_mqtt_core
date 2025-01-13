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

  # Setup Charge State Sensors
  setupChargeStateSensors $vin

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
2,*,charging-schedule-cancel,mdi:timer-cancel-outline,Cancel scheduled charge start
1,*,drive,mdi:car-wireless,Remote start car
1,*,flash-lights,mdi:car-light-high,Flash lights
1,*,frunk-open,mdi:car-select,Open car frunk
1,*,honk,mdi:bugle,Honk horn
1,*,lock,mdi:car-door-lock,Lock car
1,*,media-toggle-playback,mdi:motion-play,Toggle between play/pause
2,*,ping,mdi:check-network,Ping car
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
   "state_topic": "'${TOPIC_ROOT}'/switch/charge_enable_request", 
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
   "state_on": "true",
   "state_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/charging/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/climate",
   "state_topic": "'${TOPIC_ROOT}'/switch/is_climate_on", 
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
   "state_on": "true",
   "state_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_climate"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/climate/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/sentry-mode",
   "state_topic": "'${TOPIC_ROOT}'/switch/sentry_mode", 
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
   "state_on": "true",
   "state_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_sentry-mode"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/sentry-mode/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/steering-wheel-heater",
   "state_topic": "'${TOPIC_ROOT}'/switch/steering_wheel_heater",  
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
   "state_on": "true",
   "state_off": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_steering-wheel-heater"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/steering-wheel-heater/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/variables/polling",
   "state_topic": "'${TOPIC_ROOT}'/variables/polling",  
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "icon": "mdi:car-connected",
   "name": "State Polling",
   "device_class": "switch",
   "payload_on": "on",
   "payload_off": "off",
   "state_on": "on",
   "state_off": "off",
   "retain": "true",
   "unique_id": "'${DEVICE_ID}'_polling",
   "entity_category": "diagnostic"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/switch/${DEVICE_ID}/polling/config -l

  # Covers

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charge-port",
   "state_topic": "'${TOPIC_ROOT}'/cover/charge_port_door_open",
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
   "state_open": "true",
   "state_closed": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charge-port"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/charge-port/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/trunk",
   "state_topic": "'${TOPIC_ROOT}'/cover/rear_trunk",
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
   "state_open": "true",
   "state_closed": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_trunk"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/trunk/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/windows",
   "state_topic": "'${TOPIC_ROOT}'/cover/windows",
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
   "state_open": "true",
   "state_closed": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_windows"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/cover/${DEVICE_ID}/windows/config -l

  # Numbers

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-amps",
   "state_topic": "'${TOPIC_ROOT}'/number/charge_current_request",
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
   "max": "'${MAX_CURRENT}'",
   "mode": "slider",
   "name": "Charging Current",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-amps",
   "unit_of_measurement": "A"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/charging-set-amps/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-amps-override",
   "state_topic": "'${TOPIC_ROOT}'/number/charge_current_request",
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
   "max": "'${MAX_CURRENT}'",
   "mode": "slider",
   "name": "Charging Current single",
   "enabled_by_default": "false",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_charging-set-amps-override",
   "entity_category": "diagnostic",
   "unit_of_measurement": "A"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/charging-set-amps-override/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/charging-set-limit",
   "state_topic": "'${TOPIC_ROOT}'/number/charge_limit_soc",
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
      "state_topic": "'${TOPIC_ROOT}'/number/driver_temp_setting",
      "device": {
        "identifiers": [
          "'${DEVICE_ID}'"
        ],
        "manufacturer": "tesla-local-control",
        "model": "Tesla_BLE",
        "name": "'${DEVICE_NAME}'",
        "sw_version": "'${SW_VERSION}'"
      },
      "icon": "mdi:thermometer",
      "name": "Climate Temp",
      "device_class": "temperature",                                                                            
      "unit_of_measurement": "°C", 
      "min": "15",
      "max": "28",
      "mode": "slider",
      "qos": "'${QOS_LEVEL}'",
      "unique_id": "'${DEVICE_ID}'_climate-set-temp"
    }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/climate-temp/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/variables/polling_interval",
   "device": {
    "identifiers": [
    "'${DEVICE_ID}'"
    ],
    "manufacturer": "tesla-local-control",
    "model": "Tesla_BLE",
    "name": "'${DEVICE_NAME}'",
    "sw_version": "'${SW_VERSION}'"
   },
   "icon": "mdi:timer-sync",
   "min": "30",
   "max": "3600",
   "step": "30",
   "mode": "slider",
   "name": "Polling Interval",
   "retain": "true",
   "unique_id": "'${DEVICE_ID}'_polling_interval",
   "entity_category": "diagnostic",
   "unit_of_measurement": "secs"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/number/${DEVICE_ID}/polling_interval/config -l

  # Selects

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heater-seat-front-left",
   "state_topic": "'${TOPIC_ROOT}'/select/seat_heater_left",
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
   "state_topic": "'${TOPIC_ROOT}'/select/seat_heater_right",
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
   "command_topic": "'${TOPIC_ROOT}'/heater-seat-rear-left",
   "state_topic": "'${TOPIC_ROOT}'/select/seat_heater_rear_left",
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
   "name": "Heated Seat Rear Left",
   "options": ["off", "low", "medium", "high"],
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_heater-seat-rear-left"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/select/${DEVICE_ID}/heater-seat-rear-left/config -l

  echo '{
   "command_topic": "'${TOPIC_ROOT}'/heater-seat-rear-right",
   "state_topic": "'${TOPIC_ROOT}'/select/seat_heater_rear_right",
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
   "name": "Heated Seat Rear Right",
   "options": ["off", "low", "medium", "high"],
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_heater-seat-rear-right"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/select/${DEVICE_ID}/heater-seat-rear-right/config -l

  # Locks (future)

  #echo '{
  # "command_topic": "'${TOPIC_ROOT}'/door_lock",
  # "state_topic": "'${TOPIC_ROOT}'/lock/locked",
  # "device": {
  #  "identifiers": [
  #  "'${DEVICE_ID}'"
  #  ],
  #  "manufacturer": "tesla-local-control",
  #  "model": "Tesla_BLE",
  #  "name": "'${DEVICE_NAME}'",
  #  "sw_version": "'${SW_VERSION}'"
  # },
  # "icon": "mdi:car-door-lock",
  # "name": "Door Lock",
  # "payload_lock": "lock",
  # "payload_unlock": "unlock",
  # "state_locked": "true",
  # "state_unlocked": "false",
  # "qos": "'${QOS_LEVEL}'",
  # "unique_id": "'${DEVICE_ID}'_door_lock"
  # }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/lock/${DEVICE_ID}/door_lock/config -l

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
   "icon": "mdi:key",
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
   "icon": "mdi:key-change",
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
   "icon": "mdi:key-wireless",
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
#   Setup Diagnostic Card
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
    "icon": "mdi:car-info",
    "name": "Car state information",
    "enabled_by_default": "false",    
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
    "icon": "mdi:bluetooth-settings",
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
   "icon": "mdi:database-sync",
   "name": "Force Update All",
   "entity_category": "diagnostic",
   "payload_press": "read-state-all",
   "qos": "'${QOS_LEVEL}'",
   "unique_id": "'${DEVICE_ID}'_read-state"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/read-state-all/config -l

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
   "icon": "mdi:database-sync",
   "name": "Force Update Env",
   "entity_category": "diagnostic",
   "payload_press": "read-state-envcheck",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_read-state-envcheck"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/read-state-envcheck/config -l

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
   "icon": "mdi:database-sync",
   "name": "Force Update Charge",
   "entity_category": "diagnostic",
   "payload_press": "read-state-charge",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_read-state-charge"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/read-state-charge/config -l

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
   "icon": "mdi:database-sync",
   "name": "Force Update Climate",
   "entity_category": "diagnostic",
   "payload_press": "read-state-climate",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_read-state-climate"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/read-state-climate/config -l

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
   "icon": "mdi:database-sync",
   "name": "Force Update Tyre",
   "entity_category": "diagnostic",
   "payload_press": "read-state-tyre",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_read-state-tyre"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/read-state-tyre/config -l

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
   "icon": "mdi:database-sync",
   "name": "Force Update Closure",
   "entity_category": "diagnostic",
   "payload_press": "read-state-closure",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_read-state-closure"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/read-state-closure/config -l

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
   "icon": "mdi:database-sync",
   "name": "Force Update Drive",
   "entity_category": "diagnostic",
   "payload_press": "read-state-drive",
   "qos": "'${QOS_LEVEL}'",
   "enabled_by_default": "false",
   "unique_id": "'${DEVICE_ID}'_read-state-drive"
   }' | sed ':a;N;$!ba;s/\n//g' | retryMQTTpub 6 10 -t homeassistant/button/${DEVICE_ID}/read-state-drive/config -l

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

    # Discard /config and /command messages
    log_notice "setupHADiscoveryAllVINsMain; Discarding unread MQTT messages for command and config topics"
    eval $MOSQUITTO_PUB_BASE -t tesla_ble/$vin/config -n
    eval $MOSQUITTO_PUB_BASE -t tesla_ble/$vin/command -n
  done

}

###
##
#
##
###
# Function
delete_legacies() {

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
  eval $MOSQUITTO_PUB_BASE -t homeassistant/switch/tesla_ble/sw-heater/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/wake/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble/windows-vent/config -n

}

delete_legacies_singles() {
  vin=$1

  # If a vin is provided, add it
  if [ -n "$vin" ]; then
    add_vin=_${vin}
  fi

  log_notice "delete_legacies_singles; deleting legacy single MQTT entities topics"
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/charge-port-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/charge-port-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/charging-start/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/charging-stop/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/climate-off/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/climate-on/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/scan-bleln-macaddr/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/trunk-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/trunk-open/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/windows-close/config -n
  eval $MOSQUITTO_PUB_BASE -t homeassistant/button/tesla_ble${add_vin}/windows-vent/config -n

}
