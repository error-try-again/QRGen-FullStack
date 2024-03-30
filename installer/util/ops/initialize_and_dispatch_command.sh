#!/usr/bin/env bash

set -euo pipefail

# TODO: Migrate away from eval
# Take a list of arguments and parse them into flags and values using getopts and eval
dispatch_command() {
  trap quit SIGINT
  options_parser "$@"

  # Associative array to map the command flag to the corresponding to execute.
  local -A command_function_map=(
                       ["${setup}"]=setup
                       ["${uninstall}"]=uninstall
                       ["${dump_logs}"]=dump_logs
                       ["${update_project}"]=update_project
                       ["${stop_containers}"]=stop_containers
                       ["${purge}"]=purge
                       ["${quit}"]=quit
                       ["${help}"]=display_help
  )

  local command_executed=false
  local command

  # Iterate over the keys of the associative array and check if the key is true
  # If the key is true, then execute the corresponding and set command_executed to true
  # If no command is executed, then run the user prompt
  for command in "${!command_function_map[@]}"; do
    if [[ ${command} == true ]]; then
      eval "${command_function_map[${command}]}"
      command_executed=true
      break
    fi
  done
  if [[ ${command_executed} == false ]]; then
    prompt_user
  fi
}

#######################################
# description
# Globals:
#   docker_compose_file
#   project_logs_dir
# Arguments:
#  None
#######################################
options_parser() {

  local long_options_list

  # Define long options for the script. Each option is followed by a comma.
  # Options requiring an argument are followed by a colon.
  long_options_list="setup,uninstall,dump-logs,update-project,help,quit,stop-containers,purge"

  # Parse the provided options using getopt. This prepares them for consumption.
  # -o defines short options, here only 'h' (help) as a short option.
  # -n defines the name of the script for error messages.
  # --long defines the long options.
  # The last -- "$@" passes all the script's command-line arguments for parsing.
  local parsed_options
  parsed_options=$(getopt -o h -n 'script.bash' --long "${long_options_list}" -- "$@")

  # Exit if getopt has encountered an error.
  if [[ -z ${parsed_options} ]]; then
    print_multiple_messages "Failed parsing options." >&2
    exit 1
  fi

  eval set -- "${parsed_options}"
  while true; do
    case "$1" in
      --help | -h)
        # Display help message and terminate script execution.
        display_help
        quit
        ;;
      --setup)
        # Perform setup and terminate script execution.
        setup
        ;;
      --uninstall)
        # Perform uninstall and terminate script execution.
        uninstall
        ;;
      --stop-containers)
        # Stop containers and terminate script execution.
        stop_containers
        ;;
      --purge)
        # Perform purge and terminate script execution.
        purge
        ;;
      --dump-logs)
        # Dump logs and terminate script execution.
        dump_logs "${docker_compose_file}" "${project_logs_dir}"
        ;;
      --update-project)
        # Update project and terminate script execution.
        update_project
        ;;
      --quit)
        # Terminate script execution.
        quit
        ;;
      --)
        # End of options.
        break
        ;;
      *)
        # Unexpected option.
        print_multiple_messages "Unexpected option: $1" >&2
        quit
        ;;
    esac
    # Proceed to next option if available.
    shift
  done
}

#######################################
# description
# Arguments:
#   0
#######################################
display_help() {
  cat << EOF
Usage: $0 [options]
A comprehensive script for managing and deploying web environments.

General Options:
  --setup                             Initialize and configure the project setup.
  --uninstall                         Clean up and remove project-related data.
  --dump-logs                         Collect and display system logs.
  --update                   Update the project components to the latest version.
  --stop                   Halt all related Docker containers.
  --purge                      Remove Docker builds and clean up space (Use with caution).
  --quit                              Exit the script prematurely.

Help and Miscellaneous:
  -h, --help                          Display this help message and exit.

Descriptions and additional information for each option can be added here for clarity and guidance.

EOF
}

#######################################
# description
# Globals:
#   dump_logs
#   help
#   purge
#   quit
#   setup
#   stop_containers
#   uninstall
#   update_project
# Arguments:
#  None
#######################################
initialize_command_flags() {
  setup=false
  uninstall=false
  dump_logs=false
  update_project=false
  stop_containers=false
  purge=false
  quit=false
  help=false
}