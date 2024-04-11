#!/usr/bin/env bash

set -euo pipefail

#######################################
# Prints a message to the console in the format: | <timestamp> | <message> <secondary_message> (optional)
# Arguments:
#   1
#   2
#######################################
print_message() {
  local message
  local secondary_message
  local report_message

  message="${1}"
  secondary_message="${2:-""}"
  report_message="| $(report_timestamp) | ${message}"

  if [[ -n ${secondary_message:-} ]]; then
    report_message+=$'\n'"| $(report_timestamp) | ${secondary_message}"
  fi

  echo "${report_message}"
}

#######################################
# Print message to the console with a prefix and suffix message if provided and not empty
# Arguments:
#  None
#######################################
print_multiple_messages() {
  # Loop over the arguments two at a time
  while [[ $# -gt 0 ]]; do
    # Take first argument as the primary message
    local primary_msg="${1:-""}"
    shift # move to next argument

    # Take second argument as the secondary message, if it exists
    local secondary_msg=""
    if [[ $# -gt 0 ]]; then
      secondary_msg="${1}"
      shift # move to next pair or end of arguments
    fi

    # Call the print_message with the two messages
    echo "---------------------------------------"
    print_message "${primary_msg}" "${secondary_msg}"
    echo "---------------------------------------"
  done
}

#######################################
# Report the current timestamp in the format YYYY-MM-DD_HH:MM:SS (e.g. 2021-01-01_12:34:56)
# Arguments:
#  None
#######################################
report_timestamp() {
  local time_format="%Y-%m-%d_%H:%M:%S"
  local time
  time=$(date +"${time_format}")
  echo "${time}"
}