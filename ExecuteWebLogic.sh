#!/bin/bash
cd /
su - gsh
cd /scratch/gsh/kernel145/user_projects/domains/integrated/bin
sh /scratch/gsh/kernel145/user_projects/domains/integrated/bin/startNodeManager.sh &
sh /scratch/gsh/kernel145/user_projects/domains/integrated/bin/startWebLogic.sh &
