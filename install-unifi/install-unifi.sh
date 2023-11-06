#!/bin/sh

# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# The latest version of UniFi:
UNIFI_SOFTWARE_URL="https://dl.ui.com/unifi/7.2.97/UniFi.unix.zip"


# The rc script associated with this branch or fork:
RC_SCRIPT_URL="https://raw.githubusercontent.com/unofficial-unifi/unifi-pfsense/master/rc.d/unifi.sh"

# List of valid/supported mongodb package names, sorted with the latest being first
# As UniFi adds support for new mongodb versions, just prepend them to this list
SUPPORTED_MONGODB_PACKAGES="mongodb42 mongodb40 mongodb36 mongodb34 mongodb32 mongodb"

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

# Determine this installation's Application Binary Interface
ABI=`/usr/sbin/pkg config abi`

# FreeBSD package source:
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/${ABI}/latest/"

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

# Repairs Mongodb database in case of corruption
mongod --dbpath /usr/local/UniFi/data/db --repair

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


echo "Gathering package list from remote repository..."
# Build a list of possible packagesite.* URLs
for ext in pkg txz; do
  FREEBSD_PACKAGE_LIST_URLS="$FREEBSD_PACKAGE_LIST_URLS ${FREEBSD_PACKAGE_URL}packagesite.${ext}"
done
# Try each of the URLs in the list and exit if they all fail
if ! fetch -q1o - $FREEBSD_PACKAGE_LIST_URLS > packagesite.pkg 2> /dev/null; then
  echo "Error downloading $FREEBSD_PACKAGE_LIST_URLS"
  exit 1
fi
tar fx packagesite.pkg || exit 1
echo "Done."


# Find the latest supported mongodb version that's available in the repository
for package_name in $SUPPORTED_MONGODB_PACKAGES; do
  if grep -q "\"name\":\"$package_name\"" packagesite.yaml; then
    CURRENT_MONGODB_VERSION="$package_name"
    break
  fi
done

if [ ! -z "$CURRENT_MONGODB_VERSION" ]; then
  echo "Removing discontinued packages..."
  pkg info | grep mongodb | grep -v ${CURRENT_MONGODB_VERSION} | while read -r old_mongo; do
    package=`echo "$old_mongo" | cut -d' ' -f1`
    pkg unlock -yq ${package}
    env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete ${package}
  done
  echo " done."
else
  echo "Could not locate a valid mongodb package"
fi



# Install mongodb, OpenJDK, and unzip (required to unpack Ubiquiti's download):
# -F skips a package if it's already installed, without throwing an error.
echo "Installing required packages..."
#uncomment below for pfSense 2.2.x:
#env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install mongodb openjdk unzip pcre v8 snappy

AddPkg () {
  pkgname=$1
  pkg unlock -yq $pkgname
  pkginfo=`grep "\"name\":\"$pkgname\"" packagesite.yaml`
  pkgvers=`echo $pkginfo | pcregrep -o1 '"version":"(.*?)"' | head -1`
  pkgurl="${FREEBSD_PACKAGE_URL}`echo $pkginfo | pcregrep -o1 '"path":"(.*?)"' | head -1`"

  # compare version for update/install
  if [ `pkg info | grep -c $pkgname-$pkgvers` -eq 1 ]; then
    echo "Package $pkgname-$pkgvers already installed."
  else
    env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add -f "$pkgurl" || exit 1

    # if update openjdk8 then force detele snappyjava to reinstall for new version of openjdk
    if [ "$pkgname" == "openjdk8" ]; then
      pkg unlock -yq snappyjava
      env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete snappyjava
    fi
  fi
  pkg lock -yq $pkgname
}

#Add the following Packages for installation or reinstallation (if something was removed)
AddPkg png
AddPkg brotli
AddPkg freetype2
AddPkg fontconfig
AddPkg alsa-lib
AddPkg mpdecimal
AddPkg python37
AddPkg libfontenc
AddPkg mkfontscale
AddPkg dejavu
AddPkg giflib
AddPkg xorgproto
AddPkg libXdmcp
AddPkg libXau
AddPkg libxcb
AddPkg libICE
AddPkg libSM
AddPkg libX11
AddPkg libXfixes
AddPkg libXext
AddPkg libXi
AddPkg libXt
AddPkg libXtst
AddPkg libXrender
AddPkg libinotify
AddPkg javavmwrapper
AddPkg java-zoneinfo
AddPkg openjdk8
AddPkg snappyjava
AddPkg snappy
AddPkg cyrus-sasl
AddPkg icu
AddPkg boost-libs
if [ ! -z "$CURRENT_MONGODB_VERSION" ]; then
  AddPkg ${CURRENT_MONGODB_VERSION}
fi
AddPkg unzip
AddPkg pcre

# Clean up downloaded package manifest:
rm packagesite.*

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

# If partition size is < 4GB, add smallfiles option to mongodb
echo -n "Checking partition size..."
if [ `df -k | awk '$NF=="/"{print $2}'` -le 4194302 ]; then
  echo -e "\nunifi.db.extraargs=--smallfiles\n" >> /usr/local/UniFi/data/system.properties
fi
echo " done."

# Replace snappy java library to support AP adoption with latest firmware:
echo -n "Updating snappy java..."
unifizipcontents=`zipinfo -1 UniFi.unix.zip`
upstreamsnappyjavapattern='/(snappy-java-[^/]+\.jar)$'
# Make sure exactly one match is found
if [ $(echo "${unifizipcontents}" | egrep -c ${upstreamsnappyjavapattern}) -eq 1 ]; then
  upstreamsnappyjava="/usr/local/UniFi/lib/`echo \"${unifizipcontents}\" | pcregrep -o1 ${upstreamsnappyjavapattern}`"
  mv "${upstreamsnappyjava}" "${upstreamsnappyjava}.backup"
  cp /usr/local/share/java/classes/snappy-java.jar "${upstreamsnappyjava}"
  echo " done."
else
  echo "ERROR: Could not locate UniFi's snappy java! AP adoption will most likely fail"
fi

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
  mv /usr/local/UniFi/data /usr/local/UniFi/data-`date +%Y%m%d-%H%M`
  /usr/bin/tar -vxzf ${BACKUPFILE} -C /
fi

# Start it up:
echo -n "Starting the unifi service..."
/usr/sbin/service unifi.sh start
echo " done."
