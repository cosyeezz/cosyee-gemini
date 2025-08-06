# 部署和测试指南

## 📦 **环境准备**

### 1. 安装Go语言
```bash
# Windows
# 访问 https://golang.org/dl/
# 下载 go1.21.x.windows-amd64.msi
# 安装后重启命令行

# Linux
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# 验证安装
go version
```

### 2. 配置API密钥
编辑 `config.json` 文件：
```json
{
  "port": 8000,
  "backends": [
    {
      "url": "https://generativelanguage.googleapis.com",
      "api_key": "AIza****你的第一个密钥****"
    },
    {
      "url": "https://generativelanguage.googleapis.com", 
      "api_key": "AIza****你的第二个密钥****"
    }
  ],
  "health_check": {
    "enabled": true,
    "interval_seconds": 30,
    "timeout_seconds": 5,
    "path": "/v1beta/models"
  },
  "max_failures": 3,
  "log_level": "info"
}
```

## 🔧 **编译和运行**

### 方式1：直接运行（开发模式）
```bash
# 进入项目目录
cd gemini-proxy-go

# 直接运行（无需编译）
go run main.go
```

### 方式2：编译后运行（生产模式）
```bash
# 编译生成可执行文件
go build -o gemini-proxy main.go

# Windows
./gemini-proxy.exe

# Linux/Mac
./gemini-proxy
```

### 方式3：交叉编译（不同平台）
```bash
# 编译Linux版本（在Windows上）
set GOOS=linux
set GOARCH=amd64
go build -o gemini-proxy-linux main.go

# 编译Windows版本（在Linux上）
export GOOS=windows
export GOARCH=amd64
go build -o gemini-proxy.exe main.go

# 编译MacOS版本
export GOOS=darwin
export GOARCH=amd64
go build -o gemini-proxy-mac main.go
```

## 🧪 **功能测试**

### 1. 启动服务
```bash
go run main.go
```

预期输出：
```
2025/01/06 10:30:15 Gemini代理服务器启动在端口 8000
2025/01/06 10:30:15 状态页面: http://localhost:8000/status
2025/01/06 10:30:15 配置了 2 个后端服务器:
2025/01/06 10:30:15   [0] https://generativelanguage.googleapis.com (Key: AIza****1234)
2025/01/06 10:30:15   [1] https://generativelanguage.googleapis.com (Key: AIza****5678)
2025/01/06 10:30:15 启动健康检查，间隔: 30s
2025/01/06 10:30:45 健康检查成功: generativelanguage.googleapis.com
2025/01/06 10:30:45 健康检查成功: generativelanguage.googleapis.com
```

### 2. 测试状态接口
```bash
# 查看负载均衡器状态
curl http://localhost:8000/status
```

预期响应：
```json
{
  "backends": [
    {
      "index": 0,
      "url": "https://generativelanguage.googleapis.com",
      "healthy": true,
      "fail_count": 0,
      "last_checked": "2025-01-06 10:30:45"
    },
    {
      "index": 1,
      "url": "https://generativelanguage.googleapis.com",
      "healthy": true,
      "fail_count": 0,
      "last_checked": "2025-01-06 10:30:45"
    }
  ],
  "current_index": 0,
  "timestamp": "2025-01-06 10:31:00"
}
```

### 3. 测试API代理
```bash
# 测试模型列表（会自动轮询不同API密钥）
curl http://localhost:8000/v1beta/models

# 测试聊天请求
curl -X POST http://localhost:8000/v1beta/models/gemini-pro:generateContent \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [
      {
        "parts": [
          {
            "text": "Hello, how are you?"
          }
        ]
      }
    ]
  }'
```

### 4. 测试负载均衡
```bash
# 连续发送多个请求，观察日志中的密钥轮换
for i in {1..5}; do
  echo "Request $i:"
  curl -s http://localhost:8000/v1beta/models | head -5
  echo -e "\n---"
done
```

## 📊 **日志功能详解**

### 日志级别和内容
我们的负载均衡器包含详细的日志功能：

#### **1. 启动日志**
```
2025/01/06 10:30:15 Gemini代理服务器启动在端口 8000
2025/01/06 10:30:15 状态页面: http://localhost:8000/status
2025/01/06 10:30:15 配置了 2 个后端服务器:
2025/01/06 10:30:15   [0] https://generativelanguage.googleapis.com (Key: AIza****1234)
2025/01/06 10:30:15   [1] https://generativelanguage.googleapis.com (Key: AIza****5678)
```

#### **2. 请求转发日志**
```
2025/01/06 10:31:20 转发请求到: generativelanguage.googleapis.com, 路径: /v1beta/models
2025/01/06 10:31:25 转发请求到: generativelanguage.googleapis.com, 路径: /v1beta/models/gemini-pro:generateContent
```

#### **3. 健康检查日志**
```
# 成功的健康检查
2025/01/06 10:30:45 健康检查成功: generativelanguage.googleapis.com

# 失败的健康检查
2025/01/06 10:31:15 健康检查失败 generativelanguage.googleapis.com: HTTP 401 (失败次数: 1)
2025/01/06 10:31:45 后端服务器 generativelanguage.googleapis.com 被标记为不健康 (失败次数: 3)
```

#### **4. 故障切换日志**
```
2025/01/06 10:32:00 警告: 没有健康的后端服务器，使用第一个作为fallback
```

### 日志配置选项
在 `config.json` 中可以配置日志级别：
```json
{
  "log_level": "info"    // debug, info, warning, error
}
```

## 🐳 **Docker部署**

### 1. 创建Dockerfile
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o gemini-proxy main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/gemini-proxy .
COPY --from=builder /app/config.json .
EXPOSE 8000
CMD ["./gemini-proxy"]
```

### 2. 构建和运行
```bash
# 构建镜像
docker build -t gemini-proxy .

# 运行容器
docker run -d \
  --name gemini-proxy \
  -p 8000:8000 \
  -v $(pwd)/config.json:/root/config.json \
  gemini-proxy

# 查看日志
docker logs -f gemini-proxy
```

## 🖥️ **生产部署**

### 1. Systemd服务（Linux）
创建 `/etc/systemd/system/gemini-proxy.service`：
```ini
[Unit]
Description=Gemini Proxy Load Balancer
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/gemini-proxy
ExecStart=/opt/gemini-proxy/gemini-proxy
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 启动服务
sudo systemctl enable gemini-proxy
sudo systemctl start gemini-proxy
sudo systemctl status gemini-proxy

# 查看日志
sudo journalctl -u gemini-proxy -f
```

### 2. 反向代理（Nginx）
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🔍 **监控和维护**

### 1. 健康检查脚本
```bash
#!/bin/bash
# health_check.sh
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/status)
if [ $STATUS -eq 200 ]; then
    echo "Service is healthy"
    exit 0
else
    echo "Service is unhealthy (HTTP $STATUS)"
    exit 1
fi
```

### 2. 日志轮转
```bash
# 使用logrotate管理日志
# /etc/logrotate.d/gemini-proxy
/var/log/gemini-proxy.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

### 3. 性能监控
```bash
# 查看资源使用情况
top -p $(pgrep gemini-proxy)
ps aux | grep gemini-proxy

# 查看网络连接
netstat -tulpn | grep :8000
```

## 📈 **性能优化建议**

### 1. 配置调优
```json
{
  "health_check": {
    "interval_seconds": 60,    // 降低检查频率节省资源
    "timeout_seconds": 10      // 适当增加超时时间
  },
  "max_failures": 5,           // 增加容错次数
  "log_level": "warning"       // 生产环境减少日志输出
}
```

### 2. 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# 优化网络参数
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
sysctl -p
```

这个部署指南涵盖了从开发到生产的完整流程，包括详细的日志功能说明。你可以按照这个指南逐步测试和部署负载均衡器。
