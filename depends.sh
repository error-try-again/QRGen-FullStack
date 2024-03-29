#!/usr/bin/env bash
# bashsupport disable=BP5006

set -euo pipefail
#######################################
# Installs necessary packages, sets up Docker, and configures GPG for Docker.
# Globals:
#   VERSION_CODENAME
# Arguments:
#   None
#######################################
install_packages() {
  echo "Removing conflicting packages..."
  local remove_packages=(docker.io docker-doc docker-compose podman-docker containerd runc)
  for package in "${remove_packages[@]}"; do
    sudo apt-get remove -y "${package}"
  done

  echo "Installing required packages..."
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates netcat curl gnupg uidmap inotify-tools

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -y
  sudo apt-get install -y jq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

#######################################
# Uninstalls Docker and related packages.
# Arguments:
#   None
#######################################
uninstall_packages() {
  echo "Attempting to uninstall packages..."
  local packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose)
  for package in "${packages[@]}"; do
    if ! sudo apt-get purge -y "${package}"; then
      echo "Error occurred during uninstallation of ${package}."
      echo "Attempting to fix broken installs."
      sudo apt --fix-broken install
    fi
  done

  if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
    echo "Removing Docker repository..."
    sudo rm /etc/apt/sources.list.d/docker.list
  fi

  sudo apt-get autoremove -y
}

#######################################
# Adjusts sysctl settings to expose specific ports.
# Arguments:
#   1 - Port number to adjust
#######################################
adjust_sysctl_for_port() {
  local port="$1"
  local setting="net.ipv4.ip_unprivileged_port_start=${port}"

  if ! grep -q "^${setting}$" /etc/sysctl.conf; then
    echo "Adjusting sysctl settings to expose port ${port}..."
    echo "${setting}" | sudo tee -a /etc/sysctl.conf >/dev/null && sudo sysctl -p
  fi
}

#######################################
# Sets a new password for a given user with a prompt.
# Prompts the user to enter a new password.
# Globals:
#   user_name - The name of the user for whom the password is being set.
# Arguments:
#   None
#######################################
setup_user_with_prompt() {
  if [[ -z ${user_name} ]]; then
    echo "Error: user_name is not set."
    return 1
  fi

  echo "Setting a new password for ${user_name}."
  passwd "${user_name}" || {
    echo "Failed to set password for ${user_name}."
    return 3
  }
}

# Unified User Setup Function
setup_user() {
  echo "Setting up ${user_name} user..."
  if id "${user_name}" &>/dev/null; then
    local user_choice
    echo "User ${user_name} already exists."
    echo "1) Reset password"
    echo "2) Skip user setup"
    while true; do
      read -rp "Your choice (1-2): " user_choice
      case ${user_choice} in
      1 | 2) break ;;
      *) echo "Please enter a valid choice (1 or 2)." ;;
      esac
    done
    case ${user_choice} in
    1) setup_user_with_prompt ;;
    2) echo "User setup skipped." ;;
    *) echo "Invalid choice. Exiting." ;;
    esac
  else
    sudo adduser --disabled-password --gecos "" "${user_name}"
    setup_user_with_prompt
  fi
}

#######################################
# Removes a user and their home directory, with a prompt to kill active processes.
# Globals:
#   user_name
# Arguments:
#   None
#######################################
remove_user() {
  echo "Removing ${user_name} user..."
  if pgrep -u "${user_name}" >/dev/null; then
    echo "There are active processes running under the ${user_name} user."
    local response
    read -rp "Would you like to kill all processes and continue with user removal? (y/N) " response
    if [[ ${response} =~ ^[Yy][Ee]?[Ss]?$ ]]; then
      sudo pkill -9 -u "${user_name}"
      sleep 2 # Allow some time for processes to be terminated
    else
      echo "Skipping user removal."
      return
    fi
  fi

  sudo deluser --remove-home "${user_name}"
}


# 
docker_preflight() {
 systemctl disable --now docker.service docker.socket
}


#######################################
# Sets up NVM and Node.js for the specified user.
# Globals:
#   node_version
#   nvm_install_url
#   user_name
# Arguments:
#   None
#######################################
setup_nvm_node() {
  echo "Setting up NVM and Node.js..."

  if id "${user_name}" &>/dev/null; then
    sudo mkdir -p /home/"${user_name}"/.nvm
    sudo chown "${user_name}:${user_name}" /home/"${user_name}"/.nvm

    sudo -Eu "${user_name}" bash <<EOF
export NVM_DIR="/home/${user_name}/.nvm"
export npm_config_cache="/home/${user_name}/.npm"
curl -o- ${nvm_install_url} | bash
source "\$NVM_DIR/nvm.sh"
nvm install node
nvm use node
nvm alias default node
npm install -g npm
EOF
  else
    echo "User ${user_name} does not exist. Exiting..."
    exit 1
  fi
}

#######################################
# Removes NVM and Node.js for the specified user.
# Globals:
#   user_name
# Arguments:
#   None
#######################################
remove_nvm_node() {
  echo "Removing NVM and Node.js..."
  if id "${user_name}" &>/dev/null; then
    local nvm_dir="/home/${user_name}/.nvm"
    local nvm_sh="${nvm_dir}/nvm.sh"

    if [[ -s ${nvm_sh} ]]; then
      # Load NVM and uninstall Node versions
      sudo -u "${user_name}" bash -c "source ${nvm_sh} && nvm deactivate && nvm uninstall --lts && nvm uninstall --current"

      # Remove NVM directory
      sudo rm -rf "${nvm_dir}"
      echo "NVM and Node.js removed for user ${user_name}."
    else
      echo "NVM is not installed for ${user_name}. Skipping..."
    fi
  else
    echo "User ${user_name} does not exist. Exiting..."
    exit 1
  fi
}

#######################################
# Provides a menu for the installation and configuration tasks.
# Globals:
#   None
# Arguments:
#   None
#######################################
installation_menu() {
  local choice
  echo "Choose an action:"
  echo "1) Full Installation (All)"
  echo "2) Setup User Account"
  echo "3) Install Packages and Dependencies"
  echo "4) Setup NVM and Node.js"
  echo "5) Uninstall Packages and Dependencies"
  echo "6) Remove User Account"
  echo "7) Remove NVM and Node.js"
  echo "8) Full Uninstallation (All)"
  read -rp "Your choice (1-8): " choice

  case ${choice} in
1)
  setup_user
  install_packages
  setup_nvm_node
  docker_preflight
  ;;
2) setup_user ;;
3) install_packages ;;
4) setup_nvm_node ;;
5) uninstall_packages ;;
6) remove_user ;;
7) remove_nvm_node ;;
8)
  remove_nvm_node
  remove_user
  uninstall_packages
  ;;
*)
  echo "Invalid choice. Exiting."
  exit 1
  ;;
esac
}

#######################################
# Main to control the script flow.
# Globals:
#   LANG
#   LC_ALL
#   node_version
#   TERM
#   nvm_install_url
#   user_name
# Arguments:
#   0 - Script name
#   1 - User name (optional)
#######################################
main() {
  # Check for necessary privileges
  if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
  fi

  # Exports the current terminal & sets the locale to UTF-8 to the script's environment for automated execution
  export TERM=${TERM:-xterm}
  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8

  user_name="${1:-docker-primary}"
  nvm_install_url="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh"
  node_version="latest"

  installation_menu
}

main "$@"