#!/bin/bash
# onekey suoha
linux_os=("Debian" "Ubuntu" "CentOS" "Fedora" "Alpine")
linux_update=("apt update" "apt update" "yum -y update" "yum -y update" "apk update")
linux_install=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
n=0
for i in `echo ${linux_os[@]}`
do
	if [ $i == $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') ]
	then
		break
	else
		n=$[$n+1]
	fi
done
if [ $n == 5 ]
then
	echo 当前系统$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2)没有适配
	echo 默认使用APT包管理器
	n=0
fi
if [ -z $(type -P unzip) ]
then
	${linux_update[$n]}
	${linux_install[$n]} unzip
fi
if [ -z $(type -P curl) ]
then
	${linux_update[$n]}
	${linux_install[$n]} curl
fi
if [ $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') != "Alpine" ]
then
	if [ -z $(type -P systemctl) ]
	then
		${linux_update[$n]}
		${linux_install[$n]} systemctl
	fi
fi

function quicktunnel(){
# 检查文件是否已经存在，如不存在则下载
if [ ! -d "xray" ] || [ ! -f "cloudflared-linux" ]; then
    rm -rf xray cloudflared-linux xray.zip
    case "$(uname -m)" in
        x86_64 | x64 | amd64 )
        curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip
        curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared-linux
        ;;
        i386 | i686 )
        curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-32.zip -o xray.zip
        curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386 -o cloudflared-linux
        ;;
        armv8 | arm64 | aarch64 )
        echo arm64
        curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip -o xray.zip
        curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o cloudflared-linux
        ;;
        armv7l )
        curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm32-v7a.zip -o xray.zip
        curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -o cloudflared-linux
        ;;
        * )
        echo 当前架构$(uname -m)没有适配
        exit
        ;;
    esac
    mkdir -p xray
    unzip -d xray xray.zip
    chmod +x cloudflared-linux xray/xray
    rm -rf xray.zip
else
    echo "文件已存在，跳过下载和解压步骤"
    chmod +x cloudflared-linux xray/xray
fi

uuid=$(cat /proc/sys/kernel/random/uuid)
urlpath=$(echo $uuid | awk -F- '{print $1}')
port=$[$RANDOM+10000]
if [ $protocol == 1 ]
then
cat>xray/config.json<<EOF
{
	"inbounds": [
		{
			"port": $port,
			"listen": "localhost",
			"protocol": "vmess",
			"settings": {
				"clients": [
					{
						"id": "$uuid",
						"alterId": 0
					}
				]
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": "$urlpath"
				}
			}
		}
	],
	"outbounds": [
		{
			"protocol": "freedom",
			"settings": {}
		}
	]
}
EOF
fi
if [ $protocol == 2 ]
then
cat>xray/config.json<<EOF
{
	"inbounds": [
		{
			"port": $port,
			"listen": "localhost",
			"protocol": "vless",
			"settings": {
				"decryption": "none",
				"clients": [
					{
						"id": "$uuid"
					}
				]
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": "$urlpath"
				}
			}
		}
	],
	"outbounds": [
		{
			"protocol": "freedom",
			"settings": {}
		}
	]
}
EOF
fi
./xray/xray run>/dev/null 2>&1 &
./cloudflared-linux tunnel --url http://localhost:$port --no-autoupdate --edge-ip-version $ips --protocol http2 >argo.log 2>&1 &
sleep 1
n=0
while true
do
n=$[$n+1]
echo 等待cloudflare argo生成地址 已等待 $n 秒
argo=$(cat argo.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
if [ $n == 15 ]
then
	n=0
	if [ $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') == "Alpine" ]
	then
		kill -9 $(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print $1}') >/dev/null 2>&1
	else
		kill -9 $(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print $2}') >/dev/null 2>&1
	fi
	rm -rf argo.log
	echo argo获取超时,重试中
	./cloudflared-linux tunnel --url http://localhost:$port --no-autoupdate --edge-ip-version $ips --protocol http2 >argo.log 2>&1 &
	sleep 1
elif [ -z "$argo" ]
then
	sleep 1
else
	rm -rf argo.log
	break
fi
done
clear
# 从订阅链接获取节点信息并生成v2ray.txt
subscription_url="https://owo.o00o.ooo/sub?uuid=$uuid&encryption=none&security=tls&type=ws&host=$argo&path=$urlpath"
rm -f v2ray.txt

# 只保留包含日本、香港、新加坡、美国的节点
curl -s "$subscription_url" | base64 -d | grep -E '^vless://' | while read -r line; do
    # 提取节点名称
    node_name=$(echo "$line" | awk -F'#' '{print $2}')
    
    # 检查节点名称是否包含指定地区
    if echo "$node_name" | grep -qi -E '(日本|香港|新加坡|美国)'; then
        # 提取IP和端口
        ip_port=$(echo "$line" | awk -F'@' '{print $2}' | awk -F'?' '{print $1}')
        # 生成新链接
        new_line="vless://$uuid@$ip_port?encryption=none&security=tls&type=ws&host=$argo&path=/$urlpath#$node_name"
        echo "$new_line" >> v2ray.txt
    fi
done

# 添加不带TLS的节点，同样只保留指定地区
curl -s "$subscription_url" | base64 -d | grep -E '^vless://' | while read -r line; do
    # 提取节点名称
    node_name=$(echo "$line" | awk -F'#' '{print $2}' | sed 's/_tls$//')
    
    # 检查节点名称是否包含指定地区
    if echo "$node_name" | grep -qi -E '(日本|香港|新加坡|美国)'; then
        # 提取IP和端口
        ip_port=$(echo "$line" | awk -F'@' '{print $2}' | awk -F'?' '{print $1}')
        # 替换端口为80
        ip_port_no_tls=$(echo "$ip_port" | awk -F':' '{print $1}')":80"
        # 生成新链接
        new_line="vless://$uuid@$ip_port_no_tls?encryption=none&security=none&type=ws&host=$argo&path=/$urlpath#$node_name"
        echo "$new_line" >> v2ray.txt
    fi
done

cat v2ray.txt
}

# 设置默认参数
	mode=1
		protocol=2
		ips=4

# 清理历史进程
	if [ $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') == "Alpine" ]
	then
		kill -9 $(ps -ef | grep xray | grep -v grep | awk '{print $1}') >/dev/null 2>&1
		kill -9 $(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print $1}') >/dev/null 2>&1
	else
		kill -9 $(ps -ef | grep xray | grep -v grep | awk '{print $2}') >/dev/null 2>&1
		kill -9 $(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print $2}') >/dev/null 2>&1
	fi

# 清理历史文件
	rm -rf v2ray.txt

# 获取ISP信息
isp=$(curl -$ips -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18"-"$30}' | sed -e 's/ /_/g')

# 执行梭哈模式
	quicktunnel
