# shellcheck shell=dash
#
# mqtt.sh
##

### MQTT clients anonymous or authentication mode #############################
if [ -n "$MQTT_USERNAME" ]; then
  log_notice "Setting up MQTT clients with authentication"
  export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u '${MQTT_USERNAME}' -P '${MQTT_PASSWORD}'"
  export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT -u '${MQTT_USERNAME}' -P '${MQTT_PASSWORD}'"
else
  log_notice "Setting up MQTT clients using anonymous mode"
  export MOSQUITTO_PUB_BASE="mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT"
  export MOSQUITTO_SUB_BASE="mosquitto_sub -h $MQTT_SERVER -p $MQTT_PORT"
fi

retryMQTTpub() {
  args=$*
  retryMQTTAttemptCount=6
  retryMQTTpubDelay=10

  log_debug "retryMQTTpub; entering..."

  # read topic json fom stdin
  read -r tapic_json

  # loop for topic json fom stdin
  cmdCounterLoop=0

  # Retry loop
  max_retries=6
  for cmdCounterLoop++ in $(seq $retryMQTTAttemptCount); do

    log_debug "retryMQTTpub; calling mosquitto_sub $args"
    echo "$tapic_json" | eval $MOSQUITTO_SUB_BASE $args
    exit_code=$?

    if [ $exit_code -eq 0 ];
      log_debug "mosquitto_sub successfully sent $args"
      break
    else
      if [ $retryMQTTAttemptCount -eq $cmdCounterLoop ]; then
        log_error "mosquitto_sub could not sent $args, no more retries"
        return 1
      fi
      log_warning "mosquitto_sub could not sent $args, retrying in $retryMQTTpubDelay""
      sleep $retryMQTTpubDelay
    fi
  done

  log_debug "retryMQTTpub; leaving..."
  return $exit_code

}
