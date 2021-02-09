#!/bin/sh

# REQUIRE: FILESYSTEMS
# REQUIRE: NETWORKING
# PROVIDE: EAPController

. /etc/rc.subr

name="omada"
rcvar="eapcontroller_enable"
start_cmd="eapcontroller_start"
stop_cmd="eapcontroller_stop"

#pidfile="/var/run/${name}.pid"

#load_rc_config ${name}

OMADA_HOME="/opt/tplink/EAPController"
LOG_DIR="${OMADA_HOME}/logs"
WORK_DIR="${OMADA_HOME}/work"
DATA_DIR="${OMADA_HOME}/data"
PROPERTY_DIR="${OMADA_HOME}/properties"
AUTOBACKUP_DIR="${DATA_DIR}/autobackup"

JRE_HOME="/usr/local/openjdk8/jre"
#"${OMADA_HOME}/jre"
JAVA_TOOL="${JRE_HOME}/bin/java"
JAVA_OPTS="-server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30  -XX:+HeapDumpOnOutOfMemoryError -Deap.home=${OMADA_HOME}"
MAIN_CLASS="com.tp_link.eap.start.EapLinuxMain"

[ ! -f ${PROPERTY_DIR}/jetty.properties ] || HTTP_PORT=$(grep "^[^#;]" ${PROPERTY_DIR}/jetty.properties | sed -n 's/http.connector.port=\([0-9]\+\)/\1/p' | sed -r 's/\r//')
HTTP_PORT=${HTTP_PORT:-8088}

JSVC_OPTS="${JAVA_OPTS}\
 -cp /usr/share/java/commons-daemon.jar:${OMADA_HOME}/lib/* \
 -showversion"

eapcontroller_start()
{

    echo -n "Starting ${DESC}. Please wait.\n"
    
    [ -e "${LOG_DIR}" ] || {
        mkdir -m 755 ${LOG_DIR} 2>/dev/null
    }

    rm -f "${LOG_DIR}/startup.log"
    touch "${LOG_DIR}/startup.log" 2>/dev/null
    
    
    [ -e "$WORK_DIR" ] || {
        mkdir -m 755 ${WORK_DIR} 2>/dev/null
    }
    
    [ -e "$AUTOBACKUP_DIR" ] || {
        mkdir -m 755 ${AUTOBACKUP_DIR} 2>/dev/null
    }

    ${JAVA_TOOL} ${JSVC_OPTS} ${MAIN_CLASS} start
    
    exit

  if checkyesno ${rcvar}; then
    echo "Starting Omada Controller. "

    # Open up netcat to listen on port ${HTTP_PORT}, and then close the connection immediately, then quit.
    # This works around the long startup delay. Thanks to gcohen55.
    echo "" | nc -l 127.0.0.1 ${HTTP_PORT} >/dev/null &

    # The process will run until it is terminated and does not fork on its own.
    # So we start it in the background and stash the pid:
    /usr/local/bin/java -jar /usr/local/UniFi/lib/ace.jar start &
    echo $! > $pidfile

  fi
}

eapcontroller_stop()
{

echo -n "Stopping ${DESC} "
    ${JAVA_TOOL} ${JSVC_OPTS} -stop ${MAIN_CLASS} stop
    
    exit
    
  if [ -f $pidfile ]; then
    echo -n "Signaling the Omada Controller to stop..."

    # This process does take a while, but the stop command finishes before
    # the service is actually stopped. So we start it in the background:
    /usr/local/bin/java -jar /usr/local/UniFi/lib/ace.jar stop &

    # Get the pid of the stopper:
    stopper=$!

    # Wait until the stopper finishes:
    while [ `pgrep $stopper` ]; do
      echo -n "."
      sleep 5
    done

    echo " acknowledged."
    echo -n "Waiting for the Omada controller to stop (this can take a long time)..."

    # ...then we wait until the service identified by the pid file goes away:
    while [ `pgrep -F $pidfile` ]; do
      echo -n "."
      sleep 5
    done

    # Remove the pid file:
    rm $pidfile

    echo " stopped.";
  else
    echo "There is no pid file. The controller may not be running."
  fi
}

run_rc_command "$1"
