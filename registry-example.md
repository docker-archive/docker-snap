## Example: Setup a secure private registry

These instructions are intended to get you started quickly using the open source registry in a secure manner.  There are many configuration and deployment options not covered here (see [https://docs.docker.com/registry/](https://docs.docker.com/registry/) for more details).

* Install the `docker` snap on all systems.
* On the server node,

  * Generate a self-signed certificate replacing "mydockerhub.com" below with your fully qualified domain name:

        $ cd $HOME && mkdir certs
        $ openssl req -newkey rsa:2048 -nodes -sha256 \
                  -subj "/CN=mydockerhub.com" \
                  -x509 -days 3650 -out certs/domain.crt \
                  -keyout certs/domain.key

  * Create an `htpasswd` file, replacing "reguser" and "regpass" below with your desired credentials:

        $ cd $HOME && mkdir auth
        $ sudo docker run --entrypoint htpasswd registry:2 -Bbn reguser regpass > auth/htpasswd

  * Launch a basic authentication enabled registry server:

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

* On the client nodes,

  * If the server node is not resolvable by it's FQDN, add an override to `/etc/hosts`.
  * Copy the the certificate from the registry server to your client machine.

        $ scp user@registry_server_ip:/home/user/certs/domain.crt ./
        $ sudo mkdir -p /var/snap/docker/common/etc/certs.d/mydockerhub.com:5000
        $ sudo cp ./domain.crt /var/snap/docker/common/etc/certs.d/mydockerhub.com:5000/ca.crt

    > Note the special location `/var/snap/docker/common/etc/certs.d` instead of `/etc/docker/certs.d` mentioned in the [upstream documentation](https://docs.docker.com/engine/security/certificates/#understanding-the-configuration).

  * Login to the registry server:

        $ sudo docker login mydockerhub.com:5000

  * Validate functionality:

        $ sudo docker pull ubuntu
        $ sudo docker tag ubuntu mydockerhub.com:5000/ubuntu
        $ sudo docker push mydockerhub.com:5000/ubuntu
        $ sudo docker pull mydockerhub.com:5000/ubuntu
