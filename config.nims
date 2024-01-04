#!/usr/bin/env -S nim --hints:off

import os, strformat

version = "2024.01.04a"
author = "brian houston morrow"
description = "my personal website"
binDir = "bin"

requires("nim >= 2.0.0")

task runDev, "compiles and runs in dev mode":
    exec &"nim c -f -x -a -o:{binDir}/bhm.sh-DEV --threads:on --lineTrace:on --mm:orc --debugger:native -d:debug -r main.nim"

task buildRls, "compiles in relesae mode":
    exec &"nim c -o:{binDir}/bhm.sh -d:danger --opt:speed --passL:-s --passC:-flto main.nim"

task clean, "cleans bin/ dir":
    if dirExists(binDir):
        rmDir(binDir)
        mkDir(binDir)