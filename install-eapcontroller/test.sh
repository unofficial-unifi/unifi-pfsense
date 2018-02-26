#!/bin/sh

eapHome="/opt/tplink/EAPController"

nohup $JAVA_TOOL -server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30 -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -Deap.home="${eapHome}" -cp ${eapHome}"/lib/com.tp-link.eap.start-0.0.1-SNAPSHOT.jar:"${eapHome}"/lib/*:"${eapHome}"/external-lib/*" com.tp_link.eap.start.EapMain start > ${eapHome}/logs/startup.log 2>&1