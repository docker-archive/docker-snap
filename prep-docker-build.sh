#!/bin/bash

# should be sourced from snapcraft.yaml while building Docker
# current working directory should be the Docker source directory
# SNAPDIR should be set to the root of this Git repo
#   (the directory of snapcraft.yml)

for patch in "$SNAPDIR"/patches/*.patch; do
	echo "Applying $(basename "$patch") ..."
	patch \
		--batch \
		--forward \
		--strip 1 \
		--input "$patch"
	echo
done

export BUILDTIME="$(
	date --rfc-3339 ns 2>/dev/null | sed -e 's/ /T/' \
		|| date -u
)"

export DOCKER_BUILDTAGS='
	apparmor
	seccomp
	selinux
'
#	pkcs11

export AUTO_GOPATH=1
