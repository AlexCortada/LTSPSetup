#Add the ppa repo to install dependancies for ltsp
add-apt-repository ppa:ltsp

#apt upgrade and apt update to update all packages
sudo apt-get update && sudo apt-get -y upgrade

#Installs the LTSP packages and dependencies
apt install --install-recommends ltsp ipxe dnsmasq nfs-kernel-server openssh-server squashfs-tools ethtool net-tools -y

#enables dnsmasq for LTSP
ltsp dnsmasq

#creates the squashfs image in a rootless folder for client boot
ltsp image /

#enables the pxe boot menu and services
ltsp ipxe

#enables nfs
ltsp nfs

#runs the initrd command which allows for changes to permissions and accounts to transfer over to the booted images
ltsp initrd

#installs CUPS printers service
apt install cups

#Looks for the HP application
apt-cache search hplip

#Installs the HP toolbox GUI and app
sudo apt install hplip hplip-gui

#Enables unprivelidged apps, such as Chrome, to run on Apparmor
sudo systemct -w kernel.apparmor_restrict_unprivileged_userns=0

#Pulls the Google Chrome installation file and keys, adds the repo, updates, then installs Chrome stable via apt
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - 
sudo sh -c 'echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
sudo apt-get update
sudo apt-get install google-chrome-stable
