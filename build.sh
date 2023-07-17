#!/usr/bin/env bash

red='\e[1;31m'
white='\e[0;37m'

shopt -s extglob

if [[ $EUID -eq 0 ]]; then
    echo "no root, pls."
    exit 1
fi

SRC_FILE=main.nim
OUTPUT_DIR=bin
RLS_OUTPUT_FILE="${OUTPUT_DIR}"/bhm.sh
DEV_OUTPUT_FILE="${RLS_OUTPUT_FILE}"-DEV


dry_run() {
    local MODE=$1
    local RUN=$2
    if [[ "${MODE,,}" == "dev" ]]; then
        echo "rm ${DEV_OUTPUT_FILE}"
        echo "nim c -o:${DEV_OUTPUT_FILE} ${RUN} ${SRC_FILE}"
    elif [[ "${MODE,,}" == "rls" ]]; then
        echo "rm ${RLS_OUTPUT_FILE}"
        echo "nim c -o:${RLS_OUTPUT_FILE} -d:danger --opt:speed --passL:-s --passC:-flto ${RUN} ${SRC_FILE}"
    else
        echo -e "$red Include one of {dev|rls} $white"
        usage
        exit 1
    fi
}

wet_run() {
    local MODE=$1
    local RUN=$2
    if [[ "${MODE,,}" == "dev" ]]; then
        rm $DEV_OUTPUT_FILE
        nim c -o:$DEV_OUTPUT_FILE $RUN $SRC_FILE
    elif [[ "${MODE,,}" == "rls" ]]; then
        rm $RLS_OUTPUT_FILE
        nim c -o:$RLS_OUTPUT_FILE -d:danger --opt:speed --passL:-s --passC:-flto $RUN $SRC_FILE
    else
        echo -e "$red Include one of {dev|rls} $white"
        usage
        exit 1
    fi
}

usage() {
    local program_name
    program_name=${0##*/}
    cat <<EOF
Usage: $program_name [-t] {dev|rls} [-r]
Options:
    -t      dry run, echos commands without executing
    dev     build development version
    rls     build release version
    -r      run after building
EOF
}

main() {
    case "$1" in
        ''|-h|--help)
            usage
            exit 0
            ;;
        -t)
            dry_run $2 $3
            exit 0
            ;;
        dev|rls|DEV|RLS)
            wet_run $1 $2
            exit 0
            ;;
        *)
            echo -e "$red computer says no $white"
            usage
            exit 1
            ;;
    esac

}

main "$@"
