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

generate_nezha
generate_npc

[ -e npc.sh ] && bash npc.sh
[ -e nezha.sh ] && bash nezha.sh
