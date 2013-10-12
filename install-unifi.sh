#!/bin/sh

# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# Add the fstab entries apparently required for OpenJDK 6:
if [ $(grep -c fdesc /etc/fstab) -eq 0 ]; then
  echo "Adding fdesc filesystem to /etc/fstab..."
  echo -e "fdesc\t\t\t/dev/fd\t\tfdescfs\trw\t\t0\t0" >> /etc/fstab
fi

if [ $(grep -c proc /etc/fstab) -eq 0 ]; then
  echo "Adding procfs filesystem to /etc/fstab..."
  echo -e "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0" >> /etc/fstab
fi

# Run mount to mount the two new filesystems:
echo "Mounting new filesystems."
/sbin/mount -a

# Install mongodb, OpenJDK 6, and unzip (required to unpack Ubiquiti's download):
# -F skips a package if it's already installed, without throwing an error.
/usr/sbin/pkg_add -F -r mongodb openjdk6 unzip

# Switch to a temp directory for the Unifi download:
cd `mktemp -d -t unifi`

# Download the controller from Ubiquiti (assuming acceptance of the EULA):
echo "Downloading the UniFi controller software..."
/usr/bin/fetch http://dl.ubnt.com/unifi/2.4.5/UniFi.unix.zip

# Unpack the archive into the /usr/local directory:
echo "Installing UniFi controller in /usr/local..."
/usr/local/bin/unzip UniFi.unix.zip -d /usr/local

# Update Unifi's symbolic link for mongod to point to the version we just installed:
echo "Updating mongod link..."
/bin/ln -sf /usr/local/bin/mongod /usr/local/UniFi/bin/mongod

# Create the rc.d script for automatic startup/shutdown...
# Thinking a heredoc insertion of the script, dumped directly to a ${name} file in /etc/rc.d
# What to do if file exists?
# cat <<'EOF'
# (script)
# EOF > /etc/rc.d/${name}

# Add the startup variable to rc.conf.local.
# Eventually, this step will need to be folded into pfSense, which manages the main rc.conf.
echo "unifi_enable=YES" >> /etc/rc.conf.local

# Start it up:
/usr/sbin/service unifi start
