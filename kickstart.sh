#!/usr/bin/env bash
# Right now this script only tested on Debian 12 and Ubuntu 22.04,
# fresh installed server is recommended.
#
# WARNING: DO NOT run this script if you:
# - Already have Nginx installed using distribution-provided package.
# - Have process that use port 80 and 443.

set -e

VTS_VER="v0.2.2" # See https://github.com/vozlt/nginx-module-vts/releases

PRI()
{
    echo
    echo "$1"
    echo
}

print_prog_desc()
{
    PRI "Script that help install Nginx using their official repository for Debian and Ubuntu."
    echo "WARNING: DO NOT run this script if you:"
    echo "- Already have Nginx installed using distribution-provided package."
    echo "- Have process that use port 80 and 443."
    echo
}

print_help()
{
    echo "Syntax: ${0} [-I|-V|-h]"
    echo "options:"
    echo "-I       [I]nstall Nginx."
    echo "-V       Only compile Nginx [V]TS module." 
    echo "-h       Print this [h]elp."
    echo
}

[ "$(id -u)" -ne 0 ] && echo "This script must be run as root" && exit 1

NGINX_INSTALLED=0
if command -v nginx &> /dev/null; then
    NGINX_INSTALLED=1
fi

[ ! -f /etc/os-release ] && echo "Distro not supported" && exit 1

. /etc/os-release
if [ "$ID" = "ubuntu" ]; then
    PREREQUISTES="ubuntu-keyring"
elif  [ "$ID" = "debian" ]; then
    PREREQUISTES="debian-archive-keyring"
else
    echo "Distro not supported"
    exit 1
fi

DISTRO=$ID

install()
{
    PRI "Detected Distro: $DISTRO"
    echo "This script will upgrade your system and install Nginx + GeoIP."
    echo "The /etc/nginx directory will be modified by this script."
    echo
    read -p "Do you want to continue? ([y]es/[n]o): " answer
    [ "$answer" != "y" ] && echo "Script execution aborted." && exit 0

    PRI "Performing system upgrade..."
    # apt-get update && apt-get upgrade -y
    apt-get update

    PRI "Installing prerequistes..."
    apt install sudo curl gnupg2 ca-certificates lsb-release ${PREREQUISTES} -y

    if [ ! -f /usr/share/keyrings/nginx-archive-keyring.gpg ]; then
        PRI "Import an official nginx signing key..."
        curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
            | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    fi
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
    mkdir -p /etc/nginx/{certs,sites-enabled,snippets}

    # The self-signed certificate only used for "boilerplate" config.
    # You must use certificates issued bt real CA, for example: certbot.
    if [ ! -f /etc/nginx/certs/dhparam.pem ]; then
        PRI "Creating self-signed certificates and dhparams..."
        openssl req -x509 -newkey rsa:4096 -days 365 -nodes \
            -keyout /etc/nginx/certs/privkey.pem            \
            -out /etc/nginx/certs/fullchain.pem             \
            -subj '/CN=example.local/O=My Organization/C=US'
        openssl dhparam -out /etc/nginx/certs/dhparam.pem 2048
    fi
    nginx -t && systemctl restart nginx
    echo
    echo "####################################################################"
    echo "                      Installation complete."
    echo "If this is your first time running this script and don't have any"
    echo "existing Nginx configuration that you set, you can simply copy"
    echo "files and directory under './etc/nginx'. Command:"
    echo
    echo "sudo cp -rT ./etc/nginx /etc/nginx && \\"
    echo "    sudo /etc/nginx/cloudflare-ips.sh"
    echo
    echo "Otherwise, take a look example configuration under './etc/nginx'"
    echo "directory by your self."
    echo "####################################################################"
}

compile_vts()
{
    [ "${NGINX_INSTALLED}" -eq 0 ] && echo "Nginx is not installed." && exit 1

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
    if [ ! -f "./nginx-${N_VER}/configure" ]; then
        curl -o "nginx-${N_VER}.tar.gz" "https://nginx.org/download/nginx-${N_VER}.tar.gz"
        tar -xvzf "nginx-${N_VER}.tar.gz"
    fi
    cd "nginx-${N_VER}"
    rm -rf "./nginx-module-vts"
    git clone -b "${VTS_VER}" https://github.com/vozlt/nginx-module-vts.git
    eval ./configure "${N_CONFIGURE_ARGS}"
    make modules -j"$(nproc)"
    cp objs/ngx_http_vhost_traffic_status_module.so /etc/nginx/modules/
    nginx -t && systemctl restart nginx
}

while getopts ":hIV" option; do
    case $option in
        h) # display Help
            print_prog_desc
            print_help
            exit;;
        I) # install
            install
            exit;;
        V) # compile VTS
            compile_vts
            exit;;
        \?) # Invalid option
        echo "Invalid option!"
        print_help
        exit;;
    esac
done

print_prog_desc
print_help

# vim: set ts=4 sw=4 et:
