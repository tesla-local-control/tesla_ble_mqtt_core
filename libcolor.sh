# shellcheck shell=dash
#
# functions for colored output
#
if [ "$COLOR" = "false" ]; then
  NOCOLOR='\033[0m'
  GREEN=$NOCOLOR
  CYAN=$NOCOLOR
  YELLOW=$NOCOLOR
  MAGENTA=$NOCOLOR
  RED=$NOCOLOR
else 
  NOCOLOR='\033[0m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  YELLOW='\033[1;32m'
  MAGENTA='\033[0;35m'
  RED='\033[0;31m'
fi

# shellcheck disable=SC3036
log_debug   { [ "$DEBUG" = "true" ] && echo -e "${NOCOLOR}$1" || true }
# shellcheck disable=SC3036
log_info    { echo -e "${GREEN}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_notice  { echo -e "${CYAN}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_warning { echo -e "${YELLOW}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_error   { echo -e "${MAGENTA}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_fatal   { echo -e "${RED}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_cyan    { echo -e "${CYAN}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_green   { echo -e "${GREEN}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_magenta { echo -e "${MAGENTA}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_red     { echo -e "${RED}$1${NOCOLOR}"; }
# shellcheck disable=SC3036
log_yellow  { echo -e "${YELLOW}$1${NOCOLOR}"; }
