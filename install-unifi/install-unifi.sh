#!/bin/sh
# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# CONFIG OPTIONS
# Note: I've set these as of 2015-03-07.
# __PLEASE FIX RC_SCRIPT_URL WHEN YOU MERGE THIS PR__
UNIFI_SOFTWARE_URL="http://www.ubnt.com/downloads/unifi/3.2.10/UniFi.unix.zip"
RC_SCRIPT_URL="https://raw.githubusercontent.com/kohenkatz/unifi-pfsense/pfsense-2.2/rc.d/unifi"
PFSENSE_VERSION_SUPPORTED="2.2-RELEASE"

# ----- FUNCTIONS HERE ---- 

# attempts to install package command. if it can't a missing package it will bail out.
pkg_install()
{
  echo -n "Attempting to install $1..."
  pkg info $1 > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo " Already installed. Not doing anything."
  else
    # install, hit "yes" to everything...
    env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install $1
    pkg info $1 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      # this package should be installed. there must've been a failure.
      echo " ERROR: Could not install $1 . Exiting.".
      exit 1
    fi
    echo " done."
  fi
}


# ----- MAIN SCRIPT BEGINS ----

# Let's be sure that we're running on pfSense 2.2.
echo -n "Checking that we're running on pfSense version $PFSENSE_VERSION_SUPPORTED..."
OS_VERSION=$(cat /etc/version)
if [ "$OS_VERSION" != "2.2-RELEASE" ]; then
  echo "ERROR: $OS_VERSION is not a supported version for this script."
  exit 1
fi

# Stop the controller if it's already running...
# First let's try the rc script if it exists:
if [ -f /usr/local/etc/rc.d/unifi.sh ]; then
  echo -n "Stopping the unifi service..."
  /usr/sbin/service unifi stop
  echo " done."
fi

# Then to be doubly sure, let's make sure ace.jar isn't running for some other reason:
if [ $(ps ax | grep -c "/usr/local/UniFi/lib/[a]ce.jar start") -ne 0 ]; then
  echo -n "Killing ace.jar process..."
  /bin/kill -15 `ps ax | grep "/usr/local/UniFi/lib/[a]ce.jar start" | awk '{ print $1 }'`
  echo " done."
fi

# And then make sure mongodb doesn't have the db file open:
if [ $(ps ax | grep -c "/usr/local/UniFi/data/[d]b") -ne 0 ]; then
  echo -n "Killing mongod process..."
  /bin/kill -15 `ps ax | grep "/usr/local/UniFi/data/[d]b" | awk '{ print $1 }'`
  echo " done."
fi

# If an installation exists, we'll need to back up configuration:
if [ -d /usr/local/UniFi/data ]; then
  echo "Backing up UniFi data..."
  backupfile=/var/backups/unifi-`date +"%Y%m%d_%H%M%S"`.tgz
  /usr/bin/tar -vczf $backupfile /usr/local/UniFi/data
fi

# Add the fstab entries apparently required for OpenJDKse:
if [ $(grep -c fdesc /etc/fstab) -eq 0 ]; then
  echo -n "Adding fdesc filesystem to /etc/fstab..."
  echo -e "fdesc\t\t\t/dev/fd\t\tfdescfs\trw\t\t0\t0" >> /etc/fstab
  echo " done."
fi

if [ $(grep -c proc /etc/fstab) -eq 0 ]; then
  echo -n "Adding procfs filesystem to /etc/fstab..."
  echo -e "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0" >> /etc/fstab
  echo " done."
fi

# Run mount to mount the two new filesystems:
echo -n "Mounting new filesystems..."
/sbin/mount -a
echo " done."


# Check of the pkg manager is installed if not, install it.
if ! pkg -N 2> /dev/null; then
  echo -n "FreeBSD pkgng not installed. Installing..."
  env ASSUME_ALWAYS_YES=YES pkg bootstrap
  echo " done."
fi


# at this point, pkg should be installed. if it's not, we should probably quit.
if ! pkg -N 2> /dev/null; then
  echo "ERROR: pkgng installation failed. Exiting."
  exit 1
fi


# Install mongodb, OpenJDK 7, and unzip (required to unpack Ubiquiti's download):
# -F skips a package if it's already installed, without throwing an error.
echo "Installing required packages..."
pkg_install "mongodb"
pkg_install "openjdk8"
pkg_install "unzip"
echo "Done installing required packages."

# Switch to a temp directory for the Unifi download:
cd `mktemp -d -t unifi`

# Download the controller from Ubiquiti (assuming acceptance of the EULA):
echo -n "Downloading the UniFi controller software..."
/usr/bin/fetch $UNIFI_SOFTWARE_URL
echo " done."
if [ $? -ne 0 ]; then
  echo "ERROR: Something went wrong during the download. Exiting."
  exit 1
fi

# Unpack the archive into the /usr/local directory:
# (the -o option overwrites the existing files without complaining)
echo -n "Installing UniFi controller in /usr/local..."
/usr/local/bin/unzip -o UniFi.unix.zip -d /usr/local
echo " done."
if [ $? -ne 0 ]; then
  echo "ERROR: Something went wrong while installing controller. Exiting."
  exit 1
fi

# Update Unifi's symbolic link for mongod to point to the version we just installed:
echo -n "Updating mongod link..."
/bin/ln -sf /usr/local/bin/mongod /usr/local/UniFi/bin/mongod
echo " done."

# Fetch the rc script from github:
echo -n "Installing rc script..."
/usr/bin/fetch -o /usr/local/etc/rc.d/unifi.sh $RC_SCRIPT_URL
echo " done."

# Fix permissions so it'll run
chmod +x /usr/local/etc/rc.d/unifi.sh

if [ ! -f /etc/rc.conf.local ] || [ $(grep -c unifi_enable /etc/rc.conf.local) -eq 0 ]; then
  echo -n "Enabling the unifi service..."
  echo "unifi_enable=YES" >> /etc/rc.conf.local
  echo ""
  echo " done."
fi

# Restore the backup:
if [ ! -z "$backupfile" ] && [ -f $backupfile ]; then
  echo "Restoring UniFi data..."
  mv /usr/local/UniFi/data /usr/local/UniFi/data-orig
  /usr/bin/tar -vxzf $backupfile
fi

# Start it up:
echo -n "Starting the unifi service..."
/usr/local/etc/rc.d/unifi.sh start
echo " done."

