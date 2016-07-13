#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

targetDir="$PWD/static-bins"
rm -rf "$targetDir"
mkdir "$targetDir"

parts=( docker containerd runc )
snapcraft clean --step pull "${parts[@]}"
snapcraft pull "${parts[@]}"

export SNAPDIR="$PWD"

(
	cd parts/docker/src

	source "$SNAPDIR/prep-docker-build.sh"

	# devicemapper and static builds don't get along well
	export DOCKER_BUILDTAGS="$DOCKER_BUILDTAGS exclude_graphdriver_devicemapper"
	./hack/make.sh binary

	dockerBin='bundles/latest/binary/docker'
	"$dockerBin" -v
	"$dockerBin" -v | grep -q "$DOCKER_GITCOMMIT"

	install -T "$(readlink -f "$dockerBin")" "$targetDir/docker"
)

(
	cd parts/containerd/src

	mkdir -p .gopath/src/github.com/docker
	ln -sfT "$PWD" .gopath/src/github.com/docker/containerd
	export GOPATH="$PWD/.gopath"

	make static GIT_COMMIT= GIT_BRANCH= LDFLAGS=

	bin/containerd -v

	install -T bin/containerd "$targetDir/docker-containerd"
	install -T bin/containerd-shim "$targetDir/docker-containerd-shim"
	install -T bin/ctr "$targetDir/docker-containerd-ctr"
)

(
	cd parts/runc/src

	mkdir -p .gopath/src/github.com/opencontainers
	ln -sfT "$PWD" .gopath/src/github.com/opencontainers/runc
	export GOPATH="$PWD/.gopath"

	make static BUILDTAGS='seccomp apparmor selinux' COMMIT=

	./runc -v

	install -T runc "$targetDir/docker-runc"
)
