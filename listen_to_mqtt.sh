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
       2/ Wake the car up with your Tesla App
       3/ Push the button 'Deploy Key'"
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
          log_error "Invalid configuration request; topic:$topic vin:$vin msg:$msg"
          ;;
        esac
        ;;

      command)
        case $msg in
        wake)
          log_notice "Waking Up"
          send_command $vin "-domain vcsec $msg"
          ;;
        trunk-open)
          log_notice "Opening Trunk"
          send_command $vin $msg
          ;;
        trunk-close)
          log_notice "Closing Trunk"
          send_command $vin $msg
          ;;
        charging-start)
          log_notice "Start Charging"
          send_command $vin $msg
          ;;
        charging-stop)
          log_notice "Stop Charging"
          send_command $vin $msg
          ;;
        charge-port-open)
          log_notice "Open Charge Port"
          send_command $vin $msg
          ;;
        charge-port-close)
          log_notice "Close Charge Port"
          send_command $vin $msg
          ;;
        climate-on)
          log_notice "Start Climate"
          send_command $vin $msg
          ;;
        climate-off)
          log_notice "Stop Climate"
          send_command $vin $msg
          ;;
        flash-lights)
          log_notice "Flash Lights"
          send_command $vin $msg
          ;;
        frunk-open)
          log_notice "Open Frunk"
          send_command $vin $msg
          ;;
        honk)
          log_notice "Honk Horn"
          send_command $vin $msg
          ;;
        lock)
          log_notice "Lock Car"
          send_command $vin $msg
          ;;
        unlock)
          log_notice "Unlock Car"
          send_command $vin $msg
          ;;
        windows-close)
          log_notice "Close Windows"
          send_command $vin $msg
          ;;
        windows-vent)
          log_notice "Vent Windows"
          send_command $vin $msg
          ;;
        *)
          log_error "Invalid command request; topic:$topic msg:$msg"
          ;;
        esac
        ;; ## END of command)

      charging-set-amps)
        # https://github.com/iainbullock/tesla_ble_mqtt_docker/issues/4
        if [ $msg -gt 4 ]; then
          log_notice "Set amps"
          send_command $vin "charging-set-amps $msg"
        else
          log_notice "First Amp set"
          send_command $vin "charging-set-amps $msg"
          sleep 1
          log_notice "Second Amp set"
          send_command $vin "charging-set-amps $msg"
        fi
        ;;

      charging-set-amps-override)
        # Command to send a single Amps request
        # Ref: https://github.com/tesla-local-control/tesla_ble_mqtt_core/issues/19
        log_info "Set charging Amps to $msg"
        send_command $vin "charging-set-amps $msg"
        ;;

      charging-set-limit)
        send_command $vin "charging-set-limit $msg"
        ;;

      climate-set-temp)
        send_command $vin "climate-set-temp ${msg}C"
        ;;

      auto-seat-and-climate)
        send_command $vin "auto-seat-and-climate LR on"
        ;;

      heater-seat-front-left)
        send_command $vin "seat-heater front-left $msg"
        ;;

      heater-seat-front-right)
        send_command $vin "seat-heater front-right $msg"
        ;;

      sw-heater)
        send_command $vin "sw-heater $msg"
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
