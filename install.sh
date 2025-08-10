#!/bin/bash
# install.sh (برای نصب فایل باینری Go)

# --- متغیرهای اصلی ---
BINARY_NAME="cloudflare_dns_bot"
INSTALL_DIR="/opt/cloudflare_dns_bot" # مسیر استاندارد برای نرم‌افزارهای جانبی
SERVICE_NAME="gocflarebot" # نام سرویس برای جلوگیری از تداخل با نسخه پایتون

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

# ۲. بررسی وجود فایل باینری
if [ ! -f "./${BINARY_NAME}" ]; then
    print_error "The binary file '${BINARY_NAME}' was not found in the current directory. Please upload it alongside this script."
fi

print_info "Starting installation for '${BINARY_NAME}'..."

# ۳. مدیریت پوشه نصب
if [ -d "$INSTALL_DIR" ]; then
    print_info "An existing installation was found."
    read -p "Do you want to REMOVE the existing installation and reinstall? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        systemctl stop $SERVICE_NAME &>/dev/null || true
        rm -rf "$INSTALL_DIR"
    else
        print_error "Installation cancelled."
    fi
fi
mkdir -p "$INSTALL_DIR"
print_success "Installation directory created at $INSTALL_DIR"

# ۴. کپی کردن فایل باینری و تنظیم دسترسی
print_info "Copying binary file and setting permissions..."
cp "./${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
print_success "Binary file is ready."

# ۵. ساخت فایل کانفیگ (config.json)
CONFIG_FILE="${INSTALL_DIR}/config.json"
print_info "Please enter your configuration details to create 'config.json':"
read -p "Enter Bot Token: " bot_token
read -p "Enter Admin User ID: " admin_id

cat > "$CONFIG_FILE" <<EOF
{
  "bot_token": "$bot_token",
  "admin_id": $admin_id
}
EOF
print_success "Config file created at ${CONFIG_FILE}"

# ۶. ساخت سرویس Systemd
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
print_info "Creating systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Go Cloudflare DNS Telegram Bot
After=network.target

[Service]
# مهم: مسیر فایل اجرایی و پوشه کاری باید مطلق باشد
ExecStart=${INSTALL_DIR}/${BINARY_NAME}
WorkingDirectory=${INSTALL_DIR}
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

# ۷. فعال‌سازی و اجرای نهایی
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo ""
print_success "Installation completed!"
print_info "The bot is now running as a service."
echo "----------------------------------------------------"
echo "To check status, run: systemctl status $SERVICE_NAME"
echo "To view live logs, run: journalctl -u $SERVICE_NAME -f"
echo "----------------------------------------------------"
