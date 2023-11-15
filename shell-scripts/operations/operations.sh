#!/bin/bash

# --- User Actions --- #

# Dumps logs of all containers orchestrated by the Docker Compose file.
dump_logs() {
  test_docker_env
  produce_docker_logs > "$PROJECT_LOGS_DIR/service.log" && {
    echo "Docker logs dumped to $PROJECT_LOGS_DIR/service.log"
    cat "$PROJECT_LOGS_DIR/service.log"
  }
}

# Cleans current Docker Compose setup, arranges directories, and reinitiates Docker services.
reload() {
  echo "Reloading the project..."
  test_docker_env
  setup_project_directories
  stop_containers
  generate_server_files
  configure_nginx
  build_and_run_docker
}

# Shuts down any running Docker containers associated with the project and deletes the entire project directory.
cleanup() {
  test_docker_env
  echo "Cleaning up..."
  stop_containers

  declare -A directories=(
                        ["Project"]=$PROJECT_ROOT_DIR
                        ["Frontend"]=$FRONTEND_DIR
                        ["Backend"]=$BACKEND_DIR
  )

  local dir_name
  local dir_path

  for dir_name in "${!directories[@]}"; do
    dir_path="${directories[$dir_name]}"
    if [[ -d $dir_path   ]]; then
      rm -rf "$dir_path" && cd ..
      echo "$dir_name directory $dir_path deleted."
    fi
  done

  echo "Cleanup complete."
}

#######################################
# description
# Arguments:
#  None
#######################################
update_project() {
  git stash
  git pull
}

#######################################
# Stops, removes Docker containers, images, volumes, and networks starting with 'qrgen'.
# Globals:
#   None
# Arguments:
#  None
#######################################
purge_builds() {
  test_docker_env

  echo "Identifying and purging Docker resources associated with 'qrgen'..."

  # Stop and remove containers
  if docker ps -a --format '{{.Names}}' | grep -q '^qrgen'; then
    echo "Stopping and removing 'qrgen' containers..."
    docker ps -a --format '{{.Names}}' | grep '^qrgen' | xargs -r docker stop
    docker ps -a --format '{{.Names}}' | grep '^qrgen' | xargs -r docker rm
  else
    echo "No 'qrgen' containers found."
  fi

  # Remove images
  if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '^qrgen'; then
    echo "Removing 'qrgen' images..."
    docker images --format '{{.Repository}}:{{.Tag}}' | grep '^qrgen' | xargs -r docker rmi
  else
    echo "No 'qrgen' images found."
  fi

  # Remove volumes
  if docker volume ls --format '{{.Name}}' | grep -q '^qrgen'; then
    echo "Removing 'qrgen' volumes..."
    docker volume ls --format '{{.Name}}' | grep '^qrgen' | xargs -r docker volume rm
  else
    echo "No 'qrgen' volumes found."
  fi

  # Remove networks
  if docker network ls --format '{{.Name}}' | grep -q '^qrgen'; then
    echo "Removing 'qrgen' networks..."
    docker network ls --format '{{.Name}}' | grep '^qrgen' | xargs -r docker network rm
  else
    echo "No 'qrgen' networks found."
  fi
}

#######################################
# description
# Arguments:
#  None
#######################################
quit() {
  echo "Exiting..."
  exit 0
}

#######################################
# description
# Globals:
#   USE_LETS_ENCRYPT
# Arguments:
#  None
#######################################
handle_certs() {
  # Handle Let's Encrypt configuration
  if [[ $USE_LETS_ENCRYPT == "yes"   ]]; then

    # Generate self-signed certificates if they don't exist
    generate_self_signed_certificates

    # Start cert watcher here to ensure that changes to the self-signed certs are
    # picked up by ifnotify if they are regenerated by certbot after this
    initialize_cert_watcher || {
      echo "Failed to initialize cert watcher"
      exit 1
    }

  fi
}

# Function to remove containers that conflict with Docker Compose services
remove_conflicting_containers() {
  # Extract service names from docker-compose.yml
  local service_names
  service_names=$(docker compose config --services)

  # Loop through each service name to check if corresponding container exists
  for service in $service_names; do
    # Generate the probable container name based on the folder name and service name
    # e.g. In this instance, since the project name is "QRGen" and the service
    # name is "backend", the probable container name would be "QRGen_backend_1"
    local probable_container_name="${PWD##*/}_${service}_1"

    # Check if a container with the generated name exists
    if docker ps -a --format '{{.Names}}' | grep -qw "$probable_container_name"; then
      echo "Removing existing container that may conflict: $probable_container_name"
      docker rm -f "$probable_container_name"
    else
      echo "No conflict for $probable_container_name"
    fi
  done
}

# Function to handle ambiguous Docker networks
handle_ambiguous_networks() {
  echo "Searching for ambiguous Docker networks..."
  local networks_ids
  local network_id

  # Get all custom networks (excluding default ones)
  networks_ids=$(docker network ls --filter name=qrgen --format '{{.ID}}')

  # Loop over each network ID
  for network_id in $networks_ids; do
    echo "Inspecting network $network_id for connected containers..."
    local container_ids
    local container_id
    container_ids=$(docker network inspect "$network_id" --format '{{range .Containers}}{{.Name}} {{end}}')

    for container_id in $container_ids; do
      echo "Disconnecting container $container_id from network $network_id..."
      docker network disconnect -f "$network_id" "$container_id" || {
        echo "Failed to disconnect container $container_id from network $network_id"
      }
    done

    echo "Removing network $network_id..."
    docker network rm "$network_id" || {
      echo "Failed to remove network $network_id"
    }
  done
}

#######################################
# Modifies the docker-compose.yml file to remove specified flags
# Globals:
#   PROJECT_ROOT_DIR
# Arguments:
#   1 - Flag to remove
#######################################
modify_docker_compose() {
  local flag_to_remove=$1
  local docker_compose_file="${PROJECT_ROOT_DIR}/docker-compose.yml"
  local temp_file
  temp_file="$(mktemp)"

  echo "Modifying docker-compose.yml to remove the $flag_to_remove flag..."
  sed "/certbot:/,/command:/s/$flag_to_remove//" "$docker_compose_file" > "$temp_file"

  echo "$temp_file"
}

#######################################
# Checks if the specified flag is removed from the file
# Globals:
#   None
# Arguments:
#   1 - File to check
#   2 - Flag to check for
#######################################
check_flag_removal() {
  local file=$1
  local flag=$2

  if grep --quiet -- "$flag" "$file"; then
    echo "$flag removal failed."
    rm "$file"
    exit 1
  else
    echo "$flag removed successfully."
  fi
}

#######################################
# Backs up the original file and replaces it with the modified version
# Globals:
#   PROJECT_ROOT_DIR
# Arguments:
#   1 - Original file
#   2 - Modified file
#######################################
backup_and_replace_file() {
  local original_file=$1
  local modified_file=$2

  # Backup the original file
  cp -rf "$original_file" "${original_file}.bak"

  # Replace the original file with the modified version
  mv "$modified_file" "$original_file"
  echo "File updated and original version backed up."
}

#######################################
# Removes the --dry-run flag from the docker-compose.yml file
# Globals:
#   PROJECT_ROOT_DIR
# Arguments:
#   None
#######################################
remove_dry_run_flag() {
  local temp_file

  temp_file=$(modify_docker_compose '--dry-run')
  check_flag_removal "$temp_file" '--dry-run'
  backup_and_replace_file "${PROJECT_ROOT_DIR}/docker-compose.yml" "$temp_file"
}

#######################################
# Removes the --staging flag from the docker-compose.yml file
# Globals:
#   PROJECT_ROOT_DIR
# Arguments:
#   None
#######################################
remove_staging_flag() {
  local temp_file

  temp_file=$(modify_docker_compose '--staging')
  check_flag_removal "$temp_file" '--staging'
  backup_and_replace_file "${PROJECT_ROOT_DIR}/docker-compose.yml" "$temp_file"
}

#######################################
# Builds and runs the backend service
# Globals:
#   PROJECT_ROOT_DIR
# Arguments:
#  None
#######################################
run_backend_service() {
  echo "Building and running Backend service..."
  docker compose build backend
  docker compose up -d backend
}

#######################################
# Builds and runs the frontend service
# Globals:
#   PROJECT_ROOT_DIR
# Arguments:
#  None
#######################################
run_frontend_service() {
  echo "Building and running Frontend service..."
  docker compose build frontend
  docker compose up -d frontend
}

#######################################
# Runs the Certbot service, checks for dry run success, and reruns services
# Globals:
#   PROJECT_ROOT_DIR
# Arguments:
#  None
#######################################
run_certbot_service() {
  echo "Running Certbot service..."
  docker compose build certbot

  # Capture the output of the Certbot service
  local certbot_output
  certbot_output=$(docker compose run --rm certbot)

  # Check for the success message in the output
  if [[ $certbot_output == *"The dry run was successful."* ]]; then
    echo "Certbot dry run successful."
    echo "Removing dry-run and staging flags from docker-compose.yml..."
    remove_dry_run_flag
    remove_staging_flag

    # Rebuild and rerun the Certbot service without the dry-run flag
    docker compose build certbot
    docker compose up -d certbot

    # Optionally, restart other services if needed
    echo "Restarting other services..."
    docker compose restart backend
    docker compose restart frontend
  else
    echo "Certbot dry run failed."
    exit 1
  fi
}

#######################################
# description
# Arguments:
#  None
#######################################
pre_flight() {
  # Remove containers that would conflict with `docker-compose up`
  remove_conflicting_containers || {
    echo "Failed to remove conflicting containers"
    exit 1
  }

  # Handle ambiguous networks
  handle_ambiguous_networks || {
    echo "Failed to handle ambiguous networks"
    exit 1
  }
}

# ---- Build and Run Docker ---- #
build_and_run_docker() {
  cd "$PROJECT_ROOT_DIR" || {
    echo "Failed to change directory to $PROJECT_ROOT_DIR"
    exit 1
  }

  handle_certs || {
    echo "Failed to handle certs"
    exit 1
  }

  # If Docker Compose is running, bring down the services
  if docker compose ps &> /dev/null; then
    echo "Bringing down existing Docker Compose services..."
    docker compose down || {
      echo "Failed to bring down existing Docker Compose services"
      exit 1
    }
  fi

  # Run each service separately
  run_backend_service
  run_frontend_service
  run_certbot_service

  # Dump logs or any other post-run operations
  dump_logs || {
    echo "Failed to dump logs"
    exit 1
  }
}
