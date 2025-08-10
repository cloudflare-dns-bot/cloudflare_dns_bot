#!/bin/bash
# install.sh

set -e

echo "🚀 Go Cloudflare DNS Telegram Bot Installer"

# 1. نصب ابزارهای لازم (git و کامپایلر Go)
echo "📦 Installing dependencies (git, golang)..."
apt update -y
apt install git golang-go -y

# 2. گرفتن اطلاعات از کاربر
read -p "Enter Bot Token: " bot_token
read -p "Enter Admin User ID (e.g., 512345678): " admin_id

# 3. ساخت فایل config.json
CONFIG_FILE="config.json"
echo "📝 Creating config file..."
cat > "$CONFIG_FILE" <<EOF
{
  "bot_token": "$bot_token",
  "admin_id": $admin_id
}
EOF

echo "✅ Config file created successfully."

# 4. کامپایل برنامه Go
echo "🔨 Compiling the Go application..."
go build -o bot main.go

echo "✅ Application compiled successfully."

# 5. ساخت سرویس systemd
SERVICE_FILE="/etc/systemd/system/gocflarebot.service"
BINARY_PATH="$(pwd)/bot"
WORKING_DIR="$(pwd)"

echo "🔧 Creating systemd service..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Go Cloudflare DNS Telegram Bot
After=network.target

[Service]
ExecStart=$BINARY_PATH
WorkingDirectory=$WORKING_DIR
Restart=always
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 6. فعال‌سازی و اجرای سرویس
echo "🚀 Enabling and starting the service..."
systemctl daemon-reload
systemctl enable gocflarebot.service
systemctl restart gocflarebot.service

echo "✅ Installation completed successfully!"
echo "📡 To check status, run: systemctl status gocflarebot"
echo "📜 To see logs, run: journalctl -u gocflarebot -f"
