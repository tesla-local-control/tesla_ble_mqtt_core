#!/bin/ash
#
# shellcheck shell=dash
#
# mqtt-persistent.sh - Handle persistent MQTT connections
# Credit to mrwogu https://github.com/mrwogu for proposing this PR https://github.com/tesla-local-control/tesla_ble_mqtt_core/pull/162
##

# Variables for the persistent connection process
export MQTT_FIFO_IN="/tmp/mqtt_fifo_in"
export MQTT_FIFO_OUT="/tmp/mqtt_fifo_out"
export MQTT_PERSIST_PID_FILE="/tmp/mqtt_persist_pid"
export MQTT_CLIENT_ID="tesla_ble_mqtt_$(hostname | md5sum | head -c 8)"

# Start the persistent MQTT connection
start_mqtt_persistent() {
  log_notice "Setting up persistent MQTT connection with client ID: $MQTT_CLIENT_ID"
  
  # Create named pipes if they don't exist
  [ -p "$MQTT_FIFO_IN" ] || mkfifo "$MQTT_FIFO_IN"
  [ -p "$MQTT_FIFO_OUT" ] || mkfifo "$MQTT_FIFO_OUT"
  
  # Start mosquitto_pub in persistent mode
  if [ -n "$MQTT_USERNAME" ]; then
    log_notice "Starting persistent MQTT client with authentication"
    echo $MQTT_FIFO_IN
    cat "$MQTT_FIFO_IN"
    mosquitto_pub -h "$MQTT_SERVER" -p "$MQTT_PORT" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
      -i "$MQTT_CLIENT_ID" --nodelay -l -d < "$MQTT_FIFO_IN" > "$MQTT_FIFO_OUT" &
  else
    log_notice "Starting persistent MQTT client in anonymous mode"
    mosquitto_pub -h "$MQTT_SERVER" -p "$MQTT_PORT" \
      -i "$MQTT_CLIENT_ID" --nodelay -l -d < "$MQTT_FIFO_IN" > "$MQTT_FIFO_OUT" 2>&1 &
  fi
  
  MQTT_PID=$!
  echo $MQTT_PID > "$MQTT_PERSIST_PID_FILE"
  log_notice "Persistent MQTT connection started with PID: $MQTT_PID"
  
  # Start a background process to read from the output pipe
  (
    while read -r line; do
      log_debug "MQTT output: $line"
    done < "$MQTT_FIFO_OUT"
  ) &
}

# Stop the persistent MQTT connection
stop_mqtt_persistent() {
  if [ -f "$MQTT_PERSIST_PID_FILE" ]; then
    MQTT_PID=$(cat "$MQTT_PERSIST_PID_FILE")
    log_notice "Stopping persistent MQTT connection (PID: $MQTT_PID)"
    kill $MQTT_PID 2>/dev/null || true
    rm -f "$MQTT_PERSIST_PID_FILE"
  fi
}

# Publish a message using the persistent connection
mqtt_publish_persistent() {
  local topic="$1"
  local message="$2"
  
  # Check if the persistent connection is running
  if [ ! -f "$MQTT_PERSIST_PID_FILE" ] || ! kill -0 $(cat "$MQTT_PERSIST_PID_FILE") 2>/dev/null; then
    log_warning "MQTT persistent connection not running, starting it now"
    stop_mqtt_persistent 2>/dev/null || true
    start_mqtt_persistent
    sleep 1
  fi
  
  # Send the topic and message to the FIFO in the format mosquitto_pub expects with -l option
  # For mosquitto_pub with -l flag, each line should be: "topic message"
  echo "$topic $message" > "$MQTT_FIFO_IN"
}

# Initialize the persistent connection
init_mqtt_persistent() {
  # Ensure old connections are stopped first
  stop_mqtt_persistent 2>/dev/null || true
  
  # Start the new persistent connection
  start_mqtt_persistent
  
  # Set up a trap to close the connection on script exit
  trap stop_mqtt_persistent EXIT INT TERM
}
