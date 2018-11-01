# Docker Snap

This repository contains the source for the `docker` snap package.  The package provides a distribution of Docker Community Edition (CE) for Ubuntu Core 16 (and other snap-compatible) systems.  It is built from an upstream Docker CE release tag with some patches to fit the snap format and is available on `armhf`, `arm64`, `amd64`, `i386`, and `ppc64el` architectures.  The rest of this page describes installation, usage, and development.

> *NOTE:* The Docker Snap is no longer maintained by Docker, Inc.  The last
> release version was 17.06.2 and will not be updated.  The future of the Docker
> Snap is unclear, but it won't be developed here going forward. The source at https://code.launchpad.net/~docker/+git/snap 
> may be updated. Questions for that repository may be asked at https://forum.snapcraft.io/.

## Installation

To install the latest stable release of Docker CE using `snap`:

    $ sudo snap install docker


If you are using Ubuntu Core 16,

* Connect the `docker:home` plug as it's not auto-connected by default:

      $ sudo snap connect docker:home

If you are using an alternative snap-compatible Linux distribution ("classic" in snap lingo), and would like to run `docker` as a normal user:

* Create and join the `docker` group.

      $ sudo addgroup --system docker
      $ sudo adduser $USER docker
      $ newgrp docker

* You will also need to disable and re-enable the `docker` snap if you added the group while it was running.

      $ sudo snap disable docker
      $ sudo snap enable docker

## Usage

Docker should function normally, with the following caveats:

* All files that `docker` needs access to should live within your `$HOME` folder.

  * If you are using Ubuntu Core 16, you'll need to work within a subfolder of `$HOME` that is readable by root. https://github.com/docker/docker-snap/issues/8

* `docker-compose` is available as `docker.compose` due to snap naming restrictions.
* Additional certificates used by the Docker daemon to authenticate with registries need to be located in `/var/snap/docker/common/etc/certs.d` instead of `/etc/docker/certs.d`.

### Examples

* [Setup a secure private registry](registry-example.md)

## Development

Developing the `docker` snap package is typically performed on a "classic" Ubuntu distribution.  The instructions here are written for Ubuntu 16.04 "Xenial".

* Install the snap tooling (requires `snapd>2.21` and `snapcraft>=2.26`):

      $ sudo apt-get install snapd snapcraft
      $ sudo snap install core

* Checkout this repository and build the `docker` snap package:

      $ git clone https://github.com/docker/docker-snap
      $ cd docker-snap
      $ sudo snapcraft

* Install the newly-created snap package:

      $ sudo snap install --dangerous docker_[VER]_[ARCH].snap

* Manually connect the relevant plugs and slots which are not auto-connected:

      $ sudo snap connect docker:privileged :docker-support
      $ sudo snap connect docker:support :docker-support
      $ sudo snap connect docker:firewall-control :firewall-control
      $ sudo snap connect docker:docker-cli docker:docker-daemon
      $ sudo snap disable docker
      $ sudo snap enable docker

  You should end up with output similar to:

      $ sudo snap interfaces docker
      Slot                  Plug
      :docker-support       docker:privileged,docker:support
      :firewall-control     docker
      :home                 docker
      :network              docker
      :network-bind         docker
      docker:docker-daemon  docker:docker-cli
