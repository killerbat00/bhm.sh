#!/usr/bin/env bash

red='\e[1;31m'
white='\e[0;37m'

shopt -s extglob

if [[ $EUID -eq 0 ]]; then
    echo "no root, pls."
    exit 1
fi

wet_run() {
    local MODE=$1
    local RUN=$2
    if [[ "${MODE,,}" == "dev" ]]; then
        nim clean
        nim runDev
    elif [[ "${MODE,,}" == "rls" ]]; then
        nim clean
        nim buildRls
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
Usage: $program_name [-t] {dev|rls}
Options:
    dev     build and run development version
    rls     build release version
EOF
}

main() {
    case "$1" in
        ''|-h|--help)
            usage
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
