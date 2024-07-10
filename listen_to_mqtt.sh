# shellcheck shell=dash
#
# listen_to_mqtt
#


###
#
# listen_to_mqtt_loop :
#   - Main while loop
#   - If listen_to_mqtt fails due to MQTT service restart, network or other conditions the
#     loop will restart it.
###
listen_to_mqtt_loop() {

  log_notice "Entering Listen to MQTT loop..."

  while :; do
    log_info "Launching listen_to_mqtt"
    if ! listen_to_mqtt; then
      log_error "listen_to_mqtt stopped due to a failure; restarting the process in 10 seconds"
      sleep 10
    fi
    exit 0
  done

}

listen_to_mqtt() {
  log_debug "Listening to MQTT"
  eval $MOSQUITTO_SUB_BASE --nodelay -t tesla_ble/+/+ -F \"%t %p\" -c -i tesla_ble_mqtt -q 0 |
    while read -r payload; do
      topic=${payload%% *}
      msg=${payload#* }
      topic_stripped=${topic#*/}
      vin=${topic_stripped%/*}
      cmd=${topic_stripped#*/}
      log_info "Received MQTT message; topic:$topic msg:$msg vin:$vin cmd:$cmd"

      case $cmd in
      config)

        case $msg in
        generate-keys)
          log_notice "Generating the private key..."
          openssl ecparam -genkey -name prime256v1 -noout >/share/tesla_ble_mqtt/${vin}_private.pem
          log_debug "$(cat /share/tesla_ble_mqtt/${vin}_private.pem)"
          [ "$DEBUG" != "true" ] &&
            log_notice "The private key is shown only in debug mode"
          log_notice "Generating the public key..."
          openssl ec -in /share/tesla_ble_mqtt/${vin}_private.pem -pubout >/share/tesla_ble_mqtt/${vin}_public.pem
          log_notice "$(cat /share/tesla_ble_mqtt/${vin}_public.pem)"
          log_warning "Private and Public keys were generated; Next:
       1/ Remove any previously deployed BLE keys from vehicle before deploying this one
       2/ Open the Tesla App on your smartphone and make sure the car is awake.Wake the car up with your Tesla App
       3/ In Home Assistant device Tesla_BLE_${vin}, push the button 'Deploy Key'"
          ;;

        deploy-key)
          log_notice "Trying to deploy the public key to vehicle..."
          send_key $vin
          ;;

        scan-bleln-macaddr)
          log_notice "Scanning for Tesla BLE Local Name and respective MAC addr..."
          scan-bleln-macaddr
          ;;

        *)
          log_error "Invalid configuration command request; vin:$vin topic:$topic msg:$msg"
          ;;
        esac
        ;;

      command)
        case $msg in
        autosecure-modelx)
          send_command $vin $msg "Close falcon-wing doors and lock vehicle"
          ;;
        charge-port-close)
          send_command $vin $msg "Close charge port"
          ;;
        charge-port-open)
          send_command $vin $msg "Open charge port"
          ;;
        charging-schedule-cancel)
          send_command $vin $msg "Cancel scheduled charge start"
          ;;
        charging-start)
          send_command $vin $msg "Start charging"
          ;;
        charging-stop)
          send_command $vin $msg "Stop charging"
          ;;
        climate-off)
          send_command $vin $msg "Turn off climate control"
          ;;
        climate-on)
          send_command $vin $msg "Turn on climate control"
          ;;
        drive)
          send_command $vin $msg "Remote start vehicle"
          ;;
        flash-lights)
          send_command $vin $msg "Flash lights"
          ;;
        frunk-open)
          send_command $vin $msg "Open vehicle frunk"
          ;;
        honk)
          send_command $vin $msg "Honk horn"
          ;;
        list-keys)
          send_command $vin $msg "List public keys enrolled on vehicle"
          ;;
        lock)
          send_command $vin $msg "Lock vehicle"
          ;;
        media-toggle-playback)
          send_command $vin $msg "Toggle between play/pause"
          ;;
        ping)
          send_command $vin $msg "Ping vehicle"
          ;;
        software-update-cancel)
          send_command $vin $msg "Cancel a pending software update"
          ;;
        software-update-start)
          send_command $vin $msg "Start software update after delay"
          ;;
        tonneau-close)
          send_command $vin $msg "Close Cybertruck tonneau"
          ;;
        tonneau-open)
          send_command $vin $msg "Open Cybertruck tonneau"
          ;;
        tonneau-stop)
          send_command $vin $msg "Stop moving Cybertruck tonneau"
          ;;
        trunk-close)
          send_command $vin $msg "Close vehicle trunk"
          ;;
        trunk-move)
          send_command $vin $msg "Toggle trunk open/closed"
          ;;
        trunk-open)
          send_command $vin $msg "Open vehicle trunk"
          ;;
        unlock)
          send_command $vin $msg "Unlock vehicle"
          ;;
        wake)
          send_command $vin " "-domain vcsec $msg" "Wake up vehicule"
          ;;
        windows-close)
          send_command $vin $msg "Close all windows"
          ;;
        windows-vent)
          send_command $vin $msg "Vent all windows"
          ;;
        *)
          log_error "Invalid command request; vin:$vin topic:$topic msg:$msg"
          ;;
        esac
        ;; ## END of command)

      auto-seat-and-climate)
        send_command $vin "auto-seat-and-climate LR on" "Turn on automatic seat heating and HVAC"
        ;;

      charging-schedule)
        send_command $vin "charging-schedule $msg" "Schedule charging to $msg minutes after midnight and enable daily scheduling"
        ;;

      charging-set-amps)
        # https://github.com/iainbullock/tesla_ble_mqtt_docker/issues/4
        if [ $msg -gt 4 ]; then
          send_command $vin "charging-set-amps $msg" "Set amps"
        else
          send_command $vin "charging-set-amps $msg" "First Amp set"
          sleep 1
          send_command $vin "charging-set-amps $msg" "Second Ampt set"
        fi
        ;;

      charging-set-amps-override)
        # Command to send a single Amps request
        # Ref: https://github.com/tesla-local-control/tesla_ble_mqtt_core/issues/19
        send_command $vin "charging-set-amps $msg" "Set charging Amps to $msg"
        ;;

      charging-set-limit)
        send_command $vin "charging-set-limit $msg" "Set charging limit to ${msg}%"
        ;;

      climate-set-temp)
        [ ${msg} -le 50 ] && T="${msg}ºC" || T="${msg}ºF"
        send_command $vin "climate-set-temp $msg" "Set climate temperature to ${T}"
        ;;

      heater-seat-front-left)
        send_command $vin "seat-heater front-left $msg" "Turn $msg front left seat heater"
        ;;

      heater-seat-front-right)
        send_command $vin "seat-heater front-right $msg" "Turn $msg front right seat heater"
        ;;

      media-set-volume)
        send_command $vin $msg "Set volume to $msg"
        ;;

      steering-wheel-heater)
        msg_lower=$(echo "$msg" | tr '[:upper:]' '[:lower:]')
        send_command $vin "steering-wheel-heater $msg_lower" "Set steering wheel mode to $msg_lower"
        ;;

      sentry-mode)
        msg_lower=$(echo "$msg" | tr '[:upper:]' '[:lower:]')
        send_command $vin "sentry-mode $msg_lower" "Set sentry mode to $msg_lower"
        ;;

      *)
        log_error "Invalid request; topic:$topic vin:$vin msg:$msg"
        ;;
      esac
    done

  # If mosquitto_sub dies, return an error for the loop to restart it
  return 1

}

# Function
setup_auto_discovery_loop() {

  discardMessages=$1

  # Setup or skip HA auto discovery & Discard old MQTT messages
  for vin in $VIN_LIST; do

    # IF HA backend is enable, setup HA Auto Discover
    if [ "$ENABLE_HA_FEATURES" == "true" ]; then
      log_debug "Calling setup_auto_discovery() $vin"
      setup_auto_discovery $vin
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

# Function
listen_for_HA_start() {
  eval $MOSQUITTO_SUB_BASE --nodelay -t homeassistant/status -F \"%t %p\" |
    while read -r payload; do
      topic=$(echo "$payload" | cut -d ' ' -f 1)
      status=$(echo "$payload" | cut -d ' ' -f 2-)
      log_info "Received MQTT message: topic:$topic status:$status"
      # shellcheck disable=SC1009
      case $topic in
      homeassistant/status)
        # shellcheck disable=SC1073
        case $status in
        offline)
          log_notice "Home Assistant is stopping"
          ;;
        online)
          # Ref: https://github.com/iainbullock/tesla_ble_mqtt_docker/discussions/6
          log_notice "Home Assistant is now online, calling setup_auto_discovery_loop()"
          discardMessages=no
          setup_auto_discovery_loop $discardMessages
          ;;
        *)
          log_error "Invalid status; topic:$topic status:$status"
          ;;
        esac
        ;;
      *)
        log_error "Invalid request; topic:$topic status:$status"
        ;;
      esac
    done
}
