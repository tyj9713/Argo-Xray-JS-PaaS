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
  echo "正在生成suoha.sh脚本..."
  cat > suoha.sh << 'EOF'
#!/bin/bash
# onekey suoha
# 设置更详细的调试输出
set -x

# 检查并安装必要的软件
echo "检查必要软件..."
if ! command -v unzip &> /dev/null; then
    echo "安装 unzip..."
    apt-get update && apt-get install -y unzip curl
fi

if ! command -v curl &> /dev/null; then
    echo "安装 curl..."
    apt-get update && apt-get install -y curl
fi

function quicktunnel(){
# 清理旧文件
echo "清理旧文件..."
rm -rf xray cloudflared-linux xray.zip
pkill -9 xray || true
pkill -9 cloudflared-linux || true

# 下载相应的软件包
echo "检测系统架构..."
ARCH=$(uname -m)
echo "系统架构: $ARCH"

case "$ARCH" in
    x86_64 | x64 | amd64 )
    echo "下载 x86_64 版本软件包..."
    curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared-linux
    ;;
    i386 | i686 )
    echo "下载 i386 版本软件包..."
    curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-32.zip -o xray.zip
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386 -o cloudflared-linux
    ;;
    armv8 | arm64 | aarch64 )
    echo "下载 arm64 版本软件包..."
    curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip -o xray.zip
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o cloudflared-linux
    ;;
    armv7l )
    echo "下载 armv7l 版本软件包..."
    curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm32-v7a.zip -o xray.zip
    curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -o cloudflared-linux
    ;;
    * )
    echo "当前架构 $ARCH 没有适配"
    exit 1
    ;;
esac

# 检查下载是否成功
if [ ! -f "xray.zip" ] || [ ! -f "cloudflared-linux" ]; then
    echo "下载失败，请检查网络连接"
    exit 1
fi

# 解压
echo "解压Xray..."
mkdir -p xray
unzip -o xray.zip -d xray
chmod +x cloudflared-linux xray/xray
rm -rf xray.zip

# 检查文件是否存在
if [ ! -f "xray/xray" ] || [ ! -f "cloudflared-linux" ]; then
    echo "解压后文件丢失，请重试"
    exit 1
fi

# 配置信息
echo "生成配置..."
uuid=$(cat /proc/sys/kernel/random/uuid)
urlpath=$(echo $uuid | awk -F- '{print $1}')
port=$((RANDOM+10000))
protocol=2  # 使用vless
ips=4       # 使用IPv4

# 生成xray配置
echo "创建Xray配置文件..."
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

# 启动服务
echo "启动Xray和Cloudflared服务..."
./xray/xray run -config xray/config.json > xray.log 2>&1 &
./cloudflared-linux tunnel --url http://localhost:$port --no-autoupdate --edge-ip-version $ips --protocol http2 > argo.log 2>&1 &

# 等待服务启动
echo "等待服务启动..."
sleep 3

# 检查进程是否启动
echo "检查进程启动状态..."
ps -ef | grep xray
ps -ef | grep cloudflared-linux

echo "等待Argo隧道地址生成..."
n=0
while true
do
    n=$((n+1))
    echo "等待cloudflare argo生成地址 已等待 $n 秒"
    
    # 检查Argo日志
    if [ -f "argo.log" ]; then
        echo "Argo日志内容:"
        cat argo.log
    else
        echo "Argo日志文件不存在"
    fi
    
    if [ -f "argo.log" ]; then
        argo=$(grep -o "https://.*\.trycloudflare\.com" argo.log | awk 'NR==1{print}' | awk -F/ '{print $3}')
        if [ -n "$argo" ]; then
            echo "成功获取Argo地址: $argo"
            break
        fi
    fi
    
    if [ $n -ge 15 ]; then
        echo "15秒超时，重启Cloudflared..."
        pkill -9 cloudflared-linux || true
        rm -f argo.log
        ./cloudflared-linux tunnel --url http://localhost:$port --no-autoupdate --edge-ip-version $ips --protocol http2 > argo.log 2>&1 &
        n=0
    fi
    
    sleep 1
done

# 获取ISP信息
echo "获取ISP信息..."
isp=$(curl -s https://speed.cloudflare.com/meta | grep -o '"country":"[^"]*","city":"[^"]*","asOrganization":"[^"]*"' | sed 's/"country":"//;s/","city":"/-/;s/","asOrganization":"/-/;s/"//g' | sed 's/ /_/g')
echo "ISP信息: $isp"

# 生成vless链接
echo "生成V2Ray链接..."
echo -e "vless链接已经生成, speed.cloudflare.com 可替换为CF优选IP\n" > v2ray.txt
echo "vless://${uuid}@speed.cloudflare.com:443?encryption=none&security=tls&type=ws&host=${argo}&path=${urlpath}#${isp//,/%2C}_tls" >> v2ray.txt
echo -e "\n端口 443 可改为 2053 2083 2087 2096 8443\n" >> v2ray.txt
echo "vless://${uuid}@speed.cloudflare.com:80?encryption=none&security=none&type=ws&host=${argo}&path=${urlpath}#${isp//,/%2C}" >> v2ray.txt
echo -e "\n端口 80 可改为 8080 8880 2052 2082 2086 2095" >> v2ray.txt

# 显示结果
echo "服务启动完成，以下是V2Ray链接信息:"
cat v2ray.txt
echo -e "\n信息已经保存在 v2ray.txt,再次查看请运行 cat v2ray.txt"
echo "当前进程状态:"
ps -ef | grep -v grep | grep -E 'xray|cloudflared-linux'
}

# 执行梭哈模式
echo "开始执行梭哈模式..."
quicktunnel
EOF

  # 确保脚本有执行权限
  chmod +x suoha.sh
  echo "suoha.sh脚本生成并设置执行权限完成"
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

# 生成所有脚本
echo "开始生成脚本..."
generate_suoha
generate_nezha
generate_npc

echo "准备运行suoha.sh..."
ls -la suoha.sh
# 默认运行suoha.sh而不是nezha和npc
if [ -e suoha.sh ]; then
  echo "执行suoha.sh脚本..."
  chmod +x suoha.sh
  bash suoha.sh > suoha.log 2>&1 &
  echo "suoha.sh已在后台启动，查看日志: cat suoha.log"
else
  echo "suoha.sh文件不存在，创建失败"
fi

# [ -e npc.sh ] && bash npc.sh
# [ -e nezha.sh ] && bash nezha.sh
