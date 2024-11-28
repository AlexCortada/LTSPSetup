#!/bin/bash

set -u  # Treat unset variables as an error
trap 'echo "Error occurred at $LINENO"; exit 1' ERR  # Custom error handling

# Install the Personal Package Archive, recommended by the LTSP.org documentation
add-apt-repository ppa:ltsp

# Update and upgrade the system; refreshes repo to inlcude ppa
echo "Updating system..."
apt update && apt upgrade -y

# Install LTSP and its dependencies
echo "Installing LTSP and required dependencies..."
apt install --install-recommends ltsp ipxe dnsmasq nfs-kernel-server openssh-server squashfs-tools ethtool net-tools

# Install CUPS for printer management
echo "Installing CUPS..."
apt install -y cups

# Create a new user called "Basic" and add to admin and sudo groups
USERNAME="Basic"
echo "Creating user $USERNAME..."
adduser --disabled-password --gecos --allow-bad-names "" $USERNAME
usermod -aG sudo $USERNAME

# Allow the user to run all applications without password prompt
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# Configure CUPS to act as a network server
echo "Configuring CUPS..."
sed -i 's/Listen localhost:631/Port 631/' /etc/cups/cupsd.conf
sed -i '/<\/Location>/i Allow @LOCAL' /etc/cups/cupsd.conf
sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf
sed -i '/DefaultAuthType Basic/d' /etc/cups/cupsd.conf

# Validates and restarts the CUPS configuration
if ! cupsd -t; then
    echo "CUPS configuration syntax error detected. Restoring backup..."
    cp /etc/cups/cupsd.conf.backup /etc/cups/cupsd.conf
    systemctl restart cups
    exit 1
fi


# Share printers connected to the CUPS server
echo "Setting up printer sharing for CUPS..."
cupsctl --share-printers
cupsctl --remote-admin
cupsctl --remote-any
systemctl restart cups

#Looks for an existing isc-dhcp server service, if so stops and disables it, if not, continues
if systemctl list-unit-files | grep -q isc-dhcp-server; then
    systemctl stop isc-dhcp-server
    systemctl disable isc-dhcp-server
else
    echo "isc-dhcp-server not found, skipping..."
fi


# LTSP-specific configuration
echo "Configuring LTSP..."
ltsp init --yes

# Inform the user the setup is complete
echo "Setup complete! LTSP, CUPS, and user $USERNAME are configured."

# Configure dnsmasq in proxy mode so that it can tell the clients where to find the boot image. This is also good if you still want to use the router for DHCP leases, but the router does not support PXE boot

# Ensures the correct permissions for the dnsmasq.conf file before writing the new info
if [ ! -w "$(dirname "$DNSMASQ_CONFIG")" ]; then
    echo "Cannot write to $(dirname "$DNSMASQ_CONFIG"). Please check permissions."
    exit 1
fi

# Define variables
LTSP_SERVER_IP=$(hostname -I | awk '{print $1}')  # Automatically detect server IP
#LTSP_SERVER_IP="192.168.1.1"  # Replace with your LTSP server's IP address, this hardcodes the ip of the server in the config file
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
dhcp-range=192.168.1.100,192.168.1.200,proxy

# PXE boot service configuration
pxe-service=x86PC, "LTSP Boot", ltsp/pxelinux.0, $LTSP_SERVER_IP

# Specify the bootloader file
dhcp-boot=ltsp/pxelinux.0

# Specify the TFTP root directory
tftp-root=/var/lib/tftpboot
EOF

# Validate dnsmasq configuration
if ! dnsmasq --test; then
    echo "Error: Invalid dnsmasq configuration. Restoring backup..."
    cp "${DNSMASQ_CONFIG}.backup" "$DNSMASQ_CONFIG"
    exit 1
fi

# Restart the dnsmasq service to apply the changes
systemctl restart dnsmasq

# Enable dnsmasq to start automatically on boot
systemctl enable dnsmasq

# Inform the user
echo "dnsmasq has been configured in proxy DHCP mode and restarted."
echo "Setup complete!"
echo "LTSP server IP: $LTSP_SERVER_IP"
echo "CUPS and user $USERNAME have been configured."
echo "dnsmasq is set up in proxy DHCP mode."


