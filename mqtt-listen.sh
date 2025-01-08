# shellcheck shell=dash
#
# listen_to_mqtt
#

### function listen_to_mqtt_loop
##  - Main MQTT while loop
#   - If listen_to_mqtt() fails due to MQTT service (restart/network/etc), loop handles restart
#   - TODO: After testing, this loop might be useless.... process _sub keeps running when MQTT is
##    down for ~ 10-15m
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
  log_info "Listening to MQTT"
  eval $MOSQUITTO_SUB_BASE --nodelay --disable-clean-session --qos 1 --topic tesla_ble/+/+ -F \"%t %p\" --id tesla_ble_mqtt |
    while read -r payload; do
      topic=${payload%% *}
      msg=${payload#* }
      topic_stripped=${topic#*/}
      vin=${topic_stripped%/*}
      cmd=${topic_stripped#*/}
      log_debug "Received MQTT message; topic:$topic msg:$msg vin:$vin cmd:$cmd"

      case $cmd in
      config)

        case $msg in
        body-controller-state)
          teslaCtrlSendCommand $vin $msg "Fetch limited vehicle state information. Works over BLE when infotainment is asleep"
          ;;

        generate-keys)
          log_notice "Generating the private key..."
          openssl ecparam -genkey -name prime256v1 -noout >$KEYS_DIR/${vin}_private.pem
          log_debug "$(cat $KEYS_DIR/${vin}_private.pem)"
          [ "$DEBUG" != "true" ] &&
            log_notice "The private key is shown only in debug mode"
          log_notice "Generating the public key..."
          openssl ec -in $KEYS_DIR/${vin}_private.pem -pubout >$KEYS_DIR/${vin}_public.pem
          log_notice "$(cat $KEYS_DIR/${vin}_public.pem)"

          if [ "$ENABLE_HA_FEATURES" == "true" ]; then
            log_notice "Adding Home Assistant 'Deploy Key' button"
            setupDeployKeyButton $vin
            setupReGenerateKeysButton $vin
          fi

          log_warning "Private and Public keys were generated; Next:

           1/ Remove any previously deployed BLE keys from vehicle before deploying this one
           2/ Open the Tesla App on your smartphone and make sure the vehicule is awake
           3/ In Home Assistant device Tesla_BLE_${vin}, push the button 'Deploy Key'"
          ;;

        deploy-key)
          log_debug "deploy-key; calling deployKeyMain()"
          deployKeyMain $vin
          ;;

        info-bt-adapter)
          log_notice 'info-bt-adapter; launching infoBluetoothAdapter(); results in ~10 seconds"'
          infoBluetoothAdapter $vin
          ;;

        read-state-all)
          log_notice "read-state; calling readState()"
          readState $vin all
          ;;

        read-state-envcheck)
          log_notice "read-state; calling readState()"
          readState $vin env_check
          ;;

        read-state-charge)
          log_notice "read-state; calling readState()"
          readState $vin charge
          ;;

        read-state-climate)
          log_notice "read-state; calling readState()"
          readState $vin climate
          ;;

        read-state-tyre)
          log_notice "read-state; calling readState()"
          readState $vin tyre
          ;;

        read-state-closure)
          log_notice "read-state; calling readState()"
          readState $vin closure
          ;;
        read-state-drive)
          log_notice "read-state; calling readState()"
          readState $vin drive
          ;;

        *)
          log_error "Invalid configuration request:$msg topic:$topic vin:$vin"
          ;;
        esac
        ;;

      command)
        case $msg in
        autosecure-modelx)
          teslaCtrlSendCommand $vin $msg "Close falcon-wing doors and lock vehicle"
          ;;
        charging-schedule-cancel)
          teslaCtrlSendCommand $vin $msg "Cancel scheduled charge start"
          ;;
        drive)
          teslaCtrlSendCommand $vin $msg "Remote start vehicle"
          ;;
        flash-lights)
          teslaCtrlSendCommand $vin $msg "Flash lights"
          ;;
        frunk-open)
          teslaCtrlSendCommand $vin $msg "Open vehicle frunk"
          ;;
        honk)
          teslaCtrlSendCommand $vin $msg "Honk horn"
          ;;
        list-keys)
          teslaCtrlSendCommand $vin $msg "List public keys enrolled on vehicle"
          ;;
        lock)
          teslaCtrlSendCommand $vin $msg "Lock vehicle"
          ;;
        media-toggle-playback)
          teslaCtrlSendCommand $vin $msg "Toggle between play/pause"
          ;;
        ping)
          teslaCtrlSendCommand $vin $msg "Ping vehicle"
          ;;
        software-update-cancel)
          teslaCtrlSendCommand $vin $msg "Cancel a pending software update"
          ;;
        software-update-start)
          teslaCtrlSendCommand $vin $msg "Start software update after delay"
          ;;
        unlock)
          teslaCtrlSendCommand $vin $msg "Unlock vehicle"
          ;;
        wake)
          teslaCtrlSendCommand $vin "-domain vcsec $msg" "Wake up vehicule"
          ;;
        *)
          log_error "Invalid command request; vin:$vin topic:$topic msg:$msg"
          ;;
        esac
        ;; ## END of command)

      auto-seat-and-climate)
        teslaCtrlSendCommand $vin "auto-seat-and-climate LR on" "Turn on automatic seat heating and HVAC"
        ;;

      charging-schedule)
        teslaCtrlSendCommand $vin "charging-schedule $msg" "Schedule charging to $msg minutes after midnight and enable daily scheduling"
        ;;

      charging-set-amps)
        # https://github.com/iainbullock/tesla_ble_mqtt_docker/issues/4
        if [ $msg -gt 4 ]; then
          teslaCtrlSendCommand $vin "charging-set-amps $msg" "Set charging Amps to $msg"
        else
          teslaCtrlSendCommand $vin "charging-set-amps $msg" "4A or less requested, calling charging-set-amps $msg twice"
          sleep 1
          teslaCtrlSendCommand $vin "charging-set-amps $msg" "Set charging Amps to $msg"
        fi
        ;;

      charging-set-amps-override)
        # Command to send a single Amps request
        # Ref: https://github.com/tesla-local-control/tesla_ble_mqtt_core/issues/19
        teslaCtrlSendCommand $vin "charging-set-amps $msg" "Set charging Amps to $msg"
        ;;

      charging-set-limit)
        teslaCtrlSendCommand $vin "charging-set-limit $msg" "Set charging limit to ${msg}%"
        ;;

      climate-set-temp)
        [ ${msg} -le 50 ] && T="${msg}C" || T="${msg}F"
        teslaCtrlSendCommand $vin "climate-set-temp ${T}" "Set climate temperature to ${T}"
        ;;

      heater-seat-front-left)
        teslaCtrlSendCommand $vin "seat-heater front-left $msg" "Turn $msg front left seat heater"
        ;;

      heater-seat-front-right)
        teslaCtrlSendCommand $vin "seat-heater front-right $msg" "Turn $msg front right seat heater"
        ;;

      media-set-volume)
        teslaCtrlSendCommand $vin "media-set-volume $msg" "Set volume to $msg"
        ;;

      sentry-mode)
        teslaCtrlSendCommand $vin "sentry-mode $msg" "Set sentry mode to $msg"
        ;;

      steering-wheel-heater)
        teslaCtrlSendCommand $vin "steering-wheel-heater $msg" "Set steering wheel mode to $msg"
        ;;

      climate)
        teslaCtrlSendCommand $vin "$cmd-$msg" "Set $cmd mode to $msg"
        ;;

      charging)
        teslaCtrlSendCommand $vin "$cmd-$msg" "Set $cmd mode to $msg"
        ;;

      charge-port)
        teslaCtrlSendCommand $vin "$cmd-$msg" "Set $cmd mode to $msg"
        ;;

      trunk)
        teslaCtrlSendCommand $vin "$cmd-$msg" "Set $cmd mode to $msg"
        ;;

      tonneau)
        # not declared in MQTT yet
        teslaCtrlSendCommand $vin "$cmd-$msg" "Set $cmd mode to $msg"
        ;;

      windows)
        teslaCtrlSendCommand $vin "$cmd-$msg" "Set $cmd mode to $msg"
        ;;

      variables)
        # These get handled in the subshell where they are used       
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
listenForHAstatus() {
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
          log_notice "Home Assistant is now online, calling setupHADiscoveryAllVINsMain()"
          setupHADiscoveryAllVINsMain
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
