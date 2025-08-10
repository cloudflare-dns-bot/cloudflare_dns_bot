#!/bin/bash
# install.sh (نسخه بروز شده و پایدار)

# --- متغیرهای اصلی ---
REPO_OWNER="cloudflare-dns-bot"
REPO_NAME="cloudflare_dns_bot"
INSTALL_DIR="/root/cloudflare_dns_bot"
SERVICE_NAME="cloudflarebot"

# --- توابع کمکی برای نمایش پیام ---
print_info() { echo -e "\e[34mINFO: $1\e[0m"; }
print_success() { echo -e "\e[32m✅ SUCCESS: $1\e[0m"; }
print_error() { echo -e "\e[31m❌ ERROR: $1\e[0m"; exit 1; }

# --- شروع اسکریپت ---
set -e # توقف اسکریپت در صورت بروز هرگونه خطا

# ۱. بررسی دسترسی روت
if [ "$(id -u)" -ne 0 ]; then
   print_error "This script must be run as root. Please use 'sudo' or log in as root."
fi

print_info "Starting the Cloudflare DNS Bot installer..."

# ۲. نصب ابزارهای مورد نیاز
print_info "Installing dependencies (curl, unzip, python3-venv, git)..."
apt-get update -y
apt-get install -y curl unzip python3-venv git

# ۳. پیدا کردن آدرس آخرین نسخه از GitHub API
print_info "Finding the latest release from GitHub..."
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
DOWNLOAD_URL=$(curl -s $API_URL | grep "browser_download_url" | grep ".zip" | head -n 1 | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    print_error "Could not find the download URL for the latest release. Please check the repository."
fi
print_success "Found latest release: $DOWNLOAD_URL"

# ۴. مدیریت پوشه نصب
if [ -d "$INSTALL_DIR" ]; then
    print_info "An existing installation was found at $INSTALL_DIR."
    read -p "Do you want to REMOVE the existing installation and reinstall? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        print_info "Stopping and disabling the service, then removing the old directory..."
        systemctl stop $SERVICE_NAME &>/dev/null || true
        systemctl disable $SERVICE_NAME &>/dev/null || true
        rm -rf "$INSTALL_DIR"
    else
        print_error "Installation cancelled by the user."
    fi
fi
mkdir -p "$INSTALL_DIR"
print_success "Installation directory created at $INSTALL_DIR"

# ۵. دانلود و استخراج امن فایل‌ها
TMP_DIR=$(mktemp -d)
print_info "Downloading files to temporary directory: $TMP_DIR"
wget -O "$TMP_DIR/release.zip" "$DOWNLOAD_URL"
unzip "$TMP_DIR/release.zip" -d "$TMP_DIR"

# پیدا کردن نام پوشه استخراج شده و انتقال محتویات آن
EXTRACTED_FOLDER=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d)
if [ -z "$EXTRACTED_FOLDER" ]; then
    print_error "Could not find the extracted folder."
fi
mv "$EXTRACTED_FOLDER"/* "$INSTALL_DIR/"
rm -rf "$TMP_DIR" # پاک کردن فایل‌های موقت
print_success "Files extracted to installation directory."

# ۶. پیکربندی
cd "$INSTALL_DIR"
print_info "Please enter your configuration details:"
read -p "Enter Bot Token: " bot_token
read -p "Enter CLOUDFLARE_EMAIL: " cf_email
read -p "Enter CLOUDFLARE_API_KEY: " cf_api
read -p "Enter Admin User ID (e.g., 512345678): " admin_id

cp config.py.template config.py
sed -i "s/BOT_TOKEN = \"\"/BOT_TOKEN = \"$bot_token\"/" config.py
sed -i "s/CLOUDFLARE_EMAIL = \"\"/CLOUDFLARE_EMAIL = \"$cf_email\"/" config.py
sed -i "s/CLOUDFLARE_API_KEY = \"\"/CLOUDFLARE_API_KEY = \"$cf_api\"/" config.py
sed -i "s/ADMIN_ID = \"\"/ADMIN_ID = $admin_id/" config.py
print_success "Config file created."

# ۷. نصب محیط مجازی پایتون
print_info "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate
print_success "Python environment is ready."

# ۸. ساخت سرویس Systemd
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
print_info "Creating systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Cloudflare DNS Telegram Bot (Python)
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

# ۹. فعال‌سازی و اجرای نهایی
print_info "Enabling and starting the service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo ""
print_success "Installation completed!"
print_info "The bot is now running in the background."
echo "----------------------------------------------------"
echo "To check status, run: systemctl status $SERVICE_NAME"
echo "To view live logs, run: journalctl -u $SERVICE_NAME -f"
echo "----------------------------------------------------"
