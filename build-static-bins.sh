#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

targetDir="$PWD/static-bins"

# usage: $0 part [part ...]
#    ie: $0 docker
if [ "$#" -lt 1 ]; then
	set -- docker containerd runc compose
	rm -rf "$targetDir" # if we're building all three, let's do it clean
fi
parts=( "$@" )

mkdir -p "$targetDir"

# make an easy lookup table
declare -A wantPart=()
for part; do
	wantPart[$part]=1
done

[ -z "${wantPart[docker]}" ] || ( set -x && snapcraft clean --step pull docker )
( set -x && snapcraft pull "${parts[@]}" )

export SNAPDIR="$PWD"

if [ "${wantPart[docker]}" ]; then
(
	cd parts/docker/src

	source "$SNAPDIR/prep-docker-build.sh"

	# devicemapper and static builds don't get along well
	export DOCKER_BUILDTAGS="$DOCKER_BUILDTAGS exclude_graphdriver_devicemapper"
	( set -x && ./hack/make.sh binary )

	dockerBin='bundles/latest/binary/docker'
	( set -x && "$dockerBin" -v )
	"$dockerBin" -v | grep -q "$DOCKER_GITCOMMIT"

	install -T "$(readlink -f "$dockerBin")" "$targetDir/docker"
)
fi

if [ "${wantPart[containerd]}" ]; then
(
	cd parts/containerd/src

	mkdir -p .gopath/src/github.com/docker
	ln -sfT "$PWD" .gopath/src/github.com/docker/containerd
	export GOPATH="$PWD/.gopath"

	( set -x && make static GIT_COMMIT= GIT_BRANCH= LDFLAGS= )

	( set -x && bin/containerd -v )

	install -T bin/containerd "$targetDir/docker-containerd"
	install -T bin/containerd-shim "$targetDir/docker-containerd-shim"
	install -T bin/ctr "$targetDir/docker-containerd-ctr"
)
fi

if [ "${wantPart[runc]}" ]; then
(
	cd parts/runc/src

	mkdir -p .gopath/src/github.com/opencontainers
	ln -sfT "$PWD" .gopath/src/github.com/opencontainers/runc
	export GOPATH="$PWD/.gopath"

	( set -x && make static BUILDTAGS='seccomp apparmor selinux' COMMIT= )

	( set -x && ./runc -v )

	install -T runc "$targetDir/docker-runc"
)
fi

if [ "${wantPart[compose]}" ]; then
(
	cd parts/compose/src

	baseImage='python:2.7-slim'
	case "$(dpkg --print-architecture)" in
		armhf) baseImage="armhf/$baseImage" ;;
		amd64) ;;
		*) echo >&2 "error: unknown architecture"; exit 1 ;;
	esac

	composeBuild='docker-snap'
	if git rev-parse &> /dev/null; then
		composeBuild+="-$(git rev-parse --short HEAD)"
	fi

	#			&& pip install pyinstaller \
	# we have to pull pyinstaller from a newer commit than 3.2 so that it both builds our bootloader on armhf and doesn't run into https://github.com/pyinstaller/pyinstaller/issues/1976
	cat > Dockerfile.static <<-EOF
		FROM $baseImage

		WORKDIR /usr/src/compose

		#COPY requirements-build.txt ./
		#RUN pip install -r requirements-build.txt
		RUN set -ex \
			&& buildDeps=' \
				gcc \
				libc6-dev \
				zlib1g-dev \
			' \
			&& runDeps=' \
				binutils \
				upx-ucl \
			' \
			&& apt-get update \
			&& apt-get install -y --no-install-recommends \$buildDeps \$runDeps \
			&& rm -rf /var/lib/apt/lists/* \
			&& pip install https://github.com/pyinstaller/pyinstaller/archive/501ad40fd22b2fca8cfee7652791323f5fd1754d.tar.gz \
			&& apt-get purge -y --auto-remove \$buildDeps

		COPY requirements.txt ./
		RUN pip install -r requirements.txt

		COPY . .
		RUN pip install --no-deps .

		RUN echo '$composeBuild' > compose/GITSHA
		RUN pyinstaller docker-compose.spec
	EOF

	docker build -t snap-docker:static-compose -f Dockerfile.static .
	docker run -i --rm snap-docker:static-compose cat dist/docker-compose > "$targetDir/docker-compose"
	chmod +x "$targetDir/docker-compose"

	"$targetDir/docker-compose" --version
)
fi
