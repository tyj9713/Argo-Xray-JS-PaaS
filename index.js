const express = require("express");
const app = express();
const basicAuth = require("basic-auth");
const os = require("os");
var exec = require("child_process").exec;

// 假设环境变量中已经设置了WEB_USERNAME和WEB_PASSWORD
const username = process.env.WEB_USERNAME || "admin";
const password = process.env.WEB_PASSWORD || "password";

// 页面访问密码中间件
app.use((req, res, next) => {
  const user = basicAuth.parse(req);
  if (user && user.name === username && user.pass === password) {
    return next();
  }
  res.set("WWW-Authenticate", 'Basic realm="Node"');
  return res.status(401).send("Access denied");
});

// keepalive begin
// 哪吒保活
function keep_nezha_alive() {
  exec("pgrep -laf nezha-agent", function (err, stdout, stderr) {
    if (err) {
      console.error("Error checking nezha-agent process: ", err);
    } else if (stdout.includes("nezha-agent")) {
      console.log("哪吒正在运行");
    } else {
      console.log("启动哪吒客户端...");
      exec("bash nezha.sh", function (err, stdout, stderr) {
        if (err) {
          console.error("启动哪吒客户端失败: ", err);
        } else {
          console.log("哪吒客户端启动成功");
        }
      });
    }
  });
}

// 设置保活检查的间隔时间，单位为毫秒
setInterval(keep_nezha_alive, 45 * 1000);

// 启动核心脚本运行web,哪吒和argo
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
  console.log(`Example app listening on port ${port}!`);
});
