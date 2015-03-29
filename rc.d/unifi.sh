#!/bin/sh

# REQUIRE: FILESYSTEMS
# REQUIRE: NETWORKING
# PROVIDE: unifi

. /etc/rc.subr

name="unifi"
rcvar="unifi_enable"
start_cmd="unifi_start"
stop_cmd="unifi_stop"

pidfile="/var/run/${name}.pid"

load_rc_config ${name}

unifi_start()
{
  if checkyesno ${rcvar}; then
    echo "Starting UniFi controller. "

    # Open up netcat to listen on port 8080, and then close the connection immediately, then quit.
    # This works around the long startup delay. Thanks to gcohen55.
    echo "" | nc -l 127.0.0.1 8080 >/dev/null &

    # The process will run until it is terminated and does not fork on its own.
    # So we start it in the background and stash the pid:
    /usr/local/bin/java -jar /usr/local/UniFi/lib/ace.jar start &
    echo $! > $pidfile

  fi
}

unifi_stop()
{

  if [ -f $pidfile ]; then
    echo -n "Signaling the UniFi controller to stop..."

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
    echo -n "Waiting for the UniFi controller to stop (this can take a long time)..."

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
