#!/bin/sh

# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# OS architecture
OS_ARCH=`getconf LONG_BIT`

# The latest version of UniFi:
UNIFI_SOFTWARE_URL="https://dl.ubnt.com/unifi/5.4.11/UniFi.unix.zip"

# The rc script associated with this branch or fork:
RC_SCRIPT_URL="https://raw.githubusercontent.com/gozoinks/unifi-pfsense/master/rc.d/unifi.sh"

#FreeBSD package source:
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/freebsd:10:x86:${OS_ARCH}/latest/All/"

# If pkg-ng is not yet installed, bootstrap it:
if ! /usr/sbin/pkg -N 2> /dev/null; then
  echo "FreeBSD pkgng not installed. Installing..."
  env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg bootstrap
  echo " done."
fi

# If installation failed, exit:
if ! /usr/sbin/pkg -N 2> /dev/null; then
  echo "ERROR: pkgng installation failed. Exiting."
  exit 1
fi

# Stop the controller if it's already running...
# First let's try the rc script if it exists:
if [ -f /usr/local/etc/rc.d/unifi.sh ]; then
  echo -n "Stopping the unifi service..."
  /usr/sbin/service unifi.sh stop
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
  BACKUPFILE=/var/backups/unifi-`date +"%Y%m%d_%H%M%S"`.tgz
  /usr/bin/tar -vczf ${BACKUPFILE} /usr/local/UniFi/data
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

# Install mongodb, OpenJDK, and unzip (required to unpack Ubiquiti's download):
# -F skips a package if it's already installed, without throwing an error.
echo "Installing required packages..."
tar xv -C / -f /usr/local/share/pfSense/base.txz ./usr/bin/install
#uncomment below for pfSense 2.2.x:
#env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install mongodb openjdk unzip pcre v8 snappy
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}snappy-1.1.4.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}python2-2_3.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}v8-3.18.5_2.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}mongodb-2.6.12.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}unzip-6.0_7.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}pcre-8.40.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}alsa-lib-1.1.2.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}freetype2-2.6.3.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}fontconfig-2.12.1,1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}xproto-7.0.31.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}kbproto-1.0.7.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXdmcp-1.1.2.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libpthread-stubs-0.3_6.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXau-1.0.8_3.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libxcb-1.12.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libICE-1.0.9_1,1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libSM-1.2.2_3,1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}java-zoneinfo-2016.j.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}fixesproto-5.0.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}xextproto-7.3.0.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}inputproto-2.3.2.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libX11-1.6.4,1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXfixes-5.0.3.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXext-1.3.3_1,1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXi-1.7.9,1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXt-1.1.5,1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libfontenc-1.1.3_1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}mkfontscale-1.1.2.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}mkfontdir-1.0.7.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}dejavu-2.37.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}recordproto-1.14.2.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXtst-1.2.3.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}renderproto-0.11.1.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}libXrender-0.9.10.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}javavmwrapper-2.5_2.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}giflib-5.1.4.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}openjdk8-8.121.13.txz
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}snappyjava-1.0.4.1_2.txz
echo " done."

# Switch to a temp directory for the Unifi download:
cd `mktemp -d -t unifi`

# Download the controller from Ubiquiti (assuming acceptance of the EULA):
echo -n "Downloading the UniFi controller software..."
/usr/bin/fetch ${UNIFI_SOFTWARE_URL}
echo " done."

# Unpack the archive into the /usr/local directory:
# (the -o option overwrites the existing files without complaining)
echo -n "Installing UniFi controller in /usr/local..."
/usr/local/bin/unzip -o UniFi.unix.zip -d /usr/local
echo " done."

# Update Unifi's symbolic link for mongod to point to the version we just installed:
echo -n "Updating mongod link..."
/bin/ln -sf /usr/local/bin/mongod /usr/local/UniFi/bin/mongod
echo " done."

# Replace snappy java library to support AP adoption with latest firmware
echo -n "Updating snappy java..."
fetch https://pkg.freebsd.org/freebsd:10:x86:${OS_ARCH}/latest/All/snappyjava-1.0.4.1_2.txz
tar vfx snappyjava-1.0.4.1_2.txz
mv /usr/local/UniFi/lib/snappy-java-1.0.5.jar /usr/local/UniFi/lib/snappy-java-1.0.5.jar.backup
cp ./usr/local/share/java/classes/snappy-java.jar /usr/local/UniFi/lib/snappy-java-1.0.5.jar
rm -Rf ./usr
rm snappyjava-1.0.4.1_2.txz
echo " done."

# Fetch the rc script from github:
echo -n "Installing rc script..."
/usr/bin/fetch -o /usr/local/etc/rc.d/unifi.sh ${RC_SCRIPT_URL}
echo " done."

# Fix permissions so it'll run
chmod +x /usr/local/etc/rc.d/unifi.sh

# Add the startup variable to rc.conf.local.
# Eventually, this step will need to be folded into pfSense, which manages the main rc.conf.
# In the following comparison, we expect the 'or' operator to short-circuit, to make sure the file exists and avoid grep throwing an error.
if [ ! -f /etc/rc.conf.local ] || [ $(grep -c unifi_enable /etc/rc.conf.local) -eq 0 ]; then
  echo -n "Enabling the unifi service..."
  echo "unifi_enable=YES" >> /etc/rc.conf.local
  echo " done."
fi

# Restore the backup:
if [ ! -z "${BACKUPFILE}" ] && [ -f ${BACKUPFILE} ]; then
  echo "Restoring UniFi data..."
  mv /usr/local/UniFi/data /usr/local/UniFi/data-orig
  /usr/bin/tar -vxzf ${BACKUPFILE}
fi

# Start it up:
echo -n "Starting the unifi service..."
/usr/sbin/service unifi.sh start
echo " done."
