#!/usr/bin/env bash

# 哪吒的4个参数
NEZHA_SERVER="ip-tz.971314.xyz"
NEZHA_PORT="15555"
NEZHA_KEY="7JQFyDBT8XEc6krnqb"
#NEZHA_TLS=""
# nps客户端的3个参数
NPC_SERVER="nps.971314.xyz:8025"
NPC_VKEY="pribxlhr4wh4z5e0"
# NPC_TYPE="tcp"

# 生成suoha.sh脚本
generate_suoha() {
  cat > suoha.sh << EOF
#!/bin/bash
# onekey suoha
linux_os=("Debian" "Ubuntu" "CentOS" "Fedora" "Alpine")
linux_update=("apt update" "apt update" "yum -y update" "yum -y update" "apk update")
linux_install=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
n=0
for i in \`echo \${linux_os[@]}\`
do
	if [ \$i == \$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print \$1}') ]
	then
		break
	else
		n=\$[\$n+1]
	fi
done
if [ \$n == 5 ]
then
	echo 当前系统\$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2)没有适配
	echo 默认使用APT包管理器
	n=0
fi
if [ -z \$(type -P unzip) ]
then
	\${linux_update[\$n]}
	\${linux_install[\$n]} unzip
fi
if [ -z \$(type -P curl) ]
then
	\${linux_update[\$n]}
	\${linux_install[\$n]} curl
fi
if [ \$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print \$1}') != "Alpine" ]
then
	if [ -z \$(type -P systemctl) ]
	then
		\${linux_update[\$n]}
		\${linux_install[\$n]} systemctl
	fi
fi


function quicktunnel(){
rm -rf xray cloudflared-linux xray.zip
case "\$(uname -m)" in
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
	echo 当前架构\$(uname -m)没有适配
	exit
	;;
esac
mkdir xray
unzip -d xray xray.zip
chmod +x cloudflared-linux xray/xray
rm -rf xray.zip
uuid=\$(cat /proc/sys/kernel/random/uuid)
urlpath=\$(echo \$uuid | awk -F- '{print \$1}')
port=\$[\$RANDOM+10000]
if [ \$protocol == 1 ]
then
cat>xray/config.json<<EOF
{
	"inbounds": [
		{
			"port": \$port,
			"listen": "localhost",
			"protocol": "vmess",
			"settings": {
				"clients": [
					{
						"id": "\$uuid",
						"alterId": 0
					}
				]
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": "\$urlpath"
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
if [ \$protocol == 2 ]
then
cat>xray/config.json<<EOF
{
	"inbounds": [
		{
			"port": \$port,
			"listen": "localhost",
			"protocol": "vless",
			"settings": {
				"decryption": "none",
				"clients": [
					{
						"id": "\$uuid"
					}
				]
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": "\$urlpath"
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
./cloudflared-linux tunnel --url http://localhost:\$port --no-autoupdate --edge-ip-version \$ips --protocol http2 >argo.log 2>&1 &
sleep 1
n=0
while true
do
n=\$[\$n+1]
echo 等待cloudflare argo生成地址 已等待 \$n 秒
argo=\$(cat argo.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print \$2}' | awk '{print \$1}')
if [ \$n == 15 ]
then
	n=0
	if [ \$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print \$1}') == "Alpine" ]
	then
		kill -9 \$(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print \$1}') >/dev/null 2>&1
	else
		kill -9 \$(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print \$2}') >/dev/null 2>&1
	fi
	rm -rf argo.log
	echo argo获取超时,重试中
	./cloudflared-linux tunnel --url http://localhost:\$port --no-autoupdate --edge-ip-version \$ips --protocol http2 >argo.log 2>&1 &
	sleep 1
elif [ -z "\$argo" ]
then
	sleep 1
else
	rm -rf argo.log
	break
fi
done
clear
if [ \$protocol == 1 ]
then
	echo -e vmess链接已经生成, speed.cloudflare.com 可替换为CF优选IP'\\n' > v2ray.txt
	if [ \$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print \$1}') == "Alpine" ]
	then
		echo 'vmess://'\$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'\$argo'","id":"'\$uuid'","net":"ws","path":"'\$urlpath'","port":"443","ps":"'\$(echo \$isp | sed -e 's/_/ /g')'_tls","tls":"tls","type":"none","v":"2"}' | base64 | awk '{ORS=(NR%76==0?RS:"");}1') >> v2ray.txt
	else
		echo 'vmess://'\$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'\$argo'","id":"'\$uuid'","net":"ws","path":"'\$urlpath'","port":"443","ps":"'\$(echo \$isp | sed -e 's/_/ /g')'_tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0) >> v2ray.txt
	fi
	echo -e '\\n'端口 443 可改为 2053 2083 2087 2096 8443'\\n' >> v2ray.txt
	if [ \$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print \$1}') == "Alpine" ]
	then
		echo 'vmess://'\$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'\$argo'","id":"'\$uuid'","net":"ws","path":"'\$urlpath'","port":"80","ps":"'\$(echo \$isp | sed -e 's/_/ /g')'","tls":"","type":"none","v":"2"}' | base64 | awk '{ORS=(NR%76==0?RS:"");}1') >> v2ray.txt
	else
		echo 'vmess://'\$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'\$argo'","id":"'\$uuid'","net":"ws","path":"'\$urlpath'","port":"80","ps":"'\$(echo \$isp | sed -e 's/_/ /g')'","tls":"","type":"none","v":"2"}' | base64 -w 0) >> v2ray.txt
	fi
	echo -e '\\n'端口 80 可改为 8080 8880 2052 2082 2086 2095 >> v2ray.txt
fi
if [ \$protocol == 2 ]
then
	echo -e vless链接已经生成, speed.cloudflare.com 可替换为CF优选IP'\\n' > v2ray.txt
	echo 'vless://'\$uuid'@speed.cloudflare.com:443?encryption=none&security=tls&type=ws&host='\$argo'&path='\$urlpath'#'\$(echo \$isp | sed -e 's/_/%20/g' -e 's/,/%2C/g')'_tls' >> v2ray.txt
	echo -e '\\n'端口 443 可改为 2053 2083 2087 2096 8443'\\n' >> v2ray.txt
	echo 'vless://'\$uuid'@speed.cloudflare.com:80?encryption=none&security=none&type=ws&host='\$argo'&path='\$urlpath'#'\$(echo \$isp | sed -e 's/_/%20/g' -e 's/,/%2C/g')'' >> v2ray.txt
	echo -e '\\n'端口 80 可改为 8080 8880 2052 2082 2086 2095 >> v2ray.txt
fi
rm -rf argo.log
cat v2ray.txt
echo -e '\\n'信息已经保存在 v2ray.txt,再次查看请运行 cat v2ray.txt
}

# 设置默认参数
mode=1
protocol=2
ips=4

# 清理历史进程
if [ \$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print \$1}') == "Alpine" ]
then
	kill -9 \$(ps -ef | grep xray | grep -v grep | awk '{print \$1}') >/dev/null 2>&1
	kill -9 \$(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print \$1}') >/dev/null 2>&1
else
	kill -9 \$(ps -ef | grep xray | grep -v grep | awk '{print \$2}') >/dev/null 2>&1
	kill -9 \$(ps -ef | grep cloudflared-linux | grep -v grep | awk '{print \$2}') >/dev/null 2>&1
fi

# 清理历史文件
rm -rf xray cloudflared-linux v2ray.txt

# 获取ISP信息
isp=\$(curl -\$ips -s https://speed.cloudflare.com/meta | awk -F\" '{print \$26"-"\$18"-"\$30}' | sed -e 's/ /_/g')

# 执行梭哈模式
quicktunnel
EOF
}

generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 哪吒的4个参数
NEZHA_SERVER="$NEZHA_SERVER"
NEZHA_PORT="$NEZHA_PORT"
NEZHA_KEY="$NEZHA_KEY"
NEZHA_TLS="$NEZHA_TLS"

# 检测是否已运行
check_run() {
  [[ \$(pgrep -laf nezha-agent) ]] && echo "哪吒客户端正在运行中!" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/nezhahq/agent/releases/latest"  | grep -o "https.*linux_amd64.zip")
    URL=\${URL:-https://github.com/nezhahq/agent/releases/download/v0.15.6/nezha-agent_linux_amd64.zip} 
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

# 运行客户端
run() {
  TLS=\${NEZHA_TLS:+'--tls'}
  [[ ! \$PROCESS =~ nezha-agent && -e nezha-agent ]] && ./nezha-agent -s \${NEZHA_SERVER}:\${NEZHA_PORT} -p \${NEZHA_KEY} \${TLS} 2>&1 &
}

check_run
check_variable
download_agent
run
EOF
}

generate_npc() {
  cat > npc.sh << EOF
#!/usr/bin/env bash

# nps客户端的3个参数
NPC_SERVER="$NPC_SERVER"
NPC_VKEY="$NPC_VKEY"
# NPC_TYPE="$NPC_TYPE"

# 检测是否已运行
check_run() {
  [[ \$(pgrep -laf npc) ]] && echo "nps客户端正在运行中!" && exit
}

# 下载nps客户端
download_npc() {
  if [ ! -e npc ]; then
    wget -t 2 -T 10 -N "https://github.com/ehang-io/nps/releases/download/v0.26.8/linux_amd64_client.tar.gz"
    tar -xzvf ./linux_amd64_client.tar.gz && rm -f linux_amd64_client.tar.gz
  fi
}

# 安装并启动nps客户端
run() {
  [[ ! \$PROCESS =~ npc && -e npc ]] && ./npc -server=\${NPC_SERVER} -vkey=\${NPC_VKEY} -type=tcp
}

check_run
download_npc
run
EOF
}

generate_suoha
generate_nezha
generate_npc

# 默认运行suoha.sh而不是nezha和npc
[ -e suoha.sh ] && bash suoha.sh
# [ -e npc.sh ] && bash npc.sh
# [ -e nezha.sh ] && bash nezha.sh
