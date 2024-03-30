#!/usr/bin/env bash

set -euo pipefail

#######################################
# description
# Globals:
#   project_root_dir
#   unique_service_names
# Arguments:
#  None
#######################################
generate_certbot_renewal_script() {
  local restart_service_array=()

  local service
  for service in "${unique_service_names[@]}"; do
    restart_service_array+=("${service}")
  done

  cat << 'EOF' > "${project_root_dir}/certbot_renew.sh"

set -e

LOG_FILE="${project_logs_dir}/certbot_renew.log"

renew_certbot() {
  # Run the certbot service with dry run first
  docker compose run --rm certbot renew --dry-run

  # If the dry run succeeds, run certbot renewal without dry run
  echo "Certbot dry run succeeded, attempting renewal..."
  docker compose run --rm certbot renew

  # Restart the nginx frontend and backend services
  docker compose restart frontend
  docker compose restart "${restart_service_array[@]}"
}

{
  echo "Running certbot renewal script on $(date)"
  renew_certbot
} | tee -a "${LOG_FILE}"
EOF
}

#######################################
# description
# Globals:
#   project_logs_dir
#   project_root_dir
# Arguments:
#  None
#######################################
generate_certbot_renewal_job() {
  generate_certbot_renewal_script

  # Make the certbot renew script executable
  chmod +x "${project_root_dir}/certbot_renew.sh"

  # Setup Cron Job
  local cron_script_path="${project_root_dir}/certbot_renew.sh"
  local cron_log_path="${project_logs_dir}/certbot_cron.log"

  # Cron job to run certbot renewal every day at midnight
  local cron_job="0 0 * * 1-7 ${cron_script_path} >> ${cron_log_path} 2>&1"

  # Check if the cron job already exists
  if ! crontab -l | grep -Fq "${cron_job}"; then
    # Add the cron job if it doesn't exist
    (crontab -l echo "${cron_job}" 2> /dev/null) | crontab -
    print_multiple_messages "Cron job added."
  else
    print_multiple_messages "Cron job already exists. No action taken."
  fi
}

#######################################
# description
# Arguments:
#  None
# Returns:
#   0 ...
#   1 ...
#######################################
wait_for_certbot_completion() {
  local attempt_count=0
  local max_attempts=12
  while ((attempt_count < max_attempts)); do

    local certbot_container_id
    local certbot_status

    certbot_container_id=$(docker compose ps -q certbot)

    # TODO: Clean up this logic
    if [[ -n ${certbot_container_id} ]]; then

      certbot_status=$(docker inspect -f '{{.State.Status}}' "${certbot_container_id}")
      print_multiple_messages "Attempt ${attempt_count}"
      print_multiple_messages "Certbot container status: ${certbot_status}"

      if [[ ${certbot_status} == "exited" ]]; then
        return 0
      elif [[ ${certbot_status} != "running" ]]; then
        print_multiple_messages "Certbot container is in an unexpected state: ${certbot_status}"
        return 1
      fi
    else
      print_multiple_messages "Certbot container is not running."
      break
    fi
    sleep 5
    ((attempt_count++))
  done
  if ((attempt_count == max_attempts)); then
    print_multiple_messages "Certbot process timed out."
    return 1
  fi
}



#######################################
# description
# Arguments:
#  None
# Returns:
#   1 ...
#######################################
run_certbot_dry_run() {
  local certbot_output
  if ! certbot_output=$(docker compose run --rm certbot 2>&1); then
    print_multiple_messages "Certbot dry-run command failed."
    print_multiple_messages "Output: ${certbot_output}"
    return 1
  fi
  if [[ ${certbot_output} == *'The dry run was successful.'* ]]; then
    print_multiple_messages "Certbot dry run successful."
    remove_dry_run_flag
    handle_staging_flags
  else
    print_multiple_messages "Certbot dry run failed."
    return 1
  fi
}

#######################################
# description
# Arguments:
#  None
#######################################
run_certbot_service() {
  print_multiple_messages "Running Certbot service..."
  handle_certbot_build_and_caching || {
    print_multiple_messages "Building Certbot service failed. Exiting."
    exit 1
  }
  run_certbot_dry_run || {
    print_multiple_messages "Running Certbot dry run failed. Exiting."
    exit 1
  }
  rebuild_and_rerun_certbot || {
    print_multiple_messages "Rebuilding and rerunning Certbot failed. Exiting."
    exit 1
  }
  wait_for_certbot_completion || {
    print_multiple_messages "Waiting for Certbot to complete failed. Exiting."
    exit 1
  }
  check_certbot_success || {
    print_multiple_messages "Checking for Certbot success failed. Exiting."
    exit 1
  }
  print_multiple_messages "Certbot process completed successfully."
}

#######################################
# description
# Arguments:
#  None
# Returns:
#   1 ...
#######################################
rebuild_and_rerun_certbot() {
  print_multiple_messages "Rebuilding and rerunning Certbot without dry-run..."
  if ! docker compose build certbot || ! docker compose up -d certbot; then
    print_multiple_messages "Failed to rebuild or run Certbot service."
    return 1
  fi
}