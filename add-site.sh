#!/bin/bash

SCRIPTNAME=$0

function usage {
    cat << EOF

Usage: $SCRIPTNAME [-p] [SUBDOMAIN] [CONTAINER NAME]

A script to quickly add a new site to your local webserver

Options:
  -p,  --port integer       Specify the port number to reverse proxy to
                            on the given container (default 80)

EOF
}

if [[ "$#" == "0" ]]; then
    usage
    exit 1
fi

function checkRequirements {
    echo "Checking docker access..."
    docker_ps=$(docker ps 2>&1)
    if [ "$?" -eq "1" ]; then
    echo "Error: accessing docker with message:" >&2
    echo "$docker_ps" >&2
    exit 1
    fi
    printf "docker access OK\n\n"

    echo "Checking docker compose..."
    if ! [ -x "$(command -v docker-compose)" ]; then
    echo "Error: docker-compose is not installed." >&2
    exit 1
    fi
    printf "docker-compose OK\n\n"

    echo "Checking existing container and config..."
    if ! docker-compose exec nginx nginx -t; then
    echo "Error: There is a problem with existing configuration." >&2
    exit 1
    fi
    printf "Existing container config OK\n\n"
}

checkRequirements

portnumber=80
subdomain=""
container_name=""

for arg do
    shift
    if [[ "$arg" == "--port" ]]; then
        portnumber=$1
        echo "### Using port $portnumber"
        echo
        shift
        continue
    fi
    set -- "$@" "$arg"
done

while getopts ":p:" opt; do
    case ${opt} in
        p )
            portnumber=$OPTARG
            echo "### Using port $portnumber"
            echo
            ;;
        \? )
            echo "Error: Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        : )
            echo "Error: Option -$OPTARG requires an argument" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

subdomain=$1
container_name=$2

if [[ -z "$subdomain" ]] || [[ -z "$container_name" ]]; then
    usage
    exit
fi

if [[ -f "./nginx/sites-available/$subdomain.conf" ]]; then
    while true; do
        echo "A configuration file already exists in ./nginx/sites-available/$subdomain.conf"
        read -p "Do you want to overwrite it? " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo
fi

echo "### Checking for '$container_name' docker container"
CONTAINERCHECK=$(docker container inspect $container_name -f '{{.Name}} - {{.Driver}} - {{.Config.ExposedPorts}}' >&1)
if [[ "$CONTAINERCHECK" == *"No such container"* ]]; then
    echo "Error: Specified container could not be found." >&2
    exit 1
fi
echo "$CONTAINERCHECK - OK"
echo

echo "### Creating website configuration at ./nginx/sites-available/$subdomain.conf"
cat > ./nginx/sites-available/$subdomain.conf << EOF
upstream $subdomain {
    server $container_name:$portnumber;
}

server {
    listen 443 ssl;
    server_name $subdomain.dev.localhost;

    ssl_certificate /etc/nginx/certs.d/server.crt;
    ssl_certificate_key /etc/nginx/certs.d/server.key;

    location / {
        proxy_pass http://$subdomain;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
    }
}

EOF
echo

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
