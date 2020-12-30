# Local Webserver: NGINX + SSL

An NGINX webserver with SSL built in (yes, on localhost!).

Adapted from this article by pentacent about an NGINX + Certbot webserver in docker-compose: https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71

## Requirements:

* docker
* docker-compose

## Usage

### Run `init.sh`

Run the initialization script as sudo (the docker daemon usually requires root access)

```
sudo ./init.sh
```

This creates a local root certificate authority and server certificate in the ./nginx/certs.d directory.

You should then trust this certificate. Methods to do this can vary between OS.

## Verify that the webserver is working

Visit https://dev.localhost and verify that the page SSL is working.


## Add another subdomain

Use the `add-site.sh` script to quickly add another subdomain pointing to a container that can serve webpages or APIs.

```
sudo ./add-site.sh -p 9000 portainer portainer_main_1
```
