#!/bin/sh

# Configuration File Location


#Prepare to start the loop and warn the user
echo "Press [CTRL+C] to stop..."

while :
do
#Connect to FreeNAS
    connect=$(sshpass -p ${PASSWORD} ssh -oStrictHostKeyChecking=no -t ${ROOT}@${FREENASIP} "/bin/sh /root/scripts/hdd_temp.sh" >/dev/null)
#Wait for a bit before checking again
sleep "${INTERVAL}"
done
