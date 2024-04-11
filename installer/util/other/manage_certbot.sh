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