#!/bin/bash

# Color functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to detect the operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}Unable to detect operating system.${NC}"
        exit 1
    fi
}

# Function to install Fail2ban
install_fail2ban() {
    echo -e "${YELLOW}Installing Fail2ban...${NC}"
    case "$OS" in
        debian|ubuntu|pop)
            sudo apt-get update
            sudo apt-get install -y fail2ban
            ;;
    esac
}

# Function to configure Fail2ban
configure_fail2ban() {
    echo -e "${YELLOW}Configuring Fail2ban...${NC}"
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    # Configure jail.local for all systems
    sudo bash -c 'cat > /etc/fail2ban/jail.local' << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 600
findtime  = 600
maxretry = 3
[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
backend = systemd
EOF
    sudo systemctl restart fail2ban
}

# Main script execution
main() {
    detect_os
    install_fail2ban
    configure_fail2ban
    echo -e "${GREEN}Fail2ban installation and configuration completed.${NC}"
}

# Run the main function
main
