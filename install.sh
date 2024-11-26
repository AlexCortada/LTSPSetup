#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Update and upgrade the system
echo "Updating system..."
apt update && apt upgrade -y

# Install LTSP and its dependencies
echo "Installing LTSP and required dependencies..."
apt install -y ltsp epoptes nfs-kernel-server isc-dhcp-server

# Install CUPS for printer management
echo "Installing CUPS..."
apt install -y cups

# Create a new user called "Basic" and add to admin and sudo groups
USERNAME="Basic"
echo "Creating user $USERNAME..."
adduser --disabled-password --gecos "" $USERNAME
usermod -aG sudo $USERNAME
usermod -aG admin $USERNAME

# Allow the user to run all applications without password prompt
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# Configure CUPS to act as a network server
echo "Configuring CUPS..."
sed -i 's/Listen localhost:631/Port 631/' /etc/cups/cupsd.conf
sed -i '/<\/Location>/i Allow @LOCAL' /etc/cups/cupsd.conf
sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf
sed -i '/DefaultAuthType Basic/d' /etc/cups/cupsd.conf

# Restart CUPS service to apply changes
systemctl restart cups

# Share printers connected to the CUPS server
echo "Setting up printer sharing for CUPS..."
cupsctl --share-printers
cupsctl --remote-admin
cupsctl --remote-any
systemctl restart cups

# Disable any existing DHCP server configuration
echo "Disabling DHCP server configuration..."
systemctl stop isc-dhcp-server
systemctl disable isc-dhcp-server

# LTSP-specific configuration
echo "Configuring LTSP..."
ltsp init --yes

# Inform the user the setup is complete
echo "Setup complete! LTSP, CUPS, and user $USERNAME are configured."
