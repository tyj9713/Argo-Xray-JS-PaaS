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
# 从订阅链接获取节点信息并生成v2ray.txt
subscription_url="https://owo.o00o.ooo/sub?uuid=$uuid&encryption=none&security=tls&type=ws&host=$argo&path=$urlpath"
curl -s "$subscription_url" | base64 -d | grep -E '^vless://' | while read -r line; do
    # 提取IP和端口
    ip_port=$(echo "$line" | awk -F'@' '{print $2}' | awk -F'?' '{print $1}')
    # 提取节点名称
    node_name=$(echo "$line" | awk -F'#' '{print $2}')
    # 生成新链接
    new_line="vless://$uuid@$ip_port?encryption=none&security=tls&type=ws&host=$argo&path=/$urlpath#$node_name"
    echo "$new_line" >> v2ray.txt
done

# 添加不带TLS的节点
curl -s "$subscription_url" | base64 -d | grep -E '^vless://' | while read -r line; do
    # 提取IP和端口
    ip_port=$(echo "$line" | awk -F'@' '{print $2}' | awk -F'?' '{print $1}')
    # 替换端口为80
    ip_port_no_tls=$(echo "$ip_port" | awk -F':' '{print $1}')":80"
    # 提取节点名称并去掉"_tls"后缀
    node_name=$(echo "$line" | awk -F'#' '{print $2}' | sed 's/_tls$//')
    # 生成新链接
    new_line="vless://$uuid@$ip_port_no_tls?encryption=none&security=none&type=ws&host=$argo&path=/$urlpath#$node_name"
    echo "$new_line" >> v2ray.txt
done

cat v2ray.txt
}
