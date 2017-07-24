#!/bin/bash 
 
. $TESTSLIB/snap-names.sh 
. $TESTSLIB/utilities.sh 
 
# Remove all snaps not being the core, gadget, kernel or snap we're testing 
for snap in /snap/*; do 
    snap="${snap:6}" 
    case "$snap" in 
        "bin" | "$gadget_name" | "$kernel_name" | "$core_name" | "$SNAP_NAME" ) 
            ;;  
        *)  
            snap remove "$snap" 
            ;;  
    esac 
done 
 
# Ensure we have the same state for snapd as we had before 
sudo systemctl stop snapd.service snapd.socket 
rm -rf /var/lib/snapd/* 
ls -al $SPREAD_PATH/snapd-state.tar.gz
tar xzf $SPREAD_PATH/snapd-state.tar.gz -C / 
rm -rf /root/.snap 
sudo systemctl start snapd.service snapd.socket 
wait_for_systemd_service snapd.service 
wait_for_systemd_service snapd.socket 
 
# sudo systemctl stop snap.docker.dockerd
# rm -rf /var/snap/docker/* 
# ls -al $SPREAD_PATH/docker.tar.gz
# tar xzf $SPREAD_PATH/docker.tar.gz -C / 
# sudo systemctl start snap.docker.dockerd
# wait_for_systemd_service snap.docker.dockerd 
