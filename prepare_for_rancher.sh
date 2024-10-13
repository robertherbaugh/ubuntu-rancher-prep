#!/bin/bash

# Error handling function
handle_error() {
    echo "ERROR: $1. Exiting script."
    exit 1
}

# Update, upgrade and install required packages with error handling
echo "Starting VM template preparation..."

echo "Updating package list..."
sudo apt-get update -y || handle_error "Failed to update package list"

echo "Upgrading installed packages..."
sudo apt-get upgrade -y || handle_error "Failed to upgrade installed packages"

# List of preliminary packages
prelim_packages=(
    ca-certificates
    cloud-image-utils
    cloud-initramfs-growroot
    open-iscsi
    openssh-server
    open-vm-tools
    apparmor-utils
    cloud-init
    cloud-guest-utils
)

# Install preliminary packages in a loop
echo "Installing preliminary packages..."
for package in "${prelim_packages[@]}"; do
    sudo apt-get install -y "$package" || handle_error "Failed to install $package package"
done

# List of required packages
required_packages=(
    curl
    wget
    git
    net-tools
    unzip
)

# Install required packages in a loop
echo "Installing required packages..."
sudo apt-get install -y "${required_packages[@]}" || handle_error "Failed to install required packages"


# Disable swap and prevent it from being turned on
echo "Disabling swap..."
sudo swapoff -a || handle_error "Failed to disable swap"
sudo sed -i '/ swap / s/^\(.*\)$/#/g' /etc/fstab || handle_error "Failed to disable swap in /etc/fstab"

# Reset the VM as per Rancher template preparation guidelines

# Cleaning logs
echo "Cleaning logs..."
if [ -f /var/log/audit/audit.log ]; then
  cat /dev/null > /var/log/audit/audit.log || handle_error "Failed to clean /var/log/audit/audit.log"
fi
if [ -f /var/log/wtmp ]; then
  cat /dev/null > /var/log/wtmp || handle_error "Failed to clean /var/log/wtmp"
fi
if [ -f /var/log/lastlog ]; then
  cat /dev/null > /var/log/lastlog || handle_error "Failed to clean /var/log/lastlog"
fi

# Cleaning udev rules
echo "Cleaning udev rules..."
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
  rm /etc/udev/rules.d/70-persistent-net.rules || handle_error "Failed to remove /etc/udev/rules.d/70-persistent-net.rules"
fi

# Cleaning the /tmp directories
echo "Cleaning /tmp directories..."
rm -rf /tmp/* || handle_error "Failed to clean /tmp directory"
rm -rf /var/tmp/* || handle_error "Failed to clean /var/tmp directory"

# Cleaning the SSH host keys
echo "Cleaning SSH host keys..."
rm -f /etc/ssh/ssh_host_* || handle_error "Failed to clean SSH host keys"

# Cleaning the machine-id
echo "Cleaning machine-id..."
truncate -s 0 /etc/machine-id || handle_error "Failed to truncate /etc/machine-id"
rm /var/lib/dbus/machine-id || handle_error "Failed to remove /var/lib/dbus/machine-id"
ln -s /etc/machine-id /var/lib/dbus/machine-id || handle_error "Failed to create symlink for machine-id"

# Cleaning the shell history
echo "Cleaning shell history..."
unset HISTFILE
history -cw || handle_error "Failed to clean shell history"
echo > ~/.bash_history
rm -fr /root/.bash_history || handle_error "Failed to remove root's bash history"

# Truncating hostname, hosts, resolv.conf, and setting hostname to localhost
echo "Resetting network configuration and hostname..."
truncate -s 0 /etc/hostname || handle_error "Failed to truncate /etc/hostname"
truncate -s 0 /etc/hosts || handle_error "Failed to truncate /etc/hosts"
truncate -s 0 /etc/resolv.conf || handle_error "Failed to truncate /etc/resolv.conf"
hostnamectl set-hostname localhost || handle_error "Failed to set hostname to localhost"

# Clean cloud-init
echo "Cleaning cloud-init data..."
cloud-init clean -s -l || handle_error "Failed to clean cloud-init"

# Final message indicating successful preparation
echo "VM template preparation completed successfully."

# Ask user if they wish to shut down the machine
read -p "Do you want to shut down the machine now? (y/n): " shutdown_choice

if [ "$shutdown_choice" == "y" ] || [ "$shutdown_choice" == "Y" ]; then
    echo "User chose to shut down the machine."
    echo "Shutting down the machine..."
    sudo shutdown now || handle_error "Failed to shut down the machine"
else
    echo "User chose not to shut down the machine."
    echo "VM preparation completed, and the system will remain running."
fi
