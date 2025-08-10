#!/bin/bash
# install.sh (نسخه جدید با حالت عیب‌یابی)

# --- متغیرهای اصلی ---
REPO_OWNER="cloudflare-dns-bot"
REPO_NAME="cloudflare_dns_bot"
INSTALL_DIR="/root/cloudflare_dns_bot"
SERVICE_NAME="cloudflarebot"

# --- توابع کمکی ---
print_info() { echo -e "\e[34mINFO: $1\e[0m"; }
print_success() { echo -e "\e[32m✅ SUCCESS: $1\e[0m"; }
print_error() { echo -e "\e[31m❌ ERROR: $1\e[0m"; exit 1; }

# --- شروع اسکریپت ---
set -e

# ۱. بررسی دسترسی روت
if [ "$(id -u)" -ne 0 ]; then
   print_error "This script must be run as root. Please use 'sudo' or log in as root."
fi

print_info "Starting the Cloudflare DNS Bot installer (Debug Mode)..."

# ۲. نصب ابزارهای مورد نیاز
print_info "Installing dependencies (curl, unzip, python3-venv, git)..."
apt-get update -y > /dev/null
apt-get install -y curl unzip python3-venv git > /dev/null

# ۳. پیدا کردن آدرس آخرین نسخه
print_info "Finding the latest release from GitHub..."
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"

# ---- بخش عیب‌یابی ----
print_info "Fetching data from API: $API_URL"
API_RESPONSE=$(curl -s "$API_URL")
echo "-----------[ RAW API Response ]-----------"
echo "$API_RESPONSE"
echo "------------------------------------------"
# ----------------------

DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep "browser_download_url" | grep ".zip" | head -n 1 | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    print_error "Could not find 'browser_download_url' in the API response. Please check the output above and verify your release on GitHub."
fi
print_success "Found latest release URL: $DOWNLOAD_URL"

# --- ادامه‌ی مراحل نصب (بدون تغییر) ---
if [ -d "$INSTALL_DIR" ]; then
    read -p "An existing installation was found. Reinstall? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        systemctl stop $SERVICE_NAME &>/dev/null || true
        rm -rf "$INSTALL_DIR"
    else
        print_error "Installation cancelled."
    fi
fi
mkdir -p "$INSTALL_DIR"

TMP_DIR=$(mktemp -d)
wget -q --show-progress -O "$TMP_DIR/release.zip" "$DOWNLOAD_URL"
unzip "$TMP_DIR/release.zip" -d "$TMP_DIR"
EXTRACTED_FOLDER=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d)
mv "$EXTRACTED_FOLDER"/* "$INSTALL_DIR/"
rm -rf "$TMP_DIR"

cd "$INSTALL_DIR"
print_info "Please enter your configuration details:"
read -p "Enter Bot Token: " bot_token
read -p "Enter CLOUDFLARE_EMAIL: " cf_email
read -p "Enter CLOUDFLARE_API_KEY: " cf_api
read -p "Enter Admin User ID: " admin_id

cp config.py.template config.py
sed -i "s/BOT_TOKEN = \"\"/BOT_TOKEN = \"$bot_token\"/" config.py
sed -i "s/CLOUDFLARE_EMAIL = \"\"/CLOUDFLARE_EMAIL = \"$cf_email\"/" config.py
sed -i "s/CLOUDFLARE_API_KEY = \"\"/CLOUDFLARE_API_KEY = \"$cf_api\"/" config.py
sed -i "s/ADMIN_ID = \"\"/ADMIN_ID = $admin_id/" config.py

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt > /dev/null
deactivate

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Cloudflare DNS Telegram Bot
After=network.target
[Service]
ExecStart=${INSTALL_DIR}/venv/bin/python ${INSTALL_DIR}/bot.py
WorkingDirectory=${INSTALL_DIR}
Restart=always
RestartSec=10
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

print_success "Installation completed successfully!"
print_info "To check status, run: systemctl status $SERVICE_NAME"
