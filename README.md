Basic linux script that enables shebang, updates and upgrades repo's in Ubuntu, then installs LTSP along with CUPS and sets the server as a print server, then creates a user named "Basic" and grants them all permissions within the sudo group to run all applications.
Does NOT run 'ltsp ipxe', 'ltsp nfs', or 'ltsp initrd', nor does it create the image, usually done with 'ltsp image /', which creates the actual bootable image. These will need to be run as root separately.
I created this script to run with Ubuntu 24.04 and has been tested and working with a clean version of it.
