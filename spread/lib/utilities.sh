#!/bin/bash

wait_for_systemd_service() {
	while ! systemctl status $1 ; do
		sleep 1
	done
	sleep 1
}

clean_all_containers() {
   sudo docker rm -f $(sudo docker ps -qa)
}

clean_all_images() {
   sudo docker rmi $(sudo docker images -aq)
}
