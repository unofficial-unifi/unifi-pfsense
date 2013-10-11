#!/bin/sh

# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# Add the fstab entries apparently required for OpenJDK 6:
echo "fdesc /dev/fd fdescfs rw 0 0" >> /etc/fstab
echo "proc /proc procfs rw 0 0" >> /etc/fstab

# Run mount to mount the two new filesystems:
/sbin/mount -a

# Install mongodb, OpenJDK 6, and unzip (required to unpack Ubiquiti's download):
/usr/sbin/pkg_add -r mongodb openjdk6 unzip

# Switch to a temp directory for the Unifi download:
cd `mktemp -d -t unifi`

# Download the controller from Ubiquiti (assuming acceptance of the EULA):
/usr/bin/fetch http://dl.ubnt.com/unifi/2.4.5/UniFi.unix.zip

# Unpack the archive into the /usr/local directory:
/usr/local/bin/unzip UniFi.unix.zip -d /usr/local

# Update Unifi's symbolic link for mongod to point to the version we just installed:
/bin/ln -sf /usr/local/bin/mongod /usr/local/UniFi/bin/mongod

# Create the rc.d script for automatic startup/shutdown...
# Thinking a heredoc insertion of the script, dumped directly to a ${name} file in /etc/rc.d
# cat <<'EOF'
# (script)
# EOF > /etc/rc.d/${name}

# Add the startup variable to rc.conf.local.
# Eventually, this step will need to be folded into pfSense, which manages the main rc.conf.
echo "unifi_enable=YES" >> /etc/rc.conf.local

# Start it up:
/usr/sbin/service unifi start
