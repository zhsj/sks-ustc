#!/bin/bash

set -ex

if [[ "$EUID" -ne 0 ]]; then
	echo "Please run as root!"
	exit 1
fi

if ! docker info; then
	wget https://download.docker.com/linux/debian/gpg -O /etc/apt/trusted.gpg.d/docker
	gpg --dearmor /etc/apt/trusted.gpg.d/docker
	rm -f /etc/apt/trusted.gpg.d/docker
	echo deb https://download.docker.com/linux/debian stretch stable > /etc/apt/sources.list.d/docker.list
	apt update
	apt install -y --no-install-recommends docker-ce
	systemctl enable --now docker
fi

docker pull zhusj/sks:full

if [[ ! -e /var/lib/sks ]]; then
	s3fs keydump /mnt -o url=http://s3.zhsj.me/ -o use_path_request_style -o public_bucket=1
	docker run --rm -v /var/lib/sks/:/var/lib/sks/ -v /mnt/2018-06-16/:/var/lib/sks/dump/ zhusj/sks:full sks-init
	fusermount -u /mnt/
fi

cur=$(dirname "$(readlink -f "$0")")
rm -f /var/lib/sks/membership
cp "$cur/membership" /var/lib/sks/membership
rm -f /var/lib/sks/sksconf
cp "$cur/sksconf" /var/lib/sks/sksconf
rm -f /var/lib/sks/caddy/Caddyfile
cp "$cur/Caddyfile" /var/lib/sks/caddy/Caddyfile
rm -rf /var/lib/sks/web
cp -r "$cur/web" /var/lib/sks/web

docker rm -v -f sks-keyserver || true

docker run -it -d --restart=always --name sks-keyserver \
  --log-opt max-size=10m --log-opt max-file=2 \
  -v /var/lib/sks/:/var/lib/sks/ \
  --network=host zhusj/sks:full

docker image prune -f -a
