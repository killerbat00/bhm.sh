#!/bin/bash

SRC_FILE=main.nim
RLS_OUTPUT_FILE=bin/bhm.sh
DEV_OUTPUT_FILE="${RLS_OUTPUT_FILE}"-DEV
DRY_RUN=0
MODE=$1
RUN=$2

if [[ "${MODE}" == "-t" ]]; then
    DRY_RUN=1
    MODE=$2
    RUN=$3
fi

if [[ "${MODE,,}" == "dev" ]]; then
    if [[ "$DRY_RUN" == "" ]]; then
	    nim c -o:$DEV_OUTPUT_FILE $RUN $SRC_FILE
    else
        echo "nim c -o:${DEV_OUTPUT_FILE} ${RUN} ${SRC_FILE}"
    fi
elif [[ "${MODE,,}" == "rls" ]]; then
    if [[ "$DRY_RUN" == "" ]]; then
	    nim c -o:$RLS_OUTPUT_FILE -d:release --opt:speed $RUN $SRC_FILE
    else
        echo "nim c -o:${RLS_OUTPUT_FILE} -d:release --opt:speed ${RUN} ${SRC_FILE}"
    fi
else
	echo "Usage:"
	echo "  ./build.sh [-t] {dev|rls} [-r]"
	echo ""
	echo "  Options:"
    echo "    -t    - dry run, echos commands"
    echo "    mode:"
	echo "      dev - build development version"
	echo "      rls - build release version"
	echo "    -r    - run after building"
fi

