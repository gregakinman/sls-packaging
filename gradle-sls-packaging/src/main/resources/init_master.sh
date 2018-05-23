#!/bin/bash
#
# Copyright 2016 Palantir Technologies
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Everything in this script is relative to the base directory of an SLSv2 distribution
pushd "`dirname \"$0\"`/../.." > /dev/null

ACTION=$1
SCRIPT_DIR="service/bin"
SERVICE_INIT_SCRIPT="init_service.sh"
SIDECAR_INIT_SCRIPT="@sidecarInitScript@"
SERVICE="sidecar-test"

max() {
    LEFT=$1
    RIGHT=$2
    if [ $LEFT -ge $RIGHT ]; then
        return $LEFT
    else
        return $RIGHT
    fi
}

run_action() {
    INIT_SCRIPT=$1
    ACTION=$2
    VALUE=$(service/bin/$INIT_SCRIPT $ACTION &> /dev/null; echo $?)
    return $VALUE
}

start_process() {
    STATUS_CODE=$1
    INIT_SCRIPT=$2
    START_CODE=$(run_action $INIT_SCRIPT start; echo $?)
    if [ $START_CODE -ne 0 ]; then
        printf "%s\n" "Failed"
        exit $START_CODE
    fi
}

stop_process() {
    STATUS_CODE=$1
    INIT_SCRIPT=$2
    STOP_CODE=$(run_action $INIT_SCRIPT stop; echo $?)
    if [ $STOP_CODE -ne 0 ]; then
        printf "%s\n" "Failed"
        exit $STOP_CODE
    fi
}

case $ACTION in
start)
    printf "%-50s" "Starting '$SERVICE'..."
    SERVICE_STATUS_CODE=$(run_action $SERVICE_INIT_SCRIPT status; echo $?)
    SIDECAR_STATUS_CODE=$(run_action $SIDECAR_INIT_SCRIPT status; echo $?)

    if [ $SERVICE_STATUS_CODE -eq 0 ] && [ $SIDECAR_STATUS_CODE -eq 0 ]; then
        printf "%s\n" "'$SERVICE' is already running"
        exit 0
    fi

    start_process $SERVICE_STATUS_CODE $SERVICE_INIT_SCRIPT
    start_process $SIDECAR_STATUS_CODE $SIDECAR_INIT_SCRIPT
    printf "%s\n" "Started"
    exit 0
;;
status)
    printf "%-50s" "Checking status of '$SERVICE'..."
    SERVICE_STATUS_CODE=$(run_action $SERVICE_INIT_SCRIPT status; echo $?)
    SIDECAR_STATUS_CODE=$(run_action $SIDECAR_INIT_SCRIPT status; echo $?)

    # Return the most severe status of {service, sidecar}
    STATUS_CODE=$(max $SERVICE_STATUS_CODE $SIDECAR_STATUS_CODE; echo $?)
    case $STATUS_CODE in
    0)
        printf "%s\n" "Running"
    ;;
    1)
        printf "%s\n" "At least one process dead but pidfile exists"
    ;;
    3)
        printf "%s\n" "Not running"
    ;;
    *)
        printf "%s\n" "Status unknown"
    esac
    exit $STATUS_CODE
;;
stop)
    printf "%-50s" "Stopping '$SERVICE'..."
    SERVICE_STATUS_CODE=$(run_action $SERVICE_INIT_SCRIPT status; echo $?)
    SIDECAR_STATUS_CODE=$(run_action $SIDECAR_INIT_SCRIPT status; echo $?)

    if [ $SERVICE_STATUS_CODE -ne 0 ] && [ $SIDECAR_STATUS_CODE -ne 0 ]; then
        printf "%s\n" "Not running"
        exit 0
    fi

    stop_process $SERVICE_STATUS_CODE $SERVICE_INIT_SCRIPT
    stop_process $SIDECAR_STATUS_CODE $SIDECAR_INIT_SCRIPT
    printf "%s\n" "Stopped"
    exit 0
;;
restart)
    service/bin/init.sh stop
    service/bin/init.sh start
;;
*)
    # Support arbitrary additional actions; e.g. init-reload.sh will add a "reload" action
    if [[ -f "$SCRIPT_DIR/init-$ACTION.sh" ]]; then
        export LAUNCHER_CMD
        shift
        /bin/bash "$SCRIPT_DIR/init-$ACTION.sh" "$@"
        exit $?
    else
        COMMANDS=$(ls $SCRIPT_DIR | sed -ne '/init-.*.sh/ { s/^init-\(.*\).sh$/|\1/g; p; }' | tr -d '\n')
        echo "Usage: $0 {status|start|stop|restart${COMMANDS}}"
        exit 1
    fi
esac
