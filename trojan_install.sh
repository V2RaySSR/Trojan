#!/bin/bash
＃字体颜色
blue() {
    echo -e "\033[34m\033[01m$1\033[0m"
}
green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}
red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif grep -Eqi "debian" </etc/issue; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif grep -Eqi "ubuntu" </etc/issue; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif grep -Eqi "centos|red hat|redhat" </etc/issue; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif grep -Eqi "debian" </proc/version; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif grep -Eqi "ubuntu" </proc/version; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif grep -Eqi "centos|red hat|redhat" </proc/version; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
fi

function get_email() {
    green "======================="
    blue "acme 申请 email"
    green "======================="

    read your_email
}
function get_domain(){
    green "======================="
    blue "请输入绑定到本VPS的域名"
    green "======================="

    read your_domain
}
function test_ports(){

    # This command uses netstat to get a list of all TCP connections and filters out the ones that are listening (-l) and using the TCP protocol (-t). It then uses awk to split the output by colon and space characters and prints the fifth field, which is the port number. Finally, it filters the output to only show port 80.
    Port80=$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80)
    Port443=$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443)

    if [ -n "$Port80" ]; then
        process80=$(netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}')

        red "==========================================================="
        red "检测到80端口被占用, 占用进程为: ${process80}, 本次安装结束"
        red "==========================================================="

        exit 1
    fi

    if [ -n "$Port443" ]; then
        process443=$(netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}')

        red "============================================================="
        red "检测到443端口被占用, 占用进程为: ${process443}, 本次安装结束"
        red "============================================================="

        exit 1
    fi

}
function check_selinux(){
    # This line of code checks if SELinux is enabled by searching for the SELINUX= line in the /etc/selinux/config file and excluding any commented out lines.
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")

    if [ "$CHECK" == "SELINUX=enforcing" ]; then

        red "======================================================================="
        red "检测到SELinux为开启状态, 为防止申请证书失败, 请先重启VPS后, 再执行本脚本"
        red "======================================================================="

        # Prompts the user to confirm if they want to restart and waits for their input.
        read -p "是否现在重启 ?请输入 [Y/n] :" yn

        [ -z "${yn}" ] && yn="y"

        if [[ $yn == [Yy] ]]; then
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0

            echo -e "VPS 重启中..."

            reboot
        fi

        exit

    fi

    if [ "$CHECK" == "SELINUX=permissive" ]; then

        red "======================================================================="
        red "检测到SELinux为宽容状态, 为防止申请证书失败, 请先重启VPS后, 再执行本脚本"
        red "======================================================================="

        read -p "是否现在重启 ?请输入 [Y/n] :" yn

        [ -z "${yn}" ] && yn="y"

        if [[ $yn == [Yy] ]]; then
            sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0

            echo -e "VPS 重启中..."

            reboot
        fi

        exit
    fi
}

function check_system_support(){
    if [ "$release" == "centos" ]; then
        if grep -q ' 6\.' /etc/redhat-release; then

            red "==============="
            red "当前系统不受支持"
            red "==============="

            exit
        fi

        if grep -q ' 5\.' /etc/redhat-release; then

            red "==============="
            red "当前系统不受支持"
            red "==============="

            exit
        fi

        systemctl stop firewalld
        systemctl disable firewalld
        rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
    elif [ "$release" == "ubuntu" ]; then
        if grep -q ' 14\.' /etc/os-release; then
            red "==============="
            red "当前系统不受支持"
            red "==============="
            exit
        fi

        if grep -q ' 12\.' /etc/os-release; then
            red "==============="
            red "当前系统不受支持"
            red "==============="
            exit
        fi

        systemctl stop ufw
        systemctl disable ufw
        apt-get update

    elif [ "$release" == "debian" ]; then
        apt-get update
    fi
}
function gen_nginx_conf(){
    cat >/etc/nginx/nginx.conf <<-EOF
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
}

function gen_trojan_conf_mac(){
    #配置trojan mac
    cat >/usr/src/trojan-macos/trojan/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": 443,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}

EOF
}
function gen_trojan_conf_win(){
    # 配置trojan-cli 客户端
    cat >/usr/src/trojan-cli/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": 443,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.cer",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
}
function gen_trojan_conf_server(){
    # 配置trojan 服务端
    rm -rf /usr/src/trojan/server.conf
    cat >/usr/src/trojan/server.conf <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/usr/src/trojan-cert/fullchain.cer",
        "key": "/usr/src/trojan-cert/private.key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

}

function gen_clash_conf(){
    # clash yaml 配置文件
    cat >"/usr/src/trojan-cli/clash-global-config-${your_domain}.yaml" <<-EOF
# HTTP 端口
port: 7890

# SOCKS5 端口
socks-port: 7891

allow-lan: false

# Rule / Global / Direct (默认为 Rule 模式)
mode: Global

# 设置输出日志的等级 (默认为 info)
# info / warning / error / debug / silent
log-level: info

# RESTful API for clash
external-controller: 127.0.0.1:9090

# 实验性功能
experimental:
  ignore-resolve-fail: true # 忽略 DNS 解析失败, 默认值为true
  # interface-name: en0 # 出站接口名称

# # 实验性 hosts, 支持通配符(如 *.clash.dev 甚至 *.foo.*.examplex.com )
# # 静态域的优先级高于通配符域(foo.example.com > *.example.com)
hosts:
  "mtalk.google.com": 108.177.125.188
#   '*.clash.dev': 127.0.0.1
#   'alpha.clash.dev': '::1'

proxies:
  # Trojan
  - name: "trojan"
    type: trojan
    server: $real_addr
    port: 443
    password: $trojan_passwd
    # udp: true
    sni: $your_domain # 填写伪装域名
    alpn:
      - h2
      - http/1.1
    # skip-cert-verify: true

# Clash for Windows
cfw-bypass:
  - qq.com
  - music.163.com
  - "*.music.126.net"
  - localhost
  - 127.*
  - 10.*
  - 172.16.*
  - 172.17.*
  - 172.18.*
  - 172.19.*
  - 172.20.*
  - 172.21.*
  - 172.22.*
  - 172.23.*
  - 172.24.*
  - 172.25.*
  - 172.26.*
  - 172.27.*
  - 172.28.*
  - 172.29.*
  - 172.30.*
  - 172.31.*
  - 192.168.*
  - <local>
cfw-latency-timeout: 5000

EOF
}
function add_trojan_startup_service(){
    #增加启动脚本
    cat >"${systempwd}"trojan.service <<-EOF
[Unit]  
Description=trojan  
After=network.target  
   
[Service]  
Type=simple  
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"  
ExecReload=  
ExecStop=/usr/src/trojan/trojan  
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target

EOF
}
function install_trojan() {
    # 防火墙放通这两个端口
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    get_email    

    # Stop the nginx service
    systemctl stop nginx

    # Installs net-tools and socat packages using the system package manager.
    $systemPackage -y install net-tools socat

    # This script installs the acme.sh client by downloading it from the internet and running it with the provided email address as a parameter.
    curl https://get.acme.sh | sh -s email="$your_email"

    test_ports

    check_selinux

    check_system_support

    $systemPackage -y install nginx wget unzip zip curl tar >/dev/null 2>&1
    systemctl enable nginx
    systemctl stop nginx

    get_domain

    real_addr=$(ping "${your_domain}" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
    local_addr=$(curl ipv4.icanhazip.com)

    if [ "$real_addr" == "$local_addr" ]; then

        green "=========================================="
        green "       域名解析正常, 开始安装trojan"
        green "=========================================="

        sleep 1s
        
        gen_nginx_conf

        #设置伪装站
        rm -rf /usr/share/nginx/html/*

        cd /usr/share/nginx/html/ || exit
        wget https://github.com/HEI201/Trojan-fork/raw/master/web.zip
        unzip web.zip

        systemctl stop nginx

        sleep 5

        #申请https证书
        mkdir /usr/src/trojan-cert /usr/src/trojan-temp

        curl https://get.acme.sh | sh

        ~/.acme.sh/acme.sh --issue -d "$your_domain" --standalone

        ~/.acme.sh/acme.sh --installcert -d "$your_domain" \
            --key-file /usr/src/trojan-cert/private.key \
            --fullchain-file /usr/src/trojan-cert/fullchain.cer

        if test -s /usr/src/trojan-cert/fullchain.cer; then
            systemctl start nginx
            cd /usr/src || exit

            # 下载 Trojan Linux 客户端
            wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest
            latest_version=$(grep tag_name latest | awk -F '[:,"v]' '{print $6}')

            wget https://github.com/trojan-gfw/trojan/releases/download/v"${latest_version}"/trojan-"${latest_version}"-linux-amd64.tar.xz

            # 解压 Trojan Linux 客户端
            tar xf trojan-"${latest_version}"-linux-amd64.tar.xz

            #下载trojan WIN客户端
            wget https://github.com/atrandys/trojan/raw/master/trojan-cli.zip

            wget -P /usr/src/trojan-temp https://github.com/trojan-gfw/trojan/releases/download/v"${latest_version}"/trojan-"${latest_version}"-win.zip

            # 解压 Trojan WIN 客户端
            unzip trojan-cli.zip
            unzip /usr/src/trojan-temp/trojan-"${latest_version}"-win.zip -d /usr/src/trojan-temp/

            cp /usr/src/trojan-cert/fullchain.cer /usr/src/trojan-cli/fullchain.cer
            mv -f /usr/src/trojan-temp/trojan/trojan.exe /usr/src/trojan-cli/

            #下载trojan MAC客户端
            wget -P /usr/src/trojan-macos https://github.com/trojan-gfw/trojan/releases/download/v"${latest_version}"/trojan-"${latest_version}"-macos.zip

            # 解压 Trojan MAC 客户端
            unzip /usr/src/trojan-macos/trojan-"${latest_version}"-macos.zip -d /usr/src/trojan-macos/

            rm -rf /usr/src/trojan-macos/trojan-"${latest_version}"-macos.zip
            trojan_passwd=$(head -1 </dev/urandom | md5sum | head -c 8)

            gen_trojan_conf_mac

            gen_trojan_conf_win

            gen_trojan_conf_server

            gen_clash_conf
                
            #打包WIN客户端
            cd /usr/src/trojan-cli/ || exit
            
            zip -q -r "trojan-cli-${your_domain}.zip" .
            
            trojan_path=$(head -1 </dev/urandom | md5sum | head -c 16)
            
            mkdir /usr/share/nginx/html/"${trojan_path}"
            
            mv "/usr/src/trojan-cli/trojan-cli-${your_domain}.zip" /usr/share/nginx/html/"${trojan_path}"/
            
            #打包MAC客户端
            cd /usr/src/trojan-macos/ || exit
            
            zip -q -r "trojan-mac-${your_domain}.zip" /usr/src/trojan-macos/
            
            mv "/usr/src/trojan-macos/trojan-mac-${your_domain}.zip" /usr/share/nginx/html/"${trojan_path}"/

            add_trojan_startup_service

            chmod +x "${systempwd}"trojan.service
            systemctl start trojan.service
            systemctl enable trojan.service
            
            green "======================================================================"
            
            green "Trojan已安装完成, 请使用以下链接下载trojan客户端, 此客户端已配置好所有参数"
            green "1、复制下面的链接, 在浏览器打开, 下载客户端"
            
            blue "Windows客户端下载:http://${your_domain}/$trojan_path/trojan-cli-${your_domain}.zip"
            blue "sftp: get /usr/share/nginx/html/$trojan_path/trojan-cli-${your_domain}.zip"
            blue "MacOS客户端下载:http://${your_domain}/$trojan_path/trojan-mac-${your_domain}.zip"
            
            green "2、Windows将下载的客户端解压, 打开文件夹, 打开start.bat即打开并运行Trojan客户端"
            green "3、MacOS将下载的客户端解压, 打开文件夹, 打开start.command即打开并运行Trojan客户端"
            
            green "Trojan推荐使用 Mellow 工具代理(WIN/MAC通用)下载地址如下:"
            green "https://github.com/mellow-io/mellow/releases  (exe为Win客户端,dmg为Mac客户端)"
            
            green "======================================================================"
        else
            red "==================================="
            red "https证书没有申请成果, 自动安装失败"
            green "不要担心, 你可以手动修复证书申请"
            green "1. 重启VPS"
            green "2. 重新执行脚本, 使用修复证书功能"
            red "==================================="
        fi

    else
        red "================================"
        red "域名解析地址与本VPS IP地址不一致"
        red "本次安装失败, 请确保域名解析正常"
        red "================================"
    fi
}

function repair_cert() {
    
    systemctl stop nginx
    
    Port80=$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80)
    
    if [ -n "$Port80" ]; then
    
        process80=$(netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}')
    
        red "==========================================================="
        red "检测到80端口被占用, 占用进程为:${process80}, 本次安装结束"
        red "==========================================================="
    
        exit 1
    fi
    
    green "======================="
    blue "请输入绑定到本VPS的域名"
    blue "务必与之前失败使用的域名一致"
    green "======================="
    
    read your_domain
    
    real_addr=$(ping "${your_domain}" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
    local_addr=$(curl ipv4.icanhazip.com)
    
    if [ "$real_addr" == "$local_addr" ]; then
    
        ~/.acme.sh/acme.sh --issue -d "$your_domain" --standalone
    
        ~/.acme.sh/acme.sh --installcert -d "$your_domain" \
            --key-file /usr/src/trojan-cert/private.key \
            --fullchain-file /usr/src/trojan-cert/fullchain.cer
    
        if test -s /usr/src/trojan-cert/fullchain.cer; then
    
            green "证书申请成功"
            green "请将/usr/src/trojan-cert/下的fullchain.cer下载放到客户端trojan-cli-${your_domain}文件夹"
    
            systemctl restart trojan
            systemctl start nginx
    
        else
            red "申请证书失败"
        fi
    else
        red "================================"
        red "域名解析地址与本VPS IP地址不一致"
        red "本次安装失败, 请确保域名解析正常"
        red "================================"
    fi
}

function remove_trojan() {
    
    red "================================"
    red "即将卸载trojan"
    red "同时卸载安装的nginx"
    red "================================"
    
    systemctl stop trojan
    systemctl disable trojan
    
    rm -f "${systempwd}"trojan.service
    
    if [ "$release" == "centos" ]; then
        yum remove -y nginx
    else
        apt autoremove -y nginx
    fi
    
    rm -rf /usr/src/trojan*
    rm -rf /usr/share/nginx/html/*
    
    green "=============="
    green "trojan删除完毕"
    green "=============="
}

function bbr_boost_sh() {
    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

start_menu() {
    
    clear
    
    green " ===================================="
    green " Trojan 一键安装自动脚本 2020-2-27 更新      "
    green " 系统:centos7+/debian9+/ubuntu16.04+"
    green " 网站:www.v2rayssr.com (已开启禁止国内访问)"
    green " 此脚本为 atrandys 的, 波仔集成BBRPLUS加速及MAC客户端 "
    green " Youtube:波仔分享                "
    green " ===================================="
    
    blue " 声明:"
    red " *请不要在任何生产环境使用此脚本"
    red " *请不要有其他程序占用80和443端口"
    red " *若是第二次使用脚本, 请先执行卸载trojan"
    green " ======================================="
    
    echo
    
    green " 1. 安装trojan"
    red " 2. 卸载trojan"
    green " 3. 修复证书"
    green " 4. 安装BBR-PLUS加速4合一脚本"
    blue " 0. 退出脚本"
    
    echo
    
    read -p "请输入数字:" num
    
    case "$num" in
    1)
        install_trojan
        ;;
    2)
        remove_trojan
        ;;
    3)
        repair_cert
        ;;
    4)
        bbr_boost_sh
        ;;
    0)
        exit 1
        ;;
    *)
        clear
    
        red "请输入正确数字"
    
        sleep 1s
    
        start_menu
        ;;
    esac
}

start_menu
