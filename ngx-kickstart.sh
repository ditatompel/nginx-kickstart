#!/usr/bin/env bash
# Right now this script only tested on Ubuntu 22.04,
# fresh installed server is recommended.
# WARNING: DO NOT run this script if you:
# - Already have Nginx installed
# - Have process that use port 80 and 443.

set -e

COMPILE_VTS=1    # Set 0 if you don't want to compile VTS module
VTS_VER="v0.2.2" # See https://github.com/vozlt/nginx-module-vts/releases

[ "$(id -u)" -ne 0 ] && echo "This script must be run as root" && exit 1

#if command -v nginx &> /dev/null; then
#    echo "Refuse to continue, Nginx seems already installed."
#    exit 1
#fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    [ "$ID" != "ubuntu" ] && echo "Distro not supported" && exit 1
    DISTRO=$ID
    PREREQUISTES="ubuntu-keyring"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PREREQUISTES="debian-archive-keyring"
else
    echo "Distro not supported"
    exit 1
fi

PRI()
{
    echo
    echo "$1"
    echo
}

PRI "Detected Distro: $DISTRO"

echo "This script will upgrade your system and install Nginx + GeoIP."
echo "The /etc/nginx directory will be modified by this script."
if [ "${COMPILE_VTS}" -eq 1 ]; then
    echo "Additionally, this script will compile the Nginx VTS module."
fi
echo
read -p "Do you want to continue? ([y]es/[n]o): " answer
[ "$answer" != "y" ] && echo "Script execution aborted." && exit 0

PRI "Performing system upgrade..."
apt-get update && apt-get upgrade -y

PRI "Installing prerequistes..."
sudo apt install curl gnupg2 ca-certificates lsb-release ${PREREQUISTES} -y

PRI "Import an official nginx signing key..."
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

# Set up the apt repository for stable nginx packages
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/${DISTRO} $(lsb_release -cs) nginx" > \
    /etc/apt/sources.list.d/nginx.list

# Set up repository pinning to prefer official packages
# over distribution-provided ones...
printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > \
    /etc/apt/preferences.d/99nginx

PRI "Installing Nginx and nginx-module-geoip"
apt-get update && apt-get install nginx nginx-module-geoip -y

# Creating and copying our nginx config directory
mkdir -p /etc/nginx/{ssl,sites-enabled}
cp -rT ./etc/nginx /etc/nginx

# The self-signed certificate only used for "boilerplate" config.
# You must use certificates issued bt real CA, for example: certbot.
PRI "Creating self-signed certificates and dhparams..."
openssl req -x509 -newkey rsa:4096 -days 365 -nodes \
    -keyout /etc/nginx/ssl/privkey.pem              \
    -out /etc/nginx/ssl/fullchain.pem               \
    -subj '/CN=example.local/O=My Organization/C=US'
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

nginx -t && systemctl restart nginx

# ########### #
# VTS compile #
# ########### #

[ $COMPILE_VTS -ne 1 ] && exit 0

PRI "Compiling VTS module..."
apt install git build-essential libpcre3-dev zlib1g-dev libssl-dev -y

NGINX_V=$(nginx -V 2>&1)
N_VER=$(echo "$NGINX_V" | grep -oP 'nginx/\K[0-9.]+')
N_CONFIGURE_ARGS=$(echo "$NGINX_V" | grep -oP 'configure arguments: \K.*')
N_CONFIGURE_ARGS="${N_CONFIGURE_ARGS} --add-dynamic-module=./nginx-module-vts/"

echo "Version: $N_VER"
echo "Configure Arguments: $N_CONFIGURE_ARGS"
mkdir -p "./compile"
cd compile
if [ ! -f "./compile/nginx-${N_VER}/configure" ]; then
    curl -o "nginx-${N_VER}.tar.gz" "https://nginx.org/download/nginx-${N_VER}.tar.gz"
    tar -xvzf "nginx-${N_VER}.tar.gz"
fi
cd "nginx-${N_VER}"
rm -rf "./nginx-module-vts"
git clone -b "${VTS_VER}" https://github.com/vozlt/nginx-module-vts.git
eval ./configure "${N_CONFIGURE_ARGS}"
make -j"$(nproc)"
cp objs/ngx_http_vhost_traffic_status_module.so /etc/nginx/modules/
nginx -t && systemctl restart nginx

# vim: set ts=4 sw=4 et:
