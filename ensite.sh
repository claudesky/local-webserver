#!/bin/bash

SCRIPTNAME=$0

function usage {
    cat << EOF

Usage: $SCRIPTNAME [SUBDOMAIN]

A script to quickly enable a subdomain on the local webserver

EOF
}

if [[ "$#" == "0" ]]; then
    usage
    exit 1
fi

function checkRequirements {
    if [[ "$EUID" -ne 0 ]]; then
    echo "Error: Please run as root." >&2
    exit 1
    fi

    if ! [ -x "$(command -v docker-compose)" ]; then
    echo 'Error: docker-compose is not installed.' >&2
    exit 1
    fi
}

checkRequirements

subdomain=$1

if [[ ! -f "./nginx/sites-available/$subdomain.conf" ]]; then
    echo "Error: Specified subdomain is not configured." >&2
    exit 1
fi

echo "### Enabling website"
cd ./nginx/sites-enabled
ln -s ../sites-available/$subdomain.conf
echo

if ! docker-compose exec nginx nginx -t; then
    echo
    echo "Warning: There is a problem with existing configuration."
    echo "### Skipping nginx reload"
else
    echo
    echo "### Reloading nginx server config"
    docker-compose exec nginx nginx -s reload
fi
echo
