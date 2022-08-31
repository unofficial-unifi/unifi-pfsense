#!/bin/sh

# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# Instead every time updating the URL, just update latest controller version
LATEST_CTL_VER=7.1.68

# The latest version of UniFi:
UNIFI_SOFTWARE_URL="https://dl.ui.com/unifi/${LATEST_CTL_VER}/UniFi.unix.zip"

# The rc script associated with this branch or fork:
RC_SCRIPT_URL="https://raw.githubusercontent.com/gozoinks/unifi-pfsense/master/rc.d/unifi.sh"

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

# latest/All changed to latest/ since the path is being aquired in AddPkg
# FreeBSD package source:
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/${ABI}/latest/"

# FreeBSD package list:
FREEBSD_PACKAGE_LIST_URL="https://pkg.freebsd.org/${ABI}/latest/packagesite.txz"

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


#remove mongodb34 - discontinued
if [ `pkg info | grep -c mongodb-` -eq 1 ]; then
  echo "Removing packages discontinued..."
  pkg unlock -yq mongodb
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb
  echo " done."
fi

if [ `pkg info | grep -c mongodb34-` -eq 1 ]; then
  echo "Removing packages discontinued..."
  pkg unlock -yq mongodb34 
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb34
  echo " done."
fi

# while at it, clean up MongoDB 3.6 and 4.0 versions. If
# you are already on 4.2 and using it for UniFi ONLY
if [ `pkg info | grep -c mongodb36-` -eq 1 ]; then
  echo "Removing packages discontinued..."
  pkg unlock -yq mongodb36
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb36
  echo " done."
fi

if [ `pkg info | grep -c mongodb40-` -eq 1 ]; then
  echo "Removing packages discontinued..."
  pkg unlock -yq mongodb40
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb40
  echo " done."
fi

# New changes added to install-unifi
# Until higher versions of mongo are supported by UniFi
# this is for users who must migrate data from Mongo 4.2
if [ `pkg info | grep -wc mongodb42-tools` -eq 1 ]; then
        pkg unlock -yq mongodb42-tools
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb42-tools
fi

if [ `pkg info | grep -wc mongodb42-4.2` -eq 1 ]; then
        pkg unlock -yq mongodb42
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb42
fi

cleanup () {
    rm -rf "$TMPDIR"
}

TMPDIR=`mktemp -d  -t unifi`

# Switch to a temp directory for the Upgrades the Unifi download:
cd $TMPDIR
echo "In TempDir" 

trap cleanup EXIT

# Install latest mongodb, OpenJDK, and unzip (required to unpack Ubiquiti's download):
# -F skips a package if it's already installed, without throwing an error.
echo "Installing required updated packages..."
# uncomment below for pfSense 2.2.x:
# env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install mongodb openjdk unzip pcre v8 snappy

# From unifi 7.x / FreeBSD 12.3 onwards also need to check and install jq as pre-requisite to this script
# During 7.1.68 JQ check was introduced and it failed to check and quit
# echo "starting JQ"
# if [ `pkg info | grep -ce '^jq-'` -eq 0 ]; then
# 	echo "Installing Lightweight and flexible command-line JSON processor"
# 	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install jq
# if


echo "Get the latest package list..."
fetch -o ${TMPDIR}/packagesite.txz -q ${FREEBSD_PACKAGE_LIST_URL}
tar vfx packagesite.txz

AddPkg () {
 	PACKAGE_NAME=${1}
  pkg unlock -yq ${PACKAGE_NAME}
 	PACKAGE_INFO=`grep \"name\":\"$PACKAGE_NAME\" packagesite.yaml | jq -r '[.name,.version]| join ( "-" )'`
 	# pkgvers=`grep "\"name\":\"$PACKAGE_NAME" packagesite.yaml | jq .version | sed -e s/\"//g`
 	PACKAGE_PATH=`grep \"name\":\"$PACKAGE_NAME\" packagesite.yaml | jq .path | sed -e s/\"//g`

	# compare version for update/install
 	if [ `pkg info | grep -c ${PACKAGE_INFO}` -eq 1 ]; then
	    echo "Package $PACKAGE_NAME already at latest version."
	else
      CURRENT_PACKAGE=`pkg info | grep $PACKAGE_NAME | awk '{print $1}'`
      echo "Currently installed $CURRENT_PACKAGE"
      echo "Upgrading to... ... ${PACKAGE_INFO}"
	    env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add -f ${FREEBSD_PACKAGE_URL}${PACKAGE_PATH}

	    # if update openjdk8 then force detele snappyjava to reinstall for new version of openjdk
	    if [ "$PACKAGE_NAME" == "openjdk8" ]; then
	        pkg unlock -yq snappyjava
	        env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete snappyjava
      fi
  fi
  pkg lock -yq ${PACKAGE_NAME}
}

#Add the following Packages for installation or reinstallation (if something was removed)
AddPkg png
AddPkg freetype2
AddPkg fontconfig
AddPkg alsa-lib
AddPkg mpdecimal
AddPkg python38
AddPkg libfontenc
AddPkg mkfontscale
AddPkg dejavu
AddPkg giflib
AddPkg xorgproto
AddPkg libXdmcp
AddPkg libpthread-stubs
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
AddPkg boost-libs
AddPkg javavmwrapper
AddPkg java-zoneinfo
AddPkg openjdk8
AddPkg cyrus-sasl
AddPkg icu
AddPkg snappyjava
AddPkg snappy
AddPkg mongodb42
AddPkg mongodb42-tools
AddPkg unzip
AddPkg pcre

# Clean up downloaded package manifest:
rm packagesite.*

echo "Pakage Refresh - done."

# Download the controller from Ubiquiti (assuming acceptance of the EULA):
echo -n "Downloading latest UniFi controller software..."
/usr/bin/fetch -o $TMPDIR/UniFi.unix.zip ${UNIFI_SOFTWARE_URL}

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
upstreamsnappyjavapattern='(snappy-java-[^/]+\.jar)'
#In memory content not match thus dumping to a file 
UNZIPCONTENTS=`mktemp`
echo $unifizipcontents > $UNZIPCONTENTS
# Make sure exactly one match is found
if [ `egrep -c '/(snappy-java-[^/]+\.jar)$'` -eq 1 ]; then
  upstreamsnappyjava="/usr/local/UniFi/lib/`echo $unifizipcontents | pcregrep --buffer-size=1M -o '(snappy-java-[^/]+\.jar)'`"
  mv "${upstreamsnappyjava}" "${upstreamsnappyjava}.backup"
  cp /usr/local/share/java/classes/snappy-java.jar "${upstreamsnappyjava}"
  echo " done."
else
  echo "ERROR: Could not locate UniFi's snappy java! AP adoption will most likely fail"
fi
exit 

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
