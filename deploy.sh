#!/bin/bash

./build.sh rls
ssh -t root@bhm.sh 'service bhmsh stop'
scp bin/bhm.sh bhm.sh:~/
ssh -t root@bhm.sh 'service bhmsh start'
