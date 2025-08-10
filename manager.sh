#!/bin/bash
# manager.sh

# --- متغیرهای اصلی ---
INSTALL_DIR="/root/cloudflare_dns_bot"
SERVICE_NAME="cloudflarebot"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/AlirezaSedghi/cloudflare-dns-bot/main/install.sh" # آدرس اسکریپت نصب شما

# --- توابع کمکی ---
print_info() { echo -e "\e[34m$1\e[0m"; }

# --- منوی اصلی ---
show_menu() {
    clear
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃    ⚙️  Cloudflare DNS Bot Manager             ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    print_info "Installation path: $INSTALL_DIR"
    print_info "Service name: $SERVICE_NAME"
    echo "---------------------------------------------"
    echo "1) 🔄 Update Bot (Reinstall latest version)"
    echo "2) ⚙️ Configure Bot (Edit config file)"
    echo "3) 📜 View Logs"
    echo "4) 📡 Check Status"
    echo "5) 🔄 Restart Service"
    echo "6) ❌ Uninstall Bot"
    echo "0) 🚪 Exit"
    echo ""
    read -p "Your choice: " choice
}

# --- توابع عملیاتی ---
update_bot() {
    echo "The update process will download and run the latest installer script."
    echo "This will reinstall the bot with the newest stable version."
    read -p "Are you sure you want to continue? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        wget -O install_fresh.sh "$INSTALL_SCRIPT_URL"
        chmod +x install_fresh.sh
        ./install_fresh.sh
        rm install_fresh.sh
    else
        echo "Update cancelled."
    fi
    read -p "Press Enter to return to the menu..."
}

configure_bot() {
    CONFIG_FILE="$INSTALL_DIR/config.py"
    if [ -f "$CONFIG_FILE" ]; then
        nano "$CONFIG_FILE"
        echo "Restarting service to apply changes..."
        systemctl restart "$SERVICE_NAME"
        echo "Service restarted."
    else
        echo "Config file not found. Is the bot installed correctly at $INSTALL_DIR?"
    fi
    read -p "Press Enter to return to the menu..."
}

uninstall_bot() {
    read -p "ARE YOU SURE you want to uninstall the bot completely? This will delete all its files. (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        systemctl stop "$SERVICE_NAME" || true
        systemctl disable "$SERVICE_NAME" || true
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        rm -rf "$INSTALL_DIR"
        systemctl daemon-reload
        echo "Bot uninstalled successfully."
    else
        echo "Uninstallation cancelled."
    fi
    read -p "Press Enter to return to the menu..."
}

# --- حلقه اصلی ---
while true; do
    show_menu
    case $choice in
        1) update_bot ;;
        2) configure_bot ;;
        3) journalctl -u "$SERVICE_NAME" -f --no-pager ;;
        4) systemctl status "$SERVICE_NAME" ;;
        5) systemctl restart "$SERVICE_NAME"; echo "Service restarted."; sleep 2 ;;
        6) uninstall_bot ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option. Please try again."; sleep 2 ;;
    esac
done
