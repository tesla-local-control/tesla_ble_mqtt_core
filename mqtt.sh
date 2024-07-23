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
  retryMQTTAttemptCount=$1
  retryMQTTpubDelay=$2
  shift
  shift
  args=$*

  log_debug "retryMQTTpub; entering..."

  # read topic json fom stdin
  read -r topic_json

  # Retry loop
  cmdCounterLoop=0
  while [ $((cmdCounterLoop += 1)) -le $retryMQTTAttemptCount ]; do

    log_debug "Attempt $cmdCounterLoop/${retryMQTTAttemptCount} retryMQTTpub; calling mosquitto_pub $args"
    set +e
    echo "$topic_json" | eval $MOSQUITTO_PUB_BASE $args
    exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
      log_debug "mosquitto_pub successfully sent $args"
      return $exit_code
    else
      if [ $retryMQTTAttemptCount -eq $cmdCounterLoop ]; then
        log_error "mosquitto_pub could not sent $args, no more retries"
        return 1
      fi
      log_warning "mosquitto_pub could not sent $args, retrying in $retryMQTTpubDelay"
      sleep $retryMQTTpubDelay
    fi
  done

  log_debug "retryMQTTpub; leaving..."
  return 2

}
