# Nginx Kickstart

A bash script that helped me install Nginx + GeoIP module (and optionally compile VTS module, with example config) on FRESH **Debian** or **Ubuntu** system.

> **NOTE**: Only tested on **Debian** `12` and **Ubuntu** `22.04`.
>
> **WARNING**: **DO NOT** run this script if you:
>
> - Already have Nginx installed using distribution-provided package.
> - Have process that use port 80 and 443.

## What does this script do?

When you run the `kickstart.sh` script with `-I` option:

1. Upgrade your system and install required packages.
2. Import official Nginx signing key to `/usr/share/keyrings/nginx-archive-keyring.gpg`.
3. Add Nginx apt repository to `/etc/apt/sources.list.d/nginx.list`.
4. Prioritize Nginx official packages over distribution-provided ones.
5. Install `nginx` and  `nginx-module-geoip`.
6. Create "boilerplate" directory (`/etc/nginx/{certs,sites-enabled,snippets}`).
7. Generate self-signed certificate and DH Params key exchange.

When you run the `kickstart.sh` scipt with `-V` option:

1. Install required packages to compile Nginx VTS module (`git`, `build-essential`, `libpcre3-dev`, `zlib1g-dev`, and `libssl-dev`).
2. Download your current running Nginx version archive from `https://nginx.org/download` and place it to `./compile` directory.
3. Clone [vozlt/nginx-module-vts](https://github.com/vozlt/nginx-module-vts.git) and compile the dynamic module.
4. Copy compiled VTS module to `/etc/nginx/modules/ngx_http_vhost_traffic_status_module.so`.
5. Restart nginx service

## Usage

```shell
# Clone this repository
git clone https://github.com/ditatompel/nginx-kickstart.git && cd nginx-kickstart
# To install Nginx with GeoIP module
sudo ./kickstart.sh -I
# To compile Nginx VTS module
sudo ./kickstart.sh -V
```

If this is your first time running the script and don't have any existing Nginx configuration that you already set, you can simply copy files and directory under [./etc/nginx](./etc/nginx) to your `/etc/nginx` directory by issuing this command:

```
sudo cp -rT ./etc/nginx /etc/nginx && \
    sudo /etc/nginx/cloudflare-ips.sh
```

By default, Nginx VTS module is not loaded, search for `vhost_traffic_status` keywords in [./etc/nginx/nginx.conf](./etc/nginx/nginx.conf), [./etc/nginx/conf.d/default.conf](./etc/nginx/conf.d/default.conf), and [./etc/nginx/sites-available/example.local.conf](./etc/nginx/sites-available/example.local.conf) and uncomment that configuration example.

If you following usage instruction above, your `/etc/nginx` directory structure should similar like this:

```
.
|-- cloudflare-ips.sh
|-- conf.d
|   `-- default.conf
|-- fastcgi_params
|-- mime.types
|-- modules -> /usr/lib/nginx/modules
|-- nginx.conf
|-- scgi_params
|-- sites-available
|   `-- example.local.conf
|-- sites-enabled
|-- snippets
|   |-- cloudflare_geoip_proxy.conf
|   |-- cloudflare_real_ips.conf
|   |-- cloudflare_whitelist.conf
|   `-- ssl-params.conf
|-- certs
|   |-- dhparam.pem
|   |-- fullchain.pem
|   `-- privkey.pem
`-- uwsgi_params
```

## Attributions and Resources

- [nginx.org](https://nginx.org/en/).
- [vozlt/nginx-module-vts](https://github.com/vozlt/nginx-module-vts): Nginx virtual host traffic status module.
- [itsjfx/cloudflare-nginx-ips](https://github.com/itsjfx/cloudflare-nginx-ips.git).
