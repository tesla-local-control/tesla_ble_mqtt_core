#!/bin/ash

listen_to_mqtt() {
 # log_info "Listening to MQTT"
 mosquitto_sub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" --nodelay -t tesla_ble/+/+ -F ""%t %p" -E -c -i tesla_ble_mqtt -q 1" \
      | while read -r payload
  do
   topic=${payload%% *}
   msg=${payload#* }
   topic_stripped=${topic#*/}
   vin=${topic_stripped%/*}
   cmnd=${topic_stripped#*/}
   log_info "Received MQTT message $topic $msg VIN: $vin COMMAND: $cmnd"

   case $cmnd in
    config)
     log_info "Configuration $msg requested"

     case $msg in
      generate_keys)
       log_notice "Generating the private key"
       openssl ecparam -genkey -name prime256v1 -noout > /share/tesla_ble_mqtt/${vin}_private.pem
       log_debug "$(cat /share/tesla_ble_mqtt/${vin}_private.pem)"
       [ "$DEBUG" != "true" ] \
         && log_notice "The private key is shown only in debug mode"
       log_notice "Generating the public key"
       openssl ec -in /share/tesla_ble_mqtt/${vin}_private.pem -pubout > /share/tesla_ble_mqtt/${vin}_public.pem
       log_notice "$(cat /share/tesla_ble_mqtt/${vin}_public.pem)"
       log_notice "KEYS GENERATED. Next:
       1/ Remove any previously deployed BLE keys from vehicle before deploying this one
       2/ Wake the car up with your Tesla App
       3/ Push the button 'Deploy Key'"
      ;;

      deploy_key)
       log_notice "Deploying public key to vehicle"
       send_key $vin;;

      scan_bluetooth)
       log_notice "Scanning Bluetooth"
       scan_bluetooth;;

      *)
       log_error "Invalid Configuration request. Topic: $topic Message: $msg";;
     esac
	;;

    command)
     log_info "Command $msg requested"
     case $msg in
       wake)
        log_notice "Waking Car"
        send_command $vin "-domain vcsec $msg";;
       trunk-open)
        log_notice "Opening Trunk"
        send_command $vin $msg;;
       trunk-close)
        log_notice "Closing Trunk"
        send_command $vin $msg;;
       charging-start)
        log_notice "Start Charging"
        send_command $vin $msg;;
       charging-stop)
        log_notice "Stop Charging"
        send_command $vin $msg;;
       charge-port-open)
        log_notice "Open Charge Port"
        send_command $vin $msg;;
       charge-port-close)
        log_notice "Close Charge Port"
        send_command $vin $msg;;
       climate-on)
        log_notice "Start Climate"
        send_command $vin $msg;;
       climate-off)
        log_notice "Stop Climate"
        send_command $vin $msg;;
       flash-lights)
        log_notice "Flash Lights"
        send_command $vin $msg;;
       frunk-open)
        log_notice "Open Frunk"
        send_command $vin $msg;;
       honk)
        log_notice "Honk Horn"
        send_command $vin $msg;;
       lock)
        log_notice "Lock Car"
        send_command $vin $msg;;
       unlock)
        log_notice "Unlock Car"
        send_command $vin $msg;;
       windows-close)
        log_notice "Close Windows"
        send_command $vin $msg;;
       windows-vent)
        log_notice "Vent Windows"
        send_command $vin $msg;;
       *)
        log_error "Invalid Command Request. Topic: $topic Message: $msg";;
      esac
	;;
	
    charging-amps)
     log_info "Set Charging Amps to $msg requested"
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
	
    auto-seat-and-climate)
     log_notice "Start Auto Seat and Climate"
     send_command $vin "auto-seat-and-climate LR on";;

    charging-set-limit)
     log_notice "Set Charging Limit to $msg"
     send_command $vin "charging-set-limit $msg";;

    climate-set-temp)
     log_notice "Set Climate Temp to $msg"
     send_command $vin "climate-set-temp ${msg}C";;

    heated_seat_left)
     log_notice "Set Seat heater to front-left $msg"
     send_command $vin "seat-heater front-left $msg";;

    heated_seat_right)
     log_notice "Set Seat heater to front-right $msg"
     send_command $vin "seat-heater front-right $msg";;

    *)
     log_error "Invalid MQTT topic. Topic: $topic Message: $msg";;
   esac
  done
}

listen_for_HA_start() {
 mosquitto_sub -h $MQTT_IP -p $MQTT_PORT -u "${MQTT_USER}" -P "${MQTT_PWD}" --nodelay -t homeassistant/status -F "%t %p" | while read -r payload
  do
   topic=$(echo "$payload" | cut -d ' ' -f 1)
   msg=$(echo "$payload" | cut -d ' ' -f 2-)
   log_info "Received HA Status message: $topic $msg"
   case $topic in

    homeassistant/status)
     case $msg in
       offline)
        log_info "Home Assistant is stopping";;
       online)
        # https://github.com/iainbullock/tesla_ble_mqtt_docker/discussions/6
        log_notice "Home Assistant is starting, re-running MQTT auto-discovery"
        if [ "$TESLA_VIN1" ] && [ $TESLA_VIN1 != "00000000000000000" ]; then
         setup_auto_discovery $TESLA_VIN1
        fi
        if [ "$TESLA_VIN2" ] && [ $TESLA_VIN2 != "00000000000000000" ]; then
         setup_auto_discovery $TESLA_VIN2
        fi
        if [ "$TESLA_VIN3" ] && [ $TESLA_VIN3 != "00000000000000000" ]; then
         setup_auto_discovery $TESLA_VIN3
        fi
       ;;
       *)
        log_error "Invalid Command Request. Topic: $topic Message: $msg";;
     esac
	;;
    *)
     log_error "Invalid MQTT topic. Topic: $topic Message: $msg";;
   esac
  done
}
