# Docker-snap

Docker for snappy. This snap allows you to use the full capabilities of docker on snappy. In order to use 'docker build', 'docker save' 'docker load' and 'docker.compose', you need to place your dockerfile or docker-compose.yml within $HOME. All files that you want docker to access to must be within this path. You may also use the 'docker-privilege' command to allow you to use 'docker run --privileged'. Because docker is unencumbered on snappy, it is recommended that you follow the Docker project's recommendations for using docker securely.

### Installation

If you would like to build docker as a snap package, please make sure
you have snapd(> 2.21) and snapcraft(2.26) packages installed firstly.

```
$ sudo apt-get install snapd snapcraft
$ sudo snap install core
```

Then fetch the source code from the repo and run the following command to create a snap package.

```
$ sudo snapcraft
```

After it's done, you can run the following command to install it locally.

```
$ sudo snap install --dangerous docker_[VER]_[ARCH].snap
```

If you build the snap from source and install it locally, you need to run 
the following command to connect relevant plugs and slots.
```
$ snap connect docker:privileged :docker-support
$ snap connect docker:support :docker-support
$ snap connect docker:firewall-control :firewall-control
$ snap connect docker:network :network
$ snap connect docker:network-bind :network-bind
$ snap connect docker:docker-cli docker:docker-daemon
$ snap connect docker:home :home
$ snap disable docker
$ snap enable docker
```

Also you can install docker snap from the store by simply running the following
command. You can skip above plug and slot connections if snap is installed from the store, except home plug.

```
$ sudo snap install docker
```

Several target architectures[armhf, arm64, amd64, i386, ppc64el] are supported at this moment.


### How to use
Due to the confinement issues on snappy, it requires some manual setup to make docker-snap works on your machine.
On Ubuntu classic, before installing the docker snap,
please run the following command to add the login user into docker group so that you can use docker without sudo.

```
$ sudo addgroup --system docker
$ sudo adduser $USER docker
$ newgrp docker
```

On Ubuntu Core 16, after installing the docker snap from store,
you need to connect the home plug as it's not auto-connected by default.

```
$ sudo snap connect docker:home :home
```

Then have fun with docker in snappy.


### Setup a secure private registry
To setup a secure private registry, Below is the instruction that people can follow.
You can also follow the link [here](https://docs.docker.com/registry/deploying/#running-a-domain-registry) to setup it.


---Docker registry server setup

1. Follow the above steps to install docker snap on your server machine.
2. Generate a self-signed certificate and replace the common name(mydockerhub.com) with your fully qualified domain name.
```
$ cd $HOME && mkdir certs
$ openssl req -newkey rsa:2048 -nodes -sha256 \
                      -subj "/CN=mydockerhub.com" \
                      -x509 -days 3650 -out certs/domain.crt \
                      -keyout certs/domain.key
```

3. Create a password file with one entry for the user "foo", with password "foo123"
```
$ cd $HOME && mkdir auth
$ sudo docker run --entrypoint htpasswd registry:2 -Bbn foo foo123 > auth/htpasswd
```

4. Create basic authentication enabled registry server.
```
$ sudo docker run -d -p 5000:5000 \
            --restart=always \
            --name registry \
            -v `pwd`/auth:/auth \
            -e "REGISTRY_AUTH=htpasswd" \
            -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
            -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
            -v `pwd`/registry:/tmp/registry \
            -v `pwd`/certs:/certs  \
            -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
            -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
            registry:2
```

---Docker client setup

5. Follow the above steps to install docker snap on your client machine.
6. Edit /etc/hosts file and add one entry to the file.

   e.g. registry_server_ip mydockerhub.com

7. Copy the the certificate from the registry server to your client machine.
```
$ scp user@registry_server_ip:/home/user/certs/domain.crt ./
$ sudo mkdir -p /var/snap/docker/common/etc/certs.d/mydockerhub.com:5000
$ sudo cp ./domain.crt /var/snap/docker/common/etc/certs.d/mydockerhub.com:5000/ca.crt
```
8. Login to registry server with the newly created user("foo") 
```
$ sudo docker login mydockerhub.com:5000
```

9. Pull image from the private registry on another docker host
```
$ sudo docker pull ubuntu #pull ubuntu image from official docker hub 
$ sudo docker tag ubuntu mydockerhub.com:5000/ubuntu $ tag it to private docker hub
$ sudo docker push mydockerhub.com:5000/ubuntu $ push it to private docker hub
$ sudo docker pull mydockerhub.com:5000/ubuntu $ pull the image from private docker hub
```


### Notes

Due to the confinement, a few things to be aware of when launching a registry server in snappy.

* When generating certificates by using openssl or creating a password file, 
  please place certs and auth directory in a writable path. e.g $HOME.
* For secure private registry server, you need to create a directory on every docker client and copy domain.crt 
  to the directory before login to registry server as mentioned [here](https://docs.docker.com/engine/security/certificates/#understanding-the-configuration).
  However, the full path of directory is /var/snap/docker/common/etc/certs.d instead of /etc/docker/certs.d as /etc is read-only in snappy.
  We might probably support certificate directory configurable in the future via [hooks](https://github.com/snapcore/snapd/wiki/hooks).
