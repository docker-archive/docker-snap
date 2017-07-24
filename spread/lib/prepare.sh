#!/bin/bash

echo "Wait for firstboot change to be ready"
while ! snap changes | grep -q "Done"; do
	snap changes || true
	snap change 1 || true
	sleep 1
done

echo "Ensure fundamental snaps are still present"
. $TESTSLIB/snap-names.sh
for name in $gadget_name $kernel_name $core_name; do
	if ! snap list | grep -q $name ; then
		echo "Not all fundamental snaps are available, all-snap image not valid"
		echo "Currently installed snaps:"
		snap list
		exit 1
	fi
done

echo "Kernel has a store revision"
snap list | grep ^${kernel_name} | grep -E " [0-9]+\s+canonical"

# Pre-install docker
if [ -n "$SNAP_CHANNEL" ] ; then
	# Don't reinstall if we have it installed already
	if ! snap list | grep docker ; then
		snap install --$SNAP_CHANNEL docker
        snap connect docker:home :home
	fi
else
	# Install prebuilt docker snap
	snap install --dangerous /home/docker/docker_*_amd64.snap
	# As we have a snap which we build locally its unasserted and therefor
	# we don't have any snap-declarations in place and need to manually
	# connect all plugs.
    snap connect docker:privileged :docker-support
    snap connect docker:support :docker-support
    snap connect docker:firewall-control :firewall-control
    snap connect docker:network :network
    snap connect docker:network-bind :network-bind
    snap connect docker:docker-cli docker:docker-daemon
    snap connect docker:home :home
fi

# Remove any existing state archive from other test suites
rm -f $SPREAD_PATH/snapd-state.tar.gz
rm -f $SPREAD_PATH/docker-state.tar.gz

# Snapshot of the current snapd state for a later restore
if [ ! -f $SPREAD_PATH/snapd-state.tar.gz ] ; then
	sudo systemctl stop snapd.service snapd.socket
	tar czfP $SPREAD_PATH/snapd-state.tar.gz /var/lib/snapd /etc/netplan
	sudo systemctl start snapd.socket
fi

# And also snapshot current docker's state
if [ ! -f $SPREAD_PATH/docker-state.tar.gz ] ; then
    sudo systemctl stop snap.docker.dockerd
    tar czfP $SPREAD_PATH/docker-state.tar.gz /var/snap/docker
    sudo systemctl start snap.docker.dockerd
fi

# For debugging dump all snaps and connected slots/plugs
snap list
snap interfaces
