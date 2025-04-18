const express = require("express");
const app = express();
const path = require("path");
const exec = require("child_process").exec;
const { execSync } = require("child_process");
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
    console.log("服务状态检查结果:", stdout);
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
  console.log("开始启动suoha服务...");
  try {
    // 先确保相关进程已停止
    try {
      execSync("pkill -9 xray || true");
      execSync("pkill -9 cloudflared-linux || true");
      console.log("已清理可能存在的旧进程");
    } catch (cleanupErr) {
      console.log("清理旧进程时出现非致命错误:", cleanupErr.message);
    }
    
    // 确保suoha.sh可执行
    execSync("chmod +x suoha.sh");
    console.log("已设置suoha.sh为可执行");
    
    // 执行脚本并等待结果
    const stdout = execSync("bash suoha.sh 2>&1", { timeout: 60000 });
    console.log("suoha服务启动输出:", stdout.toString());
    
    // 检查进程是否在运行
    const processCheck = execSync("ps -ef | grep -v grep | grep -E 'xray|cloudflared-linux'").toString();
    console.log("进程检查结果:", processCheck);
    
    res.json({ 
      message: "服务启动成功", 
      details: stdout.toString().slice(0, 1000) // 返回部分输出
    });
  } catch (error) {
    console.error("启动服务失败:", error.message);
    res.status(500).json({ 
      message: "启动服务失败", 
      error: error.message,
      details: error.stdout ? error.stdout.toString() : "无详细输出"
    });
  }
});

// 重启suoha服务
app.post('/restart-suoha', (req, res) => {
  console.log("开始重启suoha服务...");
  try {
    // 先停止现有服务
    execSync("pkill -9 xray || true");
    execSync("pkill -9 cloudflared-linux || true");
    console.log("已停止旧服务");
    
    // 确保suoha.sh可执行
    execSync("chmod +x suoha.sh");
    console.log("已设置suoha.sh为可执行");
    
    // 重新启动服务
    const stdout = execSync("bash suoha.sh 2>&1", { timeout: 60000 });
    console.log("suoha服务重启输出:", stdout.toString());
    
    // 检查进程是否在运行
    const processCheck = execSync("ps -ef | grep -v grep | grep -E 'xray|cloudflared-linux'").toString();
    console.log("进程检查结果:", processCheck);
    
    res.json({ 
      message: "服务重启成功",
      details: stdout.toString().slice(0, 1000) // 返回部分输出
    });
  } catch (error) {
    console.error("重启服务失败:", error.message);
    res.status(500).json({ 
      message: "重启服务失败", 
      error: error.message,
      details: error.stdout ? error.stdout.toString() : "无详细输出"
    });
  }
});

// 停止suoha服务
app.post('/stop-suoha', (req, res) => {
  console.log("开始停止suoha服务...");
  try {
    execSync("pkill -9 xray || true");
    execSync("pkill -9 cloudflared-linux || true");
    console.log("所有suoha相关服务已停止");
    
    res.json({ message: "服务停止成功" });
  } catch (error) {
    console.error("停止服务失败:", error.message);
    res.status(500).json({ message: "停止服务失败", error: error.message });
  }
});

// 获取日志
app.get('/logs', (req, res) => {
  try {
    // 检查系统和进程信息
    const sysInfo = execSync("uname -a && df -h && ls -la").toString();
    const processInfo = execSync("ps -ef | grep -E 'xray|cloudflared|suoha' || true").toString();
    const fileCheck = execSync("ls -la suoha.sh v2ray.txt 2>&1 || true").toString();
    
    // 提取argo日志，如果存在的话
    let argoLog = "argo.log不存在";
    if (fs.existsSync('./argo.log')) {
      argoLog = fs.readFileSync('./argo.log', 'utf8');
    }
    
    res.json({
      systemInfo: sysInfo,
      processes: processInfo,
      fileStatus: fileCheck,
      argoLog: argoLog
    });
  } catch (error) {
    res.status(500).json({ error: "获取日志信息失败", message: error.message });
  }
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
      exec("chmod +x suoha.sh && bash suoha.sh", function (err, stdout, stderr) {
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
