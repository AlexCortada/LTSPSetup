add-apt-repository ppa:ltsp

apt update && apt upgrade --yes

apt install --install-recommends ltsp ipxe dnsmasq nfs-kernel-server openssh-server squashfs-tools ethtool net-tools --y

ltsp dnsmasq

ltsp image /

ltsp ipxe

ltsp nfs

ltsp initrd
