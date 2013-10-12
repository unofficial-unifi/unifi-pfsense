#!/bin/sh

# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# Add the fstab entries apparently required for OpenJDK 6:
if [ $(grep -c fdesc /etc/fstab) -eq 0 ]; then
  echo -n "Adding fdesc filesystem to /etc/fstab..."
  echo -e "fdesc\t\t\t/dev/fd\t\tfdescfs\trw\t\t0\t0" >> /etc/fstab
  echo "done."
fi

if [ $(grep -c proc /etc/fstab) -eq 0 ]; then
  echo -n "Adding procfs filesystem to /etc/fstab..."
  echo -e "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0" >> /etc/fstab
  echo "done."
fi

# Run mount to mount the two new filesystems:
echo -n "Mounting new filesystems..."
/sbin/mount -a
echo " done."

# Install mongodb, OpenJDK 6, and unzip (required to unpack Ubiquiti's download):
# -F skips a package if it's already installed, without throwing an error.
echo -n "Installing required packages..."
/usr/sbin/pkg_add -vFr mongodb openjdk6 unzip
echo " done."

# Switch to a temp directory for the Unifi download:
cd `mktemp -d -t unifi`

# Download the controller from Ubiquiti (assuming acceptance of the EULA):
echo -n "Downloading the UniFi controller software..."
/usr/bin/fetch http://dl.ubnt.com/unifi/2.4.5/UniFi.unix.zip
echo " done."

# Unpack the archive into the /usr/local directory:
echo -n "Installing UniFi controller in /usr/local..."
/usr/local/bin/unzip UniFi.unix.zip -d /usr/local
echo " done."

# Update Unifi's symbolic link for mongod to point to the version we just installed:
echo -n "Updating mongod link..."
/bin/ln -sf /usr/local/bin/mongod /usr/local/UniFi/bin/mongod
echo " done."

# Fetch the rc script from github:
echo -n "Installing rc script..."
/usr/bin/fetch -o /usr/local/etc/rc.d/unifi https://raw.github.com/gozoinks/unifi-pfsense/master/rc.d/unifi
echo " done."

# Fix permissions so it'll run
chmod +x /usr/local/etc/rc.d/unifi

# Add the startup variable to rc.conf.local.
# Eventually, this step will need to be folded into pfSense, which manages the main rc.conf.
echo -n "Enabling the unifi service..."
echo "unifi_enable=YES" >> /etc/rc.conf.local
echo " done."

# Start it up:
echo -n "Starting the unifi service..."
/usr/sbin/service unifi start
echo " done."
