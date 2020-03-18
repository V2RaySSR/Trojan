#!/bin/bash
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
fi

clear
green "=========================================================="
 blue "支持：centos7+/debian9+/ubuntu16.04+"
 blue "网站：www.v2rayssr.com （已开启禁止国内访问）"
 blue "YouTube频道：波仔分享"
green "=========================================================="
  red "简介：本脚本为Trojan分解安装第一部分（安装依赖环境和服务）"
green "=========================================================="
read -s -n1 -p "若同意上述协议，请按任意键继续 ... "
green " "
if cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
yum install epel-release
fi
$systemPackage update
$systemPackage -y install sudo nginx wget unzip zip curl tar
systemctl enable nginx
systemctl stop nginx
	green "======================="
	blue "请输入绑定到本VPS的域名"
	green "======================="
	read your_domain
	real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
	local_addr=`curl ipv4.icanhazip.com`
	green " "
	green " "
	green "==================================="
	 blue "检测到域名解析地址为 $real_addr"
	 blue "本VPS的IP为 $local_addr"
	green "==================================="
	sleep 3s
if [ $real_addr == $local_addr ] ; then
	green " "
	green " "
	green "=========================================="
	blue "        开始安装Nginx并配置"
	green "=========================================="
	sleep 3s
cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF
	green " "
	green " "
	green "=========================================="
	blue "      开始下载伪装站点源码并部署"
	green "=========================================="
	sleep 3s
	rm -rf /usr/share/nginx/html/*
	cd /usr/share/nginx/html/
	wget https://github.com/V2RaySSR/Trojan/raw/master/web.zip
	unzip web.zip
	systemctl restart nginx
	green "=========================================="
	blue "      开始下载安装官方Trojan最新版本"
	green "=========================================="
	sleep 3s
	sudo bash -c "$(wget -O- https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
	systemctl enable trojan
	green "========================================================"
	blue "本次脚本安装完成，现在进行检测"
	green "========================================================"
	read -s -n1 -p "现在开始检测安装情况，请按任意键继续 ... "
	green " "
if test -s /etc/nginx/nginx.conf; then
	green " "
	green " "
	green "==========================="
	 blue "      Nginx安装正常"
	green "==========================="
	sleep 3s
else
	green " "
	green " "
	green "==========================="
	  red "      Nginx安装不成功"
	green "==========================="
	sleep 3s
fi
if test -s /usr/local/etc/trojan/config.json; then
	green " "
	green " "
	green "==========================="
	 blue "      Trojan安装正常"
	green "==========================="
	sleep 3s
else
	green " "
	green " "
	green "==========================="
	  red "     Trojan安装不成功"
	green "==========================="
	sleep 3s
fi
	green " "
	green " "
	green "========================================================"
	 blue " 本过程安装了sudo/nginx/wget/unzip/zip/curl/tar/trojan"
	 blue " 现在你访问 http://$your_domain 应该有伪装站点的存在了"
	 blue " 伪装站点目录在 /usr/share/nginx/html 可自行更换网站"
	 blue " Trojan配置文件在 /usr/local/etc/trojan"
	 blue " 检测没有问题之后可以进行下一部分安装"
	green "========================================================"
else
	green " "
	green " "
	red "================================"
	red "域名解析地址与本VPS IP地址不一致"
	red "本次安装失败，请确保域名解析正常"
	red "================================"
fi
