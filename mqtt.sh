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
  
  # Extract topic from args if available (for persistent connection)
  topic=""
  if echo "$args" | grep -q -- "-t"; then
    topic=$(echo "$args" | sed -n 's/.*-t\s\+"\([^"]*\)".*/\1/p;s/.*-t\s\+\([^[:space:]]\+\).*/\1/p' | head -1)
  fi

  # Retry loop
  cmdCounterLoop=0
  while [ $((cmdCounterLoop += 1)) -le $retryMQTTAttemptCount ]; do

    # Use persistent connection if available and we have a topic
    if type mqtt_publish_persistent >/dev/null 2>&1 && [ -n "$topic" ]; then
      log_debug "Attempt $cmdCounterLoop/${retryMQTTAttemptCount} retryMQTTpub; using persistent connection for topic $topic"
      mqtt_publish_persistent "$topic" "$topic_json"
      exit_code=$?
    else
      # Fallback to traditional method
      log_debug "Attempt $cmdCounterLoop/${retryMQTTAttemptCount} retryMQTTpub; calling mosquitto_pub $args"
      set +e
      echo "$topic_json" | eval $MOSQUITTO_PUB_BASE $args
      exit_code=$?
      set -e
    fi

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
