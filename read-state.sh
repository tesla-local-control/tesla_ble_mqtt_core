#!/bin/ash
#
# shellcheck shell=dash
#
# read-state.sh

## function poll_state_loop
function poll_state_loop() {
    log_notice "Entering poll_state_loop..."

    sleep 30
}

function readState() {
  vin=$1

  log_debug "readState; entering vin:$vin"

 # if teslaCtrlSendCommand $vin state "Read vehicle state"; then
 #   log_debug "readState; read of vehicle state succeeded vin:$vin"
    ret=0
 # else
 #   log_debug "readState; failed to read vehicle state vin:$vin"
 #   ret=2
 # fi

  log_debug "readState; leaving vin:$vin return:$ret"

  return $ret

}