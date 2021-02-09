#!/bin/sh

# install-omada.sh
# Installs the Omada Controller software on a FreeBSD machine (presumably running pfSense).

# The latest version of Omada Controller:
OMADA_SOFTWARE_URL=`curl https://www.tp-link.com/uk/support/download/eap225/v2/#Controller_Software | tr '"' '\n' | tr "'" '\n' | grep -e 'tar.gz$' -m 1`


JRE_HOME="/usr/local/openjdk8/jre"

# The rc script associated with this branch or fork:
RC_SCRIPT_URL="https://raw.githubusercontent.com/tinwhisker/tplink-eapcontroller-pfsense/master/rc.d/eapcontroller.sh"

PATCHED_STARTCLASS_URL="https://raw.githubusercontent.com/tinwhisker/tplink-eapcontroller-pfsense/master/modifications/EapLinuxMain.class"

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
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/${ABI}/latest/All/"

# FreeBSD package list:
FREEBSD_PACKAGE_LIST_URL="https://pkg.freebsd.org/${ABI}/latest/packagesite.txz"

# Stop the controller if it's already running...
# First let's try the rc script if it exists:
if [ -f /usr/local/etc/rc.d/omadacontroller.sh ]; then
  echo -n "Stopping the OMADA Controller service..."
  /usr/sbin/service omadacontroller.sh stop
  echo " done."
fi

# Then to be doubly sure, let's make sure ace.jar isn't running for some other reason:
if [ $(ps ax | grep "eap.home=/opt/tplink/EAPController") -ne 0 ]; then
  echo -n "Killing ace.jar process..."
  /bin/kill -15 `ps ax | grep "eap.home=/opt/tplink/EAPController" | awk '{ print $1 }'`
  echo " done."
fi

# And then make sure mongodb doesn't have the db file open:
if [ $(ps ax | grep -c "/opt/tplink/EAPController/data/[d]b") -ne 0 ]; then
  echo -n "Killing mongod process..."
  /bin/kill -15 `ps ax | grep "/opt/tplink/EAPController/data/[d]b" | awk '{ print $1 }'`
  echo " done."
fi

# If an installation exists, we'll need to back up configuration:
#if [ -d /opt/tplink/EAPController/data ]; then
#  echo "Backing up OMADA Controller data..."
#  BACKUPFILE=/var/backups/eap-`date +"%Y%m%d_%H%M%S"`.tgz
#  /usr/bin/tar -vczf ${BACKUPFILE} /opt/tplink/EAPController/data
#fi

# Add the fstab entries apparently required for OpenJDKse:
#if [ $(grep -c fdesc /etc/fstab) -eq 0 ]; then
#  echo -n "Adding fdesc filesystem to /etc/fstab..."
#  echo -e "fdesc\t\t\t/dev/fd\t\tfdescfs\trw\t\t0\t0" >> /etc/fstab
#  echo " done."
#fi

#if [ $(grep -c proc /etc/fstab) -eq 0 ]; then
#  echo -n "Adding procfs filesystem to /etc/fstab..."
#  echo -e "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0" >> /etc/fstab
#  echo " done."
#fi

# Run mount to mount the two new filesystems:
#echo -n "Mounting new filesystems..."
#/sbin/mount -a
#echo " done."

# Install mongodb, OpenJDK, and unzip (required to unpack Ubiquiti's download):
# -F skips a package if it's already installed, without throwing an error.
echo "Installing required packages..."
tar xv -C / -f /usr/local/share/pfSense/base.txz ./usr/bin/install
#uncomment below for pfSense 2.2.x:
#env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg install mongodb openjdk unzip pcre v8 snappy

fetch ${FREEBSD_PACKAGE_LIST_URL}
tar vfx packagesite.txz

AddPkg () {
     pkgname=$1
        pkg unlock -yq $pkgname
     pkginfo=`grep "\"name\":\"$pkgname\"" packagesite.yaml`
     pkgvers=`echo $pkginfo | pcregrep -o1 '"version":"(.*?)"' | head -1`

    # compare version for update/install
     if [ `pkg info | grep -c $pkgname-$pkgvers` -eq 1 ]; then
         echo "Package $pkgname-$pkgvers already installed."
    else
         env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add -f ${FREEBSD_PACKAGE_URL}${pkgname}-${pkgvers}.txz

         # if update openjdk8 then force delete snappyjava to reinstall for new version of openjdk
         #if [ "$pkgname" == "openjdk8" ]; then
         #     env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete snappyjava
        #     fi
    fi
        pkg lock -yq $pkgname
}

AddPkg png
AddPkg freetype2
AddPkg fontconfig
AddPkg alsa-lib
AddPkg python37
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
AddPkg javavmwrapper
AddPkg java-zoneinfo
AddPkg openjdk8
#AddPkg snappyjava
#AddPkg snappy
AddPkg cyrus-sasl
AddPkg icu
AddPkg boost-libs
AddPkg mongodb36
AddPkg unzip
AddPkg pcre

# Clean up downloaded package manifest:
rm packagesite.*

echo " done."

# Switch to a temp directory for the OMADA Controller download:
cd `mktemp -d -t tplink`

# Download OMADA Controller from TP-Link:
echo -n "Downloading the OMADA Controller software..."
/usr/bin/fetch ${OMADA_SOFTWARE_URL} -o Omada_Controller.tar.gz
echo " done."

# Unpack the archive into the /usr/local directory:
# (the -o option overwrites the existing files without complaining)
echo -n "Installing OMADA Controller in /opt/tplink/EAPController..."
mkdir /tmp/omadac
tar -xvzC /tmp/omadac -f Omada_Controller.tar.gz --strip-components=1
mkdir /opt
mkdir /opt/tplink
mv /tmp/omadac  /opt/tplink/EAPController
echo " done."

# Update OMADA's symbolic link for mongod to point to the version we just installed:
echo -n "Updating mongod link..."
/bin/ln -sf /usr/local/bin/mongod /opt/tplink/EAPController/bin/mongod
/bin/ln -sf /usr/local/bin/mongo /opt/tplink/EAPController/bin/mongo
echo " done."

# Update OMADA's symbolic link for Java to point to the version we just installed:
echo -n "Updating Java link..."
/bin/ln -sf ${JAVA_HOME} /opt/tplink/EAPController/jre
echo " done."

echo -n "Remove Omada [un]install scripts"
rm /opt/tplink/EAPController/install.sh
rm /opt/tplink/EAPController/uninstall.sh
echo " done."

echo -n "Patch eap-start-*.jar"
EAP_START_JAR=$(ls /opt/tplink/EAPController/lib/eap-start-*.jar | sed 's#.*/##') #Get jar name
mkdir /tmp/eap-start-jar
if [ ! -f /opt/tplink/EAPController/lib/${EAP_START_JAR}.bak ]; then
    cp /opt/tplink/EAPController/lib/${EAP_START_JAR} /opt/tplink/EAPController/lib/${EAP_START_JAR}.bak
fi
cp /opt/tplink/EAPController/lib/${EAP_START_JAR} /tmp/eap-start-jar/
( cd /tmp/eap-start-jar/ && jar -xf ${EAP_START_JAR} )
/usr/bin/fetch -o /tmp/eap-start-jar/com/tp_link/eap/start/EapLinuxMain.class ${RC_SCRIPT_URL}
( cd /tmp/eap-start-jar/ && jar -cvf ${EAP_START_JAR} * )
cp /tmp/eap-start-jar/${EAP_START_JAR} /opt/tplink/EAPController/lib/${EAP_START_JAR} 
echo " done."

# If partition size is < 4GB, add smallfiles option to mongodb
#echo -n "Checking partition size..."
#if [ `df -k | awk '$NF=="/"{print $2}'` -le 4194302 ]; then
#    echo -e "\nunifi.db.extraargs=--smallfiles\n" >> /opt/tplink/EAPController/data/system.properties
#fi
#echo " done."



# Fetch the rc script from github:
echo -n "Installing rc script..."
/usr/bin/fetch -o /usr/local/etc/rc.d/eapcontroller.sh ${RC_SCRIPT_URL}
echo " done."

# Fix permissions so it'll run
chmod +x /usr/local/etc/rc.d/eapcontroller.sh

# Add the startup variable to rc.conf.local.
# Eventually, this step will need to be folded into pfSense, which manages the main rc.conf.
# In the following comparison, we expect the 'or' operator to short-circuit, to make sure the file exists and avoid grep throwing an error.
if [ ! -f /etc/rc.conf.local ] || [ $(grep -c eapcontroller_enable /etc/rc.conf.local) -eq 0 ]; then
  echo -n "Enabling the OMADA Controller service..."
  echo "eapcontroller_enable=YES" >> /etc/rc.conf.local
  echo " done."
fi

# Do some setup

DEST_DIR=/opt/tplink
DEST_FOLDER=EAPController
INSTALLDIR=${DEST_DIR}/${DEST_FOLDER}
DATA_DIR="${INSTALLDIR}/data"
#LINK=/etc/init.d/tpeap
#LINK_CMD=/usr/bin/tpeap

BACKUP_DIR=${INSTALLDIR}/../eap_db_backup
DB_FILE_NAME=eap.db.tar.gz
MAP_FILE_NAME=eap.map.tar.gz


need_import_mongo_db() {
    while true
    do
        echo -n "${DESC} detects that you have backup previous setting before, will you import it (y/n): "
        read input
        confirm=`echo $input | tr '[a-z]' '[A-Z]'`

        if [ "$confirm" == "Y" -o "$confirm" == "YES" ]; then
            return 1
        elif [ "$confirm" == "N" -o "$confirm" == "NO" ]; then
            return 0
        fi
    done
}

import_mongo_db() {
    data_is_empty
    [ 0 == $? ] && {
      #echo "current data is not empty"
      return
    }

    #echo "current data is empty"
    
    if test -f ${BACKUP_DIR}/${DB_FILE_NAME}; then
        need_import_mongo_db
        if [ 1 == $? ]; then
            cd  ${BACKUP_DIR}
            tar zxvf ${DB_FILE_NAME} -C ${DATA_DIR}

            #import map pictures
            if test -f ${MAP_FILE_NAME}; then
                tar zxvf ${MAP_FILE_NAME} -C ${DATA_DIR}
            fi
            
            rm -rf ${DB_FILE_NAME} > /dev/null 2>&1
            rm -rf ${MAP_FILE_NAME} > /dev/null 2>&1
            echo "Import previous setting seccess."
        fi
    fi
}

# Restore the backup:
if [ ! -z "${BACKUPFILE}" ] && [ -f ${BACKUPFILE} ]; then
  echo "Restoring OMADA Controller data..."
  mv /opt/tplink/EAPController/data /opt/tplink/EAPController/data-`date +%Y%m%d-%H%M`
  /usr/bin/tar -vxzf ${BACKUPFILE} -C /
fi

import_mongo_db

# Start it up:
echo -n "Starting the OMADA Controller service..."
/usr/sbin/service eapcontroller.sh start
echo " done."
