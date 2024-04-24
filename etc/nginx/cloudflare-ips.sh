#!/usr/bin/env bash
# Nginx setup for cloudflare's IPs.
# This is modified version of itsjfx's cloudflare-nginx-ips
# Ref of original script:
# https://github.com/itsjfx/cloudflare-nginx-ips/blob/master/cloudflare-ips.sh

set -e

[ "$(id -u)" -ne 0 ] && echo "This script must be run as root" && exit 1

CF_REAL_IPS_PATH=/etc/nginx/snippets/cloudflare_real_ips.conf
CF_WHITELIST_PATH=/etc/nginx/snippets/cloudflare_whitelist.conf
CF_GEOIP_PROXY_PATH=/etc/nginx/snippets/cloudflare_geoip_proxy.conf

for file in $CF_REAL_IPS_PATH $CF_WHITELIST_PATH $CF_GEOIP_PROXY_PATH; do
    echo "# https://www.cloudflare.com/ips" > $file
    echo "# Generated at $(LC_ALL=C date)" >> $file
done

echo "geo \$realip_remote_addr \$cloudflare_ip {
    default 0;" >> $CF_WHITELIST_PATH

for type in v4 v6; do
    for ip in `curl -sL https://www.cloudflare.com/ips-$type`; do
        echo "set_real_ip_from $ip;" >> $CF_REAL_IPS_PATH;
        echo "    $ip 1;" >> $CF_WHITELIST_PATH;
        echo "geoip_proxy $ip;" >> $CF_GEOIP_PROXY_PATH;
    done
done

echo "}
# if your vhost is behind CloudFlare proxy and you want your site only
# accessible from Cloudflare proxy, add this in your server{} block:
# if (\$cloudflare_ip != 1) {
#    return 403;
# }" >> $CF_WHITELIST_PATH

nginx -t && systemctl reload nginx

# cron job:
# @monthly /bin/bash /etc/nginx/cloudflare-ips.sh

# vim: set ts=4 sw=4 et:
