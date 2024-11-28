#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e
# Install the Personal Package Archive, recommended by the LTSP.org documentation
add-apt-repository ppa:ltsp
apt update

# Update and upgrade the system; refreshes repo to inlcude ppa
echo "Updating system..."
apt update && apt upgrade -y

# Install LTSP and its dependencies
echo "Installing LTSP and required dependencies..."
apt install --install-recommends ltsp ltsp-binaries dnsmasq nfs-kernel-server openssh-server squashfs-tools ethtool net-tools

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

# Configure dnsmasq in proxy mode so that it can tell the clients where to find the boot image. This is also good if you still want to use the router for DHCP leases, but the router does not support PXE boot

# Define variables
LTSP_SERVER_IP="192.168.1.1"  # Replace with your LTSP server's IP address
DNSMASQ_CONFIG="/etc/dnsmasq.conf"

# Backup the existing dnsmasq configuration file
if [ -f "$DNSMASQ_CONFIG" ]; then
    cp "$DNSMASQ_CONFIG" "${DNSMASQ_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
fi

# Write the dnsmasq configuration for proxy DHCP mode
cat <<EOF > "$DNSMASQ_CONFIG"

# Disable DNS functionality (proxy mode only)
port=0

# Proxy DHCP range (proxy mode tells clients to use the router's DHCP for IPs)
dhcp-range=192.168.1.0,proxy

# PXE boot service configuration
pxe-service=x86PC, "LTSP Boot", ltsp/pxelinux.0, $LTSP_SERVER_IP

# Specify the bootloader file
dhcp-boot=ltsp/pxelinux.0

# Specify the TFTP root directory
tftp-root=/var/lib/tftpboot
EOF

# Restart the dnsmasq service to apply the changes
systemctl restart dnsmasq

# Enable dnsmasq to start automatically on boot
systemctl enable dnsmasq

echo "dnsmasq has been configured in proxy DHCP mode and restarted."
