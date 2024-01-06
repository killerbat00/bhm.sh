#!/usr/bin/env -S nim --hints:off

import os 

task hotReload, "compiles and runs in dev mode with hot reload":
    --forceBuild:on
    --hints:off
    --run
    --out:"bin/hotreload-DEV"
    setCommand "c", "hotreload.nim"

task runDev, "compiles and runs in dev mode":
    --forceBuild:on
    --checks:on
    --assertions:on
    --threads:on
    --lineTrace:on
    --mm:orc
    --debugger:native
    --define:debug
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

task clean, "cleans bin/ dir":
    if dirExists(binDir):
        rmDir(binDir)
        mkDir(binDir)