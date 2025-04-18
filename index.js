const express = require("express");
const app = express();
const path = require("path");
const exec = require("child_process").exec;
const fs = require("fs");

// 使用express.json中间件解析JSON请求体
app.use(express.json());

// 增加路由以提供HTML页面
app.use(express.static('public'));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// 获取suoha服务状态
app.get('/suoha-status', (req, res) => {
  exec("ps -ef | grep -v grep | grep -E 'xray|cloudflared-linux'", (err, stdout, stderr) => {
    const xrayRunning = stdout.includes("xray");
    const argoRunning = stdout.includes("cloudflared-linux");
    
    res.json({
      xrayRunning,
      argoRunning,
      bothRunning: xrayRunning && argoRunning
    });
  });
});

// 获取服务器信息
app.get('/server-info', (req, res) => {
  exec("cat /etc/os-release && uname -a && curl -s https://speed.cloudflare.com/meta", (err, stdout, stderr) => {
    if (err) {
      res.status(500).json({ error: "获取服务器信息失败" });
    } else {
      res.json({ info: stdout });
    }
  });
});

// 获取v2ray链接信息
app.get('/v2ray-info', (req, res) => {
  if (fs.existsSync('./v2ray.txt')) {
    fs.readFile('./v2ray.txt', 'utf8', (err, data) => {
      if (err) {
        res.status(500).json({ error: "读取v2ray.txt失败" });
      } else {
        res.json({ content: data });
      }
    });
  } else {
    res.json({ content: "未找到v2ray.txt，请先启动服务" });
  }
});

// 启动suoha服务
app.post('/start-suoha', (req, res) => {
  exec("bash suoha.sh", (err, stdout, stderr) => {
    if (err) {
      res.status(500).json({ message: "启动服务失败", error: err });
    } else {
      res.json({ message: "服务启动成功" });
    }
  });
});

// 重启suoha服务
app.post('/restart-suoha', (req, res) => {
  exec("pkill -9 xray && pkill -9 cloudflared-linux && bash suoha.sh", (err, stdout, stderr) => {
    if (err) {
      res.status(500).json({ message: "重启服务失败", error: err });
    } else {
      res.json({ message: "服务重启成功" });
    }
  });
});

// 停止suoha服务
app.post('/stop-suoha', (req, res) => {
  exec("pkill -9 xray && pkill -9 cloudflared-linux", (err, stdout, stderr) => {
    if (err) {
      res.status(500).json({ message: "停止服务失败", error: err });
    } else {
      res.json({ message: "服务停止成功" });
    }
  });
});

// 哪吒相关控制（保留原有代码，但默认不启用）
app.post('/start-nezha', (req, res) => {
  exec("bash nezha.sh", (err, stdout, stderr) => {
    if (err) {
      res.status(500).send({ message: "启动哪吒客户端失败", error: err });
    } else {
      res.send({ message: "哪吒客户端启动成功" });
    }
  });
});

app.post('/restart-nezha', (req, res) => {
  exec("pkill -9 nezha-agent && bash nezha.sh", (err, stdout, stderr) => {
    if (err) {
      res.status(500).send({ message: "重启哪吒客户端失败", error: err });
    } else {
      res.send({ message: "哪吒客户端重启成功" });
    }
  });
});

app.post('/stop-nezha', (req, res) => {
  exec("pkill -9 nezha-agent", (err, stdout, stderr) => {
    if (err) {
      res.status(500).send({ message: "停止哪吒客户端失败", error: err });
    } else {
      res.send({ message: "哪吒客户端停止成功" });
    }
  });
});

// suoha服务保活
function keep_suoha_alive() {
  exec("ps -ef | grep -v grep | grep -E 'xray|cloudflared-linux'", function (err, stdout, stderr) {
    if (err) {
      console.error("Error checking suoha services: ", err);
    } else if (stdout.includes("xray") && stdout.includes("cloudflared-linux")) {
      console.log("梭哈服务正在运行");
    } else {
      console.log("启动梭哈服务...");
      exec("bash suoha.sh", function (err, stdout, stderr) {
        if (err) {
          console.error("启动梭哈服务失败: ", err);
        } else {
          console.log("梭哈服务启动成功");
        }
      });
    }
  });
}

// 设置保活检查的间隔时间，单位为毫秒
setInterval(keep_suoha_alive, 45 * 1000);

// 启动entrypoint.sh脚本
exec("bash entrypoint.sh", function (err, stdout, stderr) {
  if (err) {
    console.error("Error executing entrypoint.sh: ", err);
  } else {
    console.log("entrypoint.sh executed successfully: ", stdout);
  }
});

// 启动express服务器
const port = process.env.PORT || 443;
app.listen(port, () => {
  console.log(`Server listening on port ${port}!`);
});
