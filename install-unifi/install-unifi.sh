#!/bin/sh

# install-unifi.sh
# Installs the UniFi Controller software on a FreeBSD machine (presumably running pfSense).
# Requires FreeBSD 15.0+ / pfSense 2.8.1+

# The latest version of UniFi:
UNIFI_SOFTWARE_URL="https://dl.ui.com/unifi/10.1.84/UniFi.unix.zip"

# The rc script associated with this branch or fork:
RC_SCRIPT_URL="https://raw.githubusercontent.com/unofficial-unifi/unifi-pfsense/master/rc.d/unifi.sh"

CURRENT_MONGODB_VERSION=mongodb70

# External MongoDB support (set these env vars before running to use external MongoDB)
MONGO_EXTERNAL=${MONGO_EXTERNAL:-false}
MONGO_URI=${MONGO_URI:-}
MONGO_STAT_URI=${MONGO_STAT_URI:-}
MONGO_DB_NAME=${MONGO_DB_NAME:-unifi}

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

# Require FreeBSD 15.0 or later:
OSVERSION=$(uname -U)
if [ "${OSVERSION}" -lt 1500000 ]; then
  echo "ERROR: This script requires FreeBSD 15.0 or later. Detected: $(uname -r)"
  exit 1
fi

# Determine this installation's Application Binary Interface
ABI=$(/usr/sbin/pkg config abi)

# Configure FreeBSD package repository for dependency resolution
FREEBSD_REPO_URL="https://pkg.freebsd.org/${ABI}/latest"
FREEBSD_REPO_CONF="/usr/local/etc/pkg/repos/FreeBSD-unifi.conf"

mkdir -p /usr/local/etc/pkg/repos
cat > "${FREEBSD_REPO_CONF}" <<REPOEOF
FreeBSD-unifi: {
  url: "${FREEBSD_REPO_URL}",
  enabled: yes,
  mirror_type: "none"
}
REPOEOF

# Lock pkg to prevent it from being upgraded (pfSense's pkg is built against
# pfSense's base libraries; the FreeBSD upstream pkg will break)
pkg lock -yq pkg 2>/dev/null

# Update the package catalog from the FreeBSD repo
echo "Updating package catalog..."
env ASSUME_ALWAYS_YES=YES IGNORE_OSVERSION=yes /usr/sbin/pkg update -f -r FreeBSD-unifi
echo " done."

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
  /bin/kill -15 $(ps ax | grep "/usr/local/UniFi/lib/[a]ce.jar start" | awk '{ print $1 }')
  echo " done."
fi

# And then make sure mongodb doesn't have the db file open:
if [ $(ps ax | grep -c "/usr/local/UniFi/data/[d]b") -ne 0 ]; then
  echo -n "Killing mongod process..."
  /bin/kill -15 $(ps ax | grep "/usr/local/UniFi/data/[d]b" | awk '{ print $1 }')
  echo " done."
fi

# Repairs MongoDB database in case of corruption (only for local MongoDB)
if [ "${MONGO_EXTERNAL}" != "true" ] && [ -d /usr/local/UniFi/data/db ]; then
  mongod --dbpath /usr/local/UniFi/data/db --repair
fi

# If an installation exists, we'll need to back up configuration:
if [ -d /usr/local/UniFi/data ]; then
  echo "Backing up UniFi data..."
  BACKUPFILE=/var/backups/unifi-$(date +"%Y%m%d_%H%M%S").tgz
  /usr/bin/tar -vczf "${BACKUPFILE}" /usr/local/UniFi/data
fi

# Add the fstab entries apparently required for OpenJDK:
if [ $(grep -c fdesc /etc/fstab) -eq 0 ]; then
  echo -n "Adding fdesc filesystem to /etc/fstab..."
  printf "fdesc\t\t\t/dev/fd\t\tfdescfs\trw\t\t0\t0\n" >> /etc/fstab
  echo " done."
fi

if [ $(grep -c proc /etc/fstab) -eq 0 ]; then
  echo -n "Adding procfs filesystem to /etc/fstab..."
  printf "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0\n" >> /etc/fstab
  echo " done."
fi

# Run mount to mount the two new filesystems:
echo -n "Mounting new filesystems..."
/sbin/mount -a
echo " done."

# Unlock all previously locked packages to avoid conflicts
pkg unlock -ayq 2>/dev/null

# Remove all old MongoDB versions
echo "Removing discontinued packages..."
for old_ver in mongodb36 mongodb40 mongodb42 mongodb44 mongodb50 mongodb60; do
  if pkg info -e ${old_ver} 2>/dev/null; then
    env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete ${old_ver}
  fi
done

# Remove old Java versions
for old_java in openjdk8 openjdk11; do
  if pkg info -e ${old_java} 2>/dev/null; then
    env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete ${old_java}
  fi
done

# Remove packages no longer needed
for old_pkg in python37 mpdecimal snappyjava; do
  if pkg info -e ${old_pkg} 2>/dev/null; then
    env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete ${old_pkg}
  fi
done
echo " done."

# Install packages using pkg install (auto-resolves all dependencies)
echo "Installing required packages..."

# Install OpenJDK 17 and all its dependencies
env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install -r FreeBSD-unifi -f \
  openjdk17 \
  javavmwrapper \
  java-zoneinfo \
  libinotify \
  unzip \
  || exit 1

# Install MongoDB (only if using local MongoDB)
if [ "${MONGO_EXTERNAL}" != "true" ]; then
  env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install -r FreeBSD-unifi -f \
    ${CURRENT_MONGODB_VERSION} \
    || exit 1
fi

# Lock installed packages to prevent pfSense from removing them during updates
for pkg_to_lock in openjdk17 javavmwrapper java-zoneinfo libinotify unzip; do
  pkg lock -yq ${pkg_to_lock} 2>/dev/null
done

if [ "${MONGO_EXTERNAL}" != "true" ]; then
  pkg lock -yq ${CURRENT_MONGODB_VERSION} 2>/dev/null
fi

echo " done."

# Switch to a temp directory for the UniFi download:
cd $(mktemp -d -t unifi) || exit 1

# Download the controller from Ubiquiti (assuming acceptance of the EULA):
echo -n "Downloading the UniFi controller software..."
/usr/bin/fetch ${UNIFI_SOFTWARE_URL}
echo " done."

# Unpack the archive into the /usr/local directory:
# (the -o option overwrites the existing files without complaining)
echo -n "Installing UniFi controller in /usr/local..."
/usr/local/bin/unzip -o UniFi.unix.zip -d /usr/local
echo " done."

# Update UniFi's symbolic link for mongod to point to the version we just installed
# (only if using local MongoDB):
if [ "${MONGO_EXTERNAL}" != "true" ]; then
  echo -n "Updating mongod link..."
  /bin/ln -sf /usr/local/bin/mongod /usr/local/UniFi/bin/mongod
  echo " done."
fi

# Configure external MongoDB if requested:
if [ "${MONGO_EXTERNAL}" = "true" ] && [ -n "${MONGO_URI}" ]; then
  echo "Configuring external MongoDB..."
  mkdir -p /usr/local/UniFi/data
  # Remove existing mongo config lines if present
  if [ -f /usr/local/UniFi/data/system.properties ]; then
    grep -v '^db\.mongo\.\|^statdb\.mongo\.\|^unifi\.db\.name' \
      /usr/local/UniFi/data/system.properties > /usr/local/UniFi/data/system.properties.tmp
    mv /usr/local/UniFi/data/system.properties.tmp /usr/local/UniFi/data/system.properties
  fi
  cat >> /usr/local/UniFi/data/system.properties <<MONGOEOF
db.mongo.local=false
db.mongo.uri=${MONGO_URI}
statdb.mongo.uri=${MONGO_STAT_URI:-${MONGO_URI}_stat}
unifi.db.name=${MONGO_DB_NAME}
MONGOEOF
  echo " done."
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
if [ -n "${BACKUPFILE}" ] && [ -f "${BACKUPFILE}" ]; then
  echo "Restoring UniFi data..."
  mv /usr/local/UniFi/data "/usr/local/UniFi/data-$(date +%Y%m%d-%H%M)"
  /usr/bin/tar -vxzf "${BACKUPFILE}" -C /
fi

# Clean up the temporary repo config
rm -f "${FREEBSD_REPO_CONF}"

# Start it up:
echo -n "Starting the unifi service..."
/usr/sbin/service unifi.sh start
echo " done."
