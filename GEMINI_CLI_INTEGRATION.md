# Gemini CLI 集成负载均衡代理服务指南

本文档描述如何通过修改 hosts 文件，让官方的 `gemini-cli` 客户端使用你的负载均衡代理服务，实现多个 API key 的自动轮询和故障转移。

## 概述

由于官方 `gemini-cli` 不支持通过环境变量直接配置自定义 API 端点，我们通过修改系统的 hosts 文件来重定向 API 请求到本地的负载均衡代理服务。

## 架构图

```
gemini-cli → generativelanguage.googleapis.com (通过 hosts 重定向)
    ↓
127.0.0.1:443 (本地代理服务)
    ↓
负载均衡器 → 多个 API Key 轮询
    ↓
真实的 Google Gemini API
```

## 前提条件

- 已部署的 `gemini-proxy-go` 负载均衡服务
- 多个有效的 Gemini API Key
- 管理员权限（用于修改 hosts 文件）
- OpenSSL（用于生成 SSL 证书）

## 步骤一：配置代理服务支持 HTTPS

### 1.1 修改配置文件

编辑 `config.json`，将端口改为 443（HTTPS 默认端口）：

```json
{
  "port": 443,
  "backends": [
    {
      "url": "https://generativelanguage.googleapis.com",
      "api_key": "your-gemini-api-key-1"
    },
    {
      "url": "https://generativelanguage.googleapis.com", 
      "api_key": "your-gemini-api-key-2"
    },
    {
      "url": "https://generativelanguage.googleapis.com", 
      "api_key": "your-gemini-api-key-3"
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

### 1.2 生成 SSL 证书

为了支持 HTTPS，需要生成自签名证书：

```bash
# 生成私钥
openssl genrsa -out key.pem 2048

# 生成自签名证书
openssl req -new -x509 -sha256 -key key.pem -out cert.pem -days 365 \
  -subj "/CN=generativelanguage.googleapis.com/O=Local Proxy/C=US"
```

### 1.3 修改代理服务代码

在 `main.go` 中添加 HTTPS 支持：

```go
package main

import (
    "crypto/tls"
    "fmt"
    "log"
    "net/http"
    // ... 其他现有导入
)

func main() {
    // ... 现有的配置加载和负载均衡器创建代码 ...

    // 启动健康检查
    lb.StartHealthCheck()

    // 设置路由
    http.HandleFunc("/", lb.HandleRequest)
    http.HandleFunc("/status", lb.GetStatus)

    // 启动服务器
    addr := fmt.Sprintf(":%d", config.Port)
    
    if config.Port == 443 {
        log.Printf("Gemini代理服务器启动在端口 %d (HTTPS)", config.Port)
        log.Printf("状态页面: https://localhost/status")
        
        // 创建 TLS 配置
        server := &http.Server{
            Addr: addr,
            TLSConfig: &tls.Config{
                MinVersion: tls.VersionTLS12,
            },
        }
        
        // 输出后端服务器信息
        log.Printf("配置了 %d 个后端服务器:", len(config.Backends))
        for i, backend := range config.Backends {
            maskedKey := backend.APIKey
            if len(maskedKey) > 8 {
                maskedKey = maskedKey[:4] + "****" + maskedKey[len(maskedKey)-4:]
            }
            log.Printf("  [%d] %s (Key: %s)", i, backend.URL, maskedKey)
        }
        
        if err := server.ListenAndServeTLS("cert.pem", "key.pem"); err != nil {
            log.Fatalf("HTTPS 服务器启动失败: %v", err)
        }
    } else {
        log.Printf("Gemini代理服务器启动在端口 %d (HTTP)", config.Port)
        log.Printf("状态页面: http://localhost%s/status", addr)
        
        // ... 现有的 HTTP 服务器代码 ...
        
        if err := http.ListenAndServe(addr, nil); err != nil {
            log.Fatalf("HTTP 服务器启动失败: %v", err)
        }
    }
}
```

## 步骤二：修改 hosts 文件

### 2.1 Windows 系统

1. **以管理员身份运行记事本**：
   - 按 `Win + R`，输入 `notepad`
   - 右键点击记事本图标，选择"以管理员身份运行"

2. **打开 hosts 文件**：
   - 在记事本中：文件 → 打开
   - 导航到：`C:\Windows\System32\drivers\etc\`
   - 文件类型选择：所有文件 (*.*)
   - 选择并打开 `hosts` 文件

3. **添加重定向规则**：
   在文件末尾添加以下行：
   ```
   # Gemini API 重定向到本地代理
   127.0.0.1 generativelanguage.googleapis.com
   ```

4. **保存文件**：`Ctrl + S`

### 2.2 macOS/Linux 系统

1. **打开终端**

2. **编辑 hosts 文件**：
   ```bash
   sudo nano /etc/hosts
   ```
   或使用 vim：
   ```bash
   sudo vim /etc/hosts
   ```

3. **添加重定向规则**：
   在文件末尾添加：
   ```
   # Gemini API 重定向到本地代理
   127.0.0.1 generativelanguage.googleapis.com
   ```

4. **保存并退出**：
   - nano: `Ctrl + X`，然后 `Y`，再 `Enter`
   - vim: `:wq`

### 2.3 验证 hosts 配置

```bash
# 测试域名解析（应该返回 127.0.0.1）
ping generativelanguage.googleapis.com

# Windows 用户使用：
nslookup generativelanguage.googleapis.com
```

## 步骤三：启动代理服务

### 3.1 构建并运行代理服务

```bash
# 构建
go build -o gemini-proxy main.go

# 运行（需要管理员权限，因为使用 443 端口）
sudo ./gemini-proxy  # Linux/macOS
# 或在 Windows 中以管理员身份运行 PowerShell
.\gemini-proxy.exe    # Windows
```

### 3.2 验证代理服务

```bash
# 测试状态页面
curl -k https://localhost/status

# 测试 API 转发
curl -k "https://generativelanguage.googleapis.com/v1beta/models?key=test"
```

## 步骤四：配置和使用 gemini-cli

### 4.1 安装 gemini-cli

```bash
# 使用 npm 安装
npm install -g @google/gemini-cli

# 或使用 npx 直接运行
npx @google/gemini-cli
```

### 4.2 配置环境变量

```bash
# 设置一个虚拟的 API Key（代理服务会处理真实的 key）
export GEMINI_API_KEY="proxy-handled"

# 或者在 Windows PowerShell 中：
$env:GEMINI_API_KEY="proxy-handled"

# Windows CMD 中：
set GEMINI_API_KEY=proxy-handled
```

### 4.3 运行 gemini-cli

```bash
gemini
```

现在 `gemini-cli` 的所有 API 请求都会通过你的负载均衡代理服务，自动在多个 API key 之间轮询。

## 步骤五：监控和维护

### 5.1 查看代理状态

访问状态页面查看后端服务器健康状况：
```bash
curl -k https://localhost/status
```

或在浏览器中访问：`https://localhost/status`

### 5.2 日志监控

代理服务会输出详细的日志信息：
- 请求转发信息
- 健康检查结果
- 故障转移事件
- API Key 使用情况

### 5.3 故障排除

**常见问题及解决方案：**

1. **证书错误**：
   ```bash
   # 临时跳过证书验证（仅用于测试）
   export NODE_TLS_REJECT_UNAUTHORIZED=0
   ```

2. **端口占用**：
   ```bash
   # 检查端口占用
   netstat -tulpn | grep :443  # Linux
   netstat -an | findstr :443  # Windows
   ```

3. **权限问题**：
   - 确保以管理员权限运行代理服务（443 端口）
   - 确保以管理员权限修改了 hosts 文件

4. **DNS 缓存**：
   ```bash
   # 清除 DNS 缓存
   sudo systemctl flush-dns    # Linux
   sudo dscacheutil -flushcache # macOS
   ipconfig /flushdns          # Windows
   ```

## 恢复原始配置

### 6.1 恢复 hosts 文件

从 hosts 文件中删除添加的行：
```
# 删除这一行
127.0.0.1 generativelanguage.googleapis.com
```

### 6.2 停止代理服务

```bash
# 停止代理服务
Ctrl + C

# 或者找到进程并终止
ps aux | grep gemini-proxy  # Linux/macOS
tasklist | findstr gemini   # Windows
```

## 高级配置

### 7.1 使用不同端口（避免证书问题）

如果不想处理 SSL 证书，可以使用端口转发：

1. **保持代理服务在 8000 端口**
2. **使用端口转发工具**：
   ```bash
   # 使用 socat 转发 443 到 8000
   sudo socat TCP-LISTEN:443,fork TCP:127.0.0.1:8000
   
   # 或使用 nginx 作为反向代理
   # 配置 nginx 监听 443 并转发到 8000
   ```

### 7.2 配置多环境

可以创建不同的配置文件用于不同环境：

```bash
# 开发环境
./gemini-proxy -config=config-dev.json

# 生产环境  
./gemini-proxy -config=config-prod.json
```

## 安全注意事项

1. **API Key 安全**：确保配置文件中的 API Key 安全存储
2. **网络安全**：仅在本地使用，不要暴露到公网
3. **证书管理**：定期更新自签名证书
4. **访问控制**：考虑添加访问控制和认证机制

## 性能优化

1. **连接池**：配置适当的 HTTP 连接池大小
2. **缓存**：考虑添加响应缓存机制
3. **监控**：添加详细的性能监控和指标收集
4. **负载均衡算法**：根据需要选择不同的负载均衡算法

## 总结

通过修改 hosts 文件的方法，我们成功地让官方 `gemini-cli` 使用了自定义的负载均衡代理服务，实现了：

- ✅ 多个 API Key 的自动轮询
- ✅ 故障转移和健康检查  
- ✅ 透明的请求代理
- ✅ 无需修改 gemini-cli 源码
- ✅ 保持原有的使用体验

这种方案的优点是简单易实现，缺点是需要系统级配置修改。在生产环境中使用时，请确保做好安全防护和监控。
