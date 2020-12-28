#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: Please run as root." >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

rsa_key_size=4096
path="/etc/nginx/certs.d"

echo "### Checking for 'web' docker network"
WEBNET=$(docker network inspect web -f '{{.Name}} - {{.Driver}}' 2>&1)
if [[ "$WEBNET" == *"No such network"* ]]; then
  docker network create web
else
  echo $WEBNET "OK"
fi
echo

echo "### Creating root ssl certificate"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:4096 -days 365 \
    -keyout '$path/root.key' \
    -out '$path/root.pem' \
    -subj '/CN=*.dev.localhost'" nginx
echo

echo "### Creating server certificate request"
docker-compose run --rm --entrypoint "\
  openssl req -nodes -new -newkey rsa:4096 \
    -keyout '$path/server.key' \
    -out '$path/server.csr' \
    -subj '/CN=*.dev.localhost'" nginx
echo

echo "### Signing server certificate"
docker-compose run --rm --entrypoint "\
  openssl x509 -req -days 365 -sha256 \
    -extfile '$path/v3.ext' \
    -CA '$path/root.pem' \
    -CAkey '$path/root.key' \
    -CAcreateserial \
    -in '$path/server.csr' \
    -out '$path/server.crt'" nginx
echo

echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Done! Please add the certificate to trust store"
echo "The certificate is located at ./nginx/certs.d/root.pem"
