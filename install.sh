#!/bin/bash

# ==============================================================================
#                      Cloudflare DNS Telegram Bot Management Script
# ==============================================================================
# This script provides a menu to install, uninstall, update, and manage the
# Cloudflare DNS Telegram bot service.
# ==============================================================================

# --- Script Configuration and Variables ---
set -e # Exit immediately if a command exits with a non-zero status.

# !!! IMPORTANT: CHANGE THIS TO YOUR GITHUB REPOSITORY !!!
# The script will download the pre-compiled binary from your repo's releases.
GITHUB_REPO="cloudflare-dns-bot/cloudflare_dns_bot"

# --- Shared Variables ---
EXECUTABLE_NAME="cloudflare-dns-bot"
INSTALL_PATH="/usr/local/bin"
WORKING_DIR="/etc/cloudflare-dns-bot"
SERVICE_NAME="cloudflare-dns-bot.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
CONFIG_FILE="${WORKING_DIR}/config.json"

# --- Helper Functions for Colored Output ---
print_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
print_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
print_error() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; }
print_warn() { echo -e "\e[33m[WARN]\e[0m $1"; }


# ==============================================================================
#                               UNINSTALL FUNCTION
# ==============================================================================
uninstall_bot() {
    echo "----------------------------------------------"
    echo "--- Uninstalling Cloudflare DNS Bot ---"
    echo "----------------------------------------------"
    print_warn "WARNING: This will remove the binary, all configuration files (including tokens), data, and the systemd service. This cannot be undone."
    echo ""

    read -p "Are you sure you want to continue? [y/N]: " confirmation
    if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
        echo "Uninstallation cancelled."
        return 0
    fi

    print_info "Stopping and disabling the service..."
    if systemctl list-units --full -all | grep -Fq "${SERVICE_NAME}"; then
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            systemctl stop "$SERVICE_NAME"
            print_info "Service stopped."
        fi
        if systemctl is-enabled --quiet "$SERVICE_NAME"; then
            systemctl disable "$SERVICE_NAME"
            print_info "Service disabled."
        fi
    else
        print_warn "Service not found. Skipping."
    fi

    if [ -f "$SERVICE_FILE" ]; then
        print_info "Removing systemd service file..."
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        print_info "Systemd daemon reloaded."
    fi

    if [ -f "${INSTALL_PATH}/${EXECUTABLE_NAME}" ]; then
        print_info "Removing executable: ${INSTALL_PATH}/${EXECUTABLE_NAME}"
        rm -f "${INSTALL_PATH}/${EXECUTABLE_NAME}"
    fi

    if [ -d "$WORKING_DIR" ]; then
        print_info "Removing data directory and all its contents: ${WORKING_DIR}"
        rm -rf "$WORKING_DIR"
    fi

    echo ""
    print_success "Cloudflare DNS Bot has been completely uninstalled."
}

# ==============================================================================
#                            INSTALL/UPDATE FUNCTION
# ==============================================================================
install_or_update_bot() {
    print_info "Starting Bot Installation/Update..."

    if [ "$GITHUB_REPO" == "YourUsername/YourRepoName" ]; then
        print_error "Please edit the script and set the GITHUB_REPO variable on line 19."
        return 1
    fi

    print_info "Checking for dependencies (curl, jq)..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y > /dev/null && apt-get install -y -qq curl jq > /dev/null
    elif command -v yum &> /dev/null; then
        yum install -y curl jq > /dev/null
    else
        print_warn "Unsupported package manager. Please install 'curl' and 'jq' manually."
    fi
    print_success "Dependencies are satisfied."

    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ASSET_NAME="cloudflare-dns-bot-amd64" ;;
        aarch64 | arm64) ASSET_NAME="cloudflare-dns-bot-arm64" ;;
        *) print_error "Unsupported architecture: $ARCH."; return 1 ;;
    esac

    print_info "Fetching the latest version from GitHub ($GITHUB_REPO)..."
    API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    DOWNLOAD_URL=$(curl -sSL "$API_URL" | jq -r ".assets[] | select(.name == \"${ASSET_NAME}\") | .browser_download_url")

    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
        print_error "Failed to find a download URL for asset '${ASSET_NAME}'."
        print_error "Please ensure a release exists and contains the correct asset file for your architecture."
        return 1
    fi
    print_info "Found download URL."

    print_info "Downloading the latest binary (${ASSET_NAME})..."
    TMP_DIR=$(mktemp -d); trap 'rm -rf -- "$TMP_DIR"' EXIT;
    if ! curl -sSLf -o "$TMP_DIR/${EXECUTABLE_NAME}" "$DOWNLOAD_URL"; then
        print_error "Download failed. Please check the URL and your connection."
        return 1
    fi
    print_success "Binary downloaded successfully."

    if systemctl is-active --quiet $SERVICE_NAME; then
        print_warn "An existing service is running. It will be stopped for the update."
        systemctl stop $SERVICE_NAME
    fi

    print_info "Installing executable to ${INSTALL_PATH}..."
    mv "$TMP_DIR/${EXECUTABLE_NAME}" "${INSTALL_PATH}/${EXECUTABLE_NAME}"
    chmod +x "${INSTALL_PATH}/${EXECUTABLE_NAME}"
    print_success "Binary installed/updated."

    print_info "Creating working directory at ${WORKING_DIR}..."
    mkdir -p "$WORKING_DIR"

    if [ ! -f "$CONFIG_FILE" ]; then
        print_info "First-time setup: Please provide initial configuration."
        read -p "Enter your Telegram Bot Token: " BOT_TOKEN
        read -p "Enter your numeric Admin User ID: " ADMIN_ID
        read -p "Enter your Cloudflare Email: " CF_EMAIL
        read -p "Enter your Cloudflare API Key: " CF_API_KEY


        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            print_error "Invalid Admin ID. It must be a number. Installation aborted."
            return 1
        fi

        print_info "Creating config file: ${CONFIG_FILE}"
        cat > "$CONFIG_FILE" << EOF
{
  "bot_token": "${BOT_TOKEN}",
  "cloudflare_email": "${CF_EMAIL}",
  "cloudflare_api_key": "${CF_API_KEY}",
  "admin_id": ${ADMIN_ID}
}
EOF
    else
        print_info "Existing configuration found, skipping initial setup."
    fi

    print_info "Configuring systemd service..."
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Cloudflare DNS Telegram Bot
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${INSTALL_PATH}/${EXECUTABLE_NAME}
WorkingDirectory=${WORKING_DIR}
Restart=always
RestartSec=5
LimitNOFILE=65536
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_success "Systemd service file created/updated."

    print_info "Enabling and starting the service..."
    systemctl enable --now ${SERVICE_NAME}

    echo ""
    print_success "Installation/Update complete!"
    echo "------------------------------------------------------------"
    sleep 2
    if systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Bot service is now RUNNING!"
    else
        print_error "The service failed to start. Please check logs with: journalctl -u ${SERVICE_NAME}"
    fi
    echo "------------------------------------------------------------"
}


# ==============================================================================
#                            EDIT CONFIG FUNCTION
# ==============================================================================
edit_config() {
    check_if_installed || return 1

    print_info "Editing configuration file: ${CONFIG_FILE}"
    echo "Current values are shown in [brackets]. Press Enter to keep the current value."
    echo ""

    # Read current values
    CURRENT_BOT_TOKEN=$(jq -r .bot_token "$CONFIG_FILE")
    CURRENT_ADMIN_ID=$(jq -r .admin_id "$CONFIG_FILE")
    CURRENT_CF_EMAIL=$(jq -r .cloudflare_email "$CONFIG_FILE")
    CURRENT_CF_API_KEY=$(jq -r .cloudflare_api_key "$CONFIG_FILE")

    # Prompt for new values
    read -p "Enter Telegram Bot Token [${CURRENT_BOT_TOKEN:0:8}...]: " NEW_BOT_TOKEN
    read -p "Enter Admin User ID [${CURRENT_ADMIN_ID}]: " NEW_ADMIN_ID
    read -p "Enter Cloudflare Email [${CURRENT_CF_EMAIL}]: " NEW_CF_EMAIL
    read -p "Enter Cloudflare API Key [${CURRENT_CF_API_KEY:0:5}...]: " NEW_CF_API_KEY

    # Use new value if provided, otherwise keep the old one
    FINAL_BOT_TOKEN=${NEW_BOT_TOKEN:-$CURRENT_BOT_TOKEN}
    FINAL_ADMIN_ID=${NEW_ADMIN_ID:-$CURRENT_ADMIN_ID}
    FINAL_CF_EMAIL=${NEW_CF_EMAIL:-$CURRENT_CF_EMAIL}
    FINAL_CF_API_KEY=${NEW_CF_API_KEY:-$CURRENT_CF_API_KEY}

    if ! [[ "$FINAL_ADMIN_ID" =~ ^[0-9]+$ ]]; then
        print_error "Invalid Admin ID. It must be a number. Update aborted."
        return 1
    fi

    # Write the new configuration
    print_info "Updating config file..."
    cat > "$CONFIG_FILE" << EOF
{
  "bot_token": "${FINAL_BOT_TOKEN}",
  "cloudflare_email": "${FINAL_CF_EMAIL}",
  "cloudflare_api_key": "${FINAL_CF_API_KEY}",
  "admin_id": ${FINAL_ADMIN_ID}
}
EOF
    print_success "Configuration updated."
    
    read -p "Do you want to restart the service to apply changes? [Y/n]: " restart_choice
    if [[ "$restart_choice" != "n" && "$restart_choice" != "N" ]]; then
        restart_service
    fi
}


# ==============================================================================
#                       SERVICE MANAGEMENT FUNCTIONS
# ==============================================================================
check_if_installed() {
    if [ ! -f "${INSTALL_PATH}/${EXECUTABLE_NAME}" ]; then
        print_error "Bot is not installed. Please install it first."
        return 1
    fi
    return 0
}

restart_service() {
    check_if_installed || return 1
    print_info "Restarting bot service..."
    systemctl restart ${SERVICE_NAME}
    print_success "Service restarted."
}

stop_service() {
    check_if_installed || return 1
    print_info "Stopping bot service..."
    systemctl stop ${SERVICE_NAME}
    print_success "Service stopped."
}

status_service() {
    check_if_installed || return 1
    print_info "Showing status for bot service..."
    systemctl status ${SERVICE_NAME} --no-pager
}

view_logs() {
    check_if_installed || return 1
    print_info "Displaying live logs... (Press Ctrl+C to exit)"
    journalctl -u ${SERVICE_NAME} -f
}


# ==============================================================================
#                                  MAIN MENU
# ==============================================================================
show_menu() {
    clear
    echo "=========================================="
    echo "       Cloudflare DNS Bot Manager"
    echo "=========================================="
    if [ -f "${INSTALL_PATH}/${EXECUTABLE_NAME}" ]; then
        echo -e "Status: \e[32mInstalled\e[0m"
        if systemctl is-active --quiet ${SERVICE_NAME}; then
            echo -e "Service: \e[32mRunning\e[0m"
        else
            echo -e "Service: \e[31mStopped\e[0m"
        fi
    else
        echo -e "Status: \e[31mNot Installed\e[0m"
    fi
    echo "------------------------------------------"
    echo "1. Install or Update Bot"
    echo "2. Uninstall Bot"
    echo "3. Edit Configuration"
    echo "4. Restart Service"
    echo "5. Stop Service"
    echo "6. View Service Status"
    echo "7. View Live Logs"
    echo "8. Exit"
    echo "------------------------------------------"
}

# --- Main Script Execution Logic ---
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root. Please use 'sudo bash $0'."
    exit 1
fi

while true; do
    show_menu
    read -p "Please enter your choice [1-8]: " choice

    case $choice in
        1) install_or_update_bot ;;
        2) uninstall_bot ;;
        3) edit_config ;;
        4) restart_service ;;
        5) stop_service ;;
        6) status_service ;;
        7) view_logs ;;
        8) echo "Exiting."; exit 0 ;;
        *) print_warn "Invalid option. Please try again." ;;
    esac
    echo ""
    read -n 1 -s -r -p "Press any key to return to the menu..."
done
