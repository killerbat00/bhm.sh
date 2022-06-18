#!/bin/bash

./build.sh rls
ssh -t bhm.sh 'sudo service bhmsh stop'
scp bin/bhm.sh bhm.sh:~/
ssh -t bhm.sh 'sudo service bhmsh start'
