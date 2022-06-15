#!/bin/bash

MODE=$1
DEV_OUTPUT_FILE=bin/bhm.sh-DEV
RLS_OUTPUT_FILE=bin/bhm.sh
SRC_FILE=main.nim

if [[ "$MODE" == "dev" ]]; then
	nim c -o:$DEV_OUTPUT_FILE $2 $SRC_FILE
elif [[ "$MODE" == "DEV" ]]; then
	nim c -o:$DEV_OUTPUT_FILE $2 $SRC_FILE
elif [[ "$MODE" == "rls" ]]; then
	nim c -o:$RLS_OUTPUT_FILE -d:release $2 $SRC_FILE
elif [[ "$MODE" == "RLS" ]]; then
	nim c -o:$RLS_OUTPUT_FILE -d:release $2 $SRC_FILE
else
	echo "Usage:"
	echo "  ./build.sh {dev|rls} [-r]"
	echo ""
	echo "  Options:"
	echo "    dev - build development version"
	echo "    rls - build release version"
	echo "    -r  - run after building"
fi

