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

# aww, can't use "git ls-remote" on launchpad:
#  fatal: unable to access 'https://github.com/docker/docker.git/': Could not resolve host: github.com
# Loïc: you can, but only during the pull phase
DOCKER_GITCOMMIT="$(
	git ls-remote --tags \
		https://github.com/docker/docker.git \
		"refs/tags/v$(< VERSION)^{}" \
	| cut -b1-7 \
	|| echo "v$(< VERSION)"
)-snap"
if git rev-parse &> /dev/null; then
	DOCKER_GITCOMMIT+="-$(git rev-parse --short HEAD)"
fi
export DOCKER_GITCOMMIT
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
