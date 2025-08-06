# Gemini Proxy - 轻量级负载均衡器

一个用Go语言实现的极简Gemini API负载均衡器，专为1核1G服务器优化。

## 特性

- ✅ **轻量级**: 内存占用仅5-10MB
- ✅ **简单轮询**: Round Robin负载均衡算法
- ✅ **健康检查**: HTTP探测后端服务状态
- ✅ **配置文件**: JSON格式配置
- ✅ **简单日志**: 结构化日志输出
- ✅ **单二进制**: 无依赖部署

## 快速开始

### 1. 配置API密钥

编辑 `config.json` 文件，添加你的Gemini API密钥：

```json
{
  "port": 8000,
  "backends": [
    {
      "url": "https://generativelanguage.googleapis.com",
      "api_key": "你的第一个API密钥"
    },
    {
      "url": "https://generativelanguage.googleapis.com", 
      "api_key": "你的第二个API密钥"
    }
  ]
}
```

### 2. 编译运行

```bash
# 编译
go build -o gemini-proxy main.go

# 运行
./gemini-proxy
```

### 3. 使用代理

```bash
# 测试请求
curl -X POST http://localhost:8000/v1beta/models/gemini-pro:generateContent \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}'

# 查看状态
curl http://localhost:8000/status
```

## 配置说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `port` | 监听端口 | 8000 |
| `backends[].url` | 后端API地址 | - |
| `backends[].api_key` | API密钥 | - |
| `health_check.enabled` | 启用健康检查 | true |
| `health_check.interval_seconds` | 检查间隔(秒) | 30 |
| `health_check.timeout_seconds` | 超时时间(秒) | 5 |
| `health_check.path` | 检查路径 | "/v1beta/models" |
| `max_failures` | 最大失败次数 | 3 |
| `log_level` | 日志级别 | "info" |

## 内存使用

- **启动内存**: ~5MB
- **运行内存**: ~8-12MB
- **对比Python版本**: 节省90%+内存

## API端点

- `GET /status` - 查看负载均衡器状态
- `POST /*` - 代理所有其他请求到后端

## 故障处理

- 自动检测后端服务健康状态
- 失败次数超过阈值自动禁用
- 健康恢复后自动启用
- 所有后端失败时使用fallback机制

## 适用场景

- 1核1G小内存服务器
- AI开发项目的API代理
- 简单的负载均衡需求
- 学习Go语言网络编程
