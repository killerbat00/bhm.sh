#!/usr/bin/env -S nim --hints:off

import std/distros
from os import dirExists

var binDir = "bin"

task hotReload, "compiles and runs in dev mode with hot reload":
    --forceBuild:on
    --hints:off
    --run
    --out:"bin/hotreload-DEV"
    setCommand "c", "hotreload.nim"

task runDev, "compiles and runs in dev mode":
    if defined(macosx):
        --forceBuild:on
        --checks:on
        --assertions:on
        --threads:on
        --lineTrace:on
        --mm:orc
        --debugger:native
        --cc:clang
        --define:debug
        --deepcopy:on
        --cpu:arm64
        --passC:"-flto -target arm64-apple-macos11" 
        --passL:"-flto -target arm64-apple-macos11"
    else:
        --forceBuild:on
        --checks:on
        --assertions:on
        --threads:on
        --lineTrace:on
        --mm:orc
        --debugger:native
        --define:debug
    --hints:off
    --run
    --out:"bin/bhm.sh-DEV"
    setCommand "c", "main.nim"

task buildDev, "compiles in dev mode":
    --forceBuild:on
    --checks:on
    --assertions:on
    --threads:on
    --lineTrace:on
    --mm:orc
    --debugger:native
    --define:debug
    --hints:off
    --out:"bin/bhm.sh-DEV"
    setCommand "c", "main.nim"

task buildRls, "compiles in release mode":
    --define:danger
    --opt:speed
    --passL:"-s"
    --passC:"-flto"
    --out:"bin/bhm.sh"
    setCommand "c", "main.nim"

#task clean, "cleans bin/ dir":
#    if dirExists(binDir):
#        rmDir(binDir)
#        mkDir(binDir)