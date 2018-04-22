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
	apt install -y docker-ce
	systemctl enable --now docker
fi

docker pull zhusj/sks:full

if [[ ! -e /var/lib/sks ]]; then
	mkdir -p /var/lib/sks/dump
	(
		cd /var/lib/sks/dump
		wget -crp -e robots=off -l1 --no-parent --cut-dirs=3 -nH -A pgp,txt https://keyserver.mattrude.com/dump/current
		md5sum -c metadata-sks-dump.txt
	)
	docker run --rm -v /srv/docker/sks/:/var/lib/sks/ zhusj/sks:full sks-init
	rm -rf /var/lib/sks/dump
	cur=$(dirname "$(readlink -f "$0")")
	rm -f /var/lib/sks/membership
	ln -s "$cur/membership" /var/lib/sks/membership
	rm -f /var/lib/sks/sksconf
	ln -s "$cur/sksconf" /var/lib/sks/sksconf
	rm -f /var/lib/sks/caddy/Caddyfile
	ln -s "$cur/Caddyfile" /var/lib/sks/caddy/Caddyfile
	rm -f /var/lib/sks/web/index.html
	ln -s "$cur/index.html" /var/lib/sks/web/index.html
fi

docker rm -v -f sks-keyserver || true

docker run -it -d --restart=always --name sks-keyserver \
  -v /srv/docker/sks/:/var/lib/sks/ \
  --network=host zhusj/sks:full

docker image prune -f -a
