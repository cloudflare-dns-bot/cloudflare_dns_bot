#!/bin/bash
# setup.sh

# --- متغیرهای اصلی ---
INSTALL_DIR="/root/cloudflare_dns_bot"
REPO_URL="https://github.com/cloudflare-dns-bot/cloudflare_dns_bot.git"
SERVICE_NAME="cloudflarebot" # نام سرویس بر اساس اسکریپت اصلی پروژه

# --- توابع منو ---
show_menu() {
    clear
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃    ⚙️  Cloudflare DNS Bot Manager (Python)    ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo "1) 🛠  Install Bot"
    echo "2) ⚙️  Configure Bot"
    echo "3) 🔄  Update Bot"
    echo "4) ❌  Uninstall Bot"
    echo "5) 📜  View Logs"
    echo "6) 📡  Check Status"
    echo "0) 🚪  Exit"
    echo ""
    read -p "Your choice: " choice
}

install_bot() {
    echo "📦 Installing the bot..."
    if [ -d "$INSTALL_DIR" ]; then
        echo "⚠️ A previous installation exists. Uninstall it first or choose another directory."
    else
        # کلون کردن ریپازیتوری
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR" || exit
        # اجرای اسکریپت نصب اصلی خود پروژه
        bash install.sh
        echo "✅ Installation completed successfully."
    fi
    read -p "⏎ Press Enter to return to the menu..." _
}

configure_bot() {
    # فایل کانفیگ در این پروژه config.py است
    CONFIG_FILE="$INSTALL_DIR/config.py"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚠️ Config file not found. Please install the bot first."
    else
        echo "📝 Opening the config file with nano..."
        sleep 1
        nano "$CONFIG_FILE"
        echo "🔄 Restarting the bot service to apply changes..."
        systemctl restart "$SERVICE_NAME"
        echo "✅ Configuration saved and bot restarted."
    fi
    read -p "⏎ Press Enter to return to the menu..." _
}

update_bot() {
    if [ ! -d "$INSTALL_DIR/.git" ]; then
        echo "⚠️ Git repository not found. Please install the bot first."
    else
        echo "🔄 Updating the bot to the latest version..."
        cd "$INSTALL_DIR" || exit
        # دریافت آخرین تغییرات از گیت
        git fetch origin
        git reset --hard origin/main # یا هر برنچی که استفاده می‌کنید
        git pull origin main

        # به روز رسانی پکیج‌های پایتون در صورت تغییر requirements.txt
        echo "🐍 Updating Python packages..."
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        deactivate

        echo "🔄 Restarting the bot service..."
        systemctl restart "$SERVICE_NAME"
        echo "✅ Bot updated and restarted successfully."
    fi
    read -p "⏎ Press Enter to return to the menu..." _
}

uninstall_bot() {
    echo "❌ Uninstalling the bot completely..."
    systemctl stop "$SERVICE_NAME" || true
    systemctl disable "$SERVICE_NAME" || true
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
    rm -rf "$INSTALL_DIR"
    echo "✅ Bot, service, and all files have been removed."
    read -p "⏎ Press Enter to return to the menu..." _
}

view_logs() {
    echo "📜 Displaying live logs... Press Ctrl+C to exit."
    journalctl -u "$SERVICE_NAME" -f --no-pager
    read -p "⏎ Press Enter to return to the menu..." _
}

check_status() {
    systemctl status "$SERVICE_NAME"
    read -p "⏎ Press Enter to return to the menu..." _
}

# --- حلقه اصلی برنامه ---
while true; do
    show_menu
    case $choice in
        1) install_bot ;;
        2) configure_bot ;;
        3) update_bot ;;
        4) uninstall_bot ;;
        5) view_logs ;;
        6) check_status ;;
        0) echo "👋 Exiting. Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option. Please choose a valid one."; sleep 2 ;;
    esac
done
