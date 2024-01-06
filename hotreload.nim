## This module implements a basic hot rebuild and restart mechanism
## for the webserver. When any file in the dynamic, static or layouts
## directory is changed, the running server process is killed, 
## a new webserver executable is rebuilt and restarted.

import os, browsers, times, tables, osproc, strformat
from main import IP_ADDR, PORT_NUM

proc getFileTimes(files: var Table[string, Time]) =
    for path in walkDirRec("dynamic", {pcFile}):
        if dirExists(path):
            continue
        files[path] = getLastModificationTime(path)
    for path in walkDirRec("static", {pcFile, pcDir}):
        if dirExists(path):
            continue
        files[path] = getLastModificationTime(path)
    for path in walkDirRec("layouts", {pcFile, pcDir}):
        if dirExists(path):
            continue
        files[path] = getLastModificationTime(path)

proc main() = 
    let nimPath = "/Users/bhm/.nimble/bin/nim"
    let binPath = getCurrentDir() / "bin"

    echo "Building..."
    discard execCmd(&"{nimPath} buildDev")

    echo "Starting webserver..."
    var curP: Process = startProcess(&"{binPath}/bhm.sh-DEV", options = {poParentStreams})
    openDefaultBrowser(&"http://{IP_ADDR}:{PORT_NUM}")

    var files: Table[string, Time] = initTable[string, Time]()
    getFileTimes(files)

    while true:
        sleep(300)
        for path, time in files.mpairs():
            let newTime = getLastModificationTime(path)
            if time != newTime:
                files[path] = newTime
                echo "File changed: ", path
                echo "Killing process: ", processID(curP)
                curP.kill()
                echo "Rebuilding..."
                discard execCmd(&"{nimPath} buildDev")
                echo "Restarting..."
                curP = startProcess(&"{binPath}/bhm.sh-DEV", options = {poParentStreams})
                openDefaultBrowser(&"http://{IP_ADDR}:{PORT_NUM}")
                continue

main()