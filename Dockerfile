FROM ubuntu:18.04
RUN apt install -y wget curl xz-utils systemd iputils-ping cron socat \
 && printf "1\nctgfw.ml\n" | bash <(curl -s -L https://github.com/V2RaySSR/Trojan/raw/master/Trojan.sh)
