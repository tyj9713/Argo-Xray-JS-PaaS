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
mkdir xray
unzip -d xray xray.zip
chmod +x cloudflared-linux xray/xray
rm -rf xray.zip
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
if [ $protocol == 1 ]
then
	echo -e vmess链接已经生成, speed.cloudflare.com 可替换为CF优选IP'\n' > v2ray.txt
	if [ $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') == "Alpine" ]
	then
		echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$urlpath'","port":"443","ps":"'$(echo $isp | sed -e 's/_/ /g')'_tls","tls":"tls","type":"none","v":"2"}' | base64 | awk '{ORS=(NR%76==0?RS:"");}1') >> v2ray.txt
	else
		echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$urlpath'","port":"443","ps":"'$(echo $isp | sed -e 's/_/ /g')'_tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0) >> v2ray.txt
	fi
	echo -e '\n'端口 443 可改为 2053 2083 2087 2096 8443'\n' >> v2ray.txt
	if [ $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') == "Alpine" ]
	then
		echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$urlpath'","port":"80","ps":"'$(echo $isp | sed -e 's/_/ /g')'","tls":"","type":"none","v":"2"}' | base64 | awk '{ORS=(NR%76==0?RS:"");}1') >> v2ray.txt
	else
		echo 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$urlpath'","port":"80","ps":"'$(echo $isp | sed -e 's/_/ /g')'","tls":"","type":"none","v":"2"}' | base64 -w 0) >> v2ray.txt
	fi
	echo -e '\n'端口 80 可改为 8080 8880 2052 2082 2086 2095 >> v2ray.txt
fi
if [ $protocol == 2 ]
then
	echo -e vless链接已经生成, speed.cloudflare.com 可替换为CF优选IP'\n' > v2ray.txt
	echo 'vless://'$uuid'@speed.cloudflare.com:443?encryption=none&security=tls&type=ws&host='$argo'&path='$urlpath'#'$(echo $isp | sed -e 's/_/%20/g' -e 's/,/%2C/g')'_tls' >> v2ray.txt
	echo -e '\n'端口 443 可改为 2053 2083 2087 2096 8443'\n' >> v2ray.txt
	echo 'vless://'$uuid'@speed.cloudflare.com:80?encryption=none&security=none&type=ws&host='$argo'&path='$urlpath'#'$(echo $isp | sed -e 's/_/%20/g' -e 's/,/%2C/g')'' >> v2ray.txt
	echo -e '\n'端口 80 可改为 8080 8880 2052 2082 2086 2095 >> v2ray.txt
fi
rm -rf argo.log
cat v2ray.txt
echo -e '\n'信息已经保存在 v2ray.txt,再次查看请运行 cat v2ray.txt
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
	rm -rf xray cloudflared-linux v2ray.txt

# 获取ISP信息
isp=$(curl -$ips -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18"-"$30}' | sed -e 's/ /_/g')

# 执行梭哈模式
	quicktunnel
