# Gemini CLI 增强版

基于 [Google 官方 Gemini CLI](https://github.com/google-gemini/gemini-cli) 的增强版本，添加了 API Key 轮询、故障转移和代理支持等企业级功能。

## 🆚 主要改动

### 🔄 **API Key 轮询与故障转移**
- **多 Key 支持**：支持配置多个 API Key（逗号分隔），实现负载均衡
- **自动故障转移**：当某个 API Key 失败时自动切换到下一个可用的 Key
- **智能轮询**：每次请求成功后自动轮询到下一个 Key，避免单点过载
- **详细日志**：记录 Key 切换过程，便于监控和调试

```bash
# 配置多个 API Key
export GEMINI_API_KEY="key1,key2,key3"
```

### 🌐 **代理支持**
- **默认代理**：所有 API 请求默认通过 `http://localhost:10808` 代理
- **自定义代理**：支持通过环境变量 `GEMINI_PROXY` 自定义代理地址
- **无缝集成**：代理功能对用户透明，无需额外配置

```bash
# 自定义代理地址
export GEMINI_PROXY="http://your-proxy-server:port"
```

### 📊 **跨平台日志系统**
- **统一路径**：不同操作系统使用标准化的日志路径
- **详细记录**：API Key 切换、故障转移过程的完整日志
- **静默处理**：日志功能不影响主程序运行

**日志位置**：
- **Windows**: `%USERPROFILE%\.gemini-cli\logs\api-key-rotation.log`
- **macOS**: `~/Library/Logs/gemini-cli/api-key-rotation.log`
- **Linux**: `~/.local/share/gemini-cli/logs/api-key-rotation.log`

### 🛠️ **开发优化**
- **源码开发**：开发时直接使用源码，bundle 文件被忽略
- **自动构建**：安装时自动构建可执行文件
- **全局命令**：支持 `gemini` 命令全局使用

## 📦 本地安装与使用

### 安装步骤

#### 1. 下载代码
```bash
git clone https://github.com/cosyeezz/cosyee-gemini.git
cd cosyee-gemini
```

#### 2. 安装依赖
```bash
npm install
```
> 这一步会自动运行 `prepare` 脚本，构建 bundle 文件

#### 3. 全局安装
```bash
npm install -g .
```

#### 4. 验证安装
```bash
# 检查版本
gemini --version

# 启动对话
gemini
```

### 配置说明

#### 🔑 API Key 配置

**单个 API Key**：
```bash
export GEMINI_API_KEY="your-api-key-here"
gemini
```

**多个 API Key（轮询模式）**：
```bash
export GEMINI_API_KEY="key1,key2,key3"
gemini
```

**其他认证方式**：
```bash
# OAuth 登录
gemini  # 首次运行会提示浏览器登录

# Vertex AI
export GOOGLE_API_KEY="your-vertex-api-key"
export GOOGLE_GENAI_USE_VERTEXAI=true
gemini

# 设置 Google Cloud 项目
export GOOGLE_CLOUD_PROJECT="your-project-name"
gemini
```

#### 🌐 代理配置

```bash
# 使用默认代理 (http://localhost:10808)
gemini

# 自定义代理
export GEMINI_PROXY="http://your-proxy:port"
gemini

# 禁用代理
unset GEMINI_PROXY
gemini
```

### 基本使用

#### 交互式对话
```bash
# 在当前目录启动
gemini

# 包含多个目录
gemini --include-directories ../lib,../docs

# 使用特定模型
gemini -m gemini-2.5-flash
```

#### 非交互式使用
```bash
# 单次问答
gemini -p "解释这段代码的功能"

# 分析项目
cd your-project
gemini -p "分析这个项目的架构"
```

### 更新版本

当有新的代码更新时：

```bash
cd cosyee-gemini
git pull
npm install -g .
```

### 卸载

```bash
npm uninstall -g @google/gemini-cli
```

## 💡 功能特点

- ✅ **多 API Key 轮询**：自动负载均衡和故障转移
- ✅ **代理支持**：默认支持本地代理，可自定义
- ✅ **详细日志**：API Key 切换和错误日志记录
- ✅ **跨平台**：支持 Windows、macOS、Linux
- ✅ **向后兼容**：完全兼容原版 Gemini CLI 的所有功能
- ✅ **企业友好**：适用于需要高可用性的企业环境

## 🐛 故障排除

### 问题1：`gemini` 命令未找到
```bash
# 确保全局安装成功
npm list -g @google/gemini-cli

# 检查 npm 全局路径
npm config get prefix
```

### 问题2：权限错误
```bash
# macOS/Linux 使用 sudo
sudo npm install -g .

# 或配置 npm 全局路径到用户目录
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH
```

### 问题3：API Key 轮询不工作
- 检查 API Key 格式是否正确（逗号分隔，无空格）
- 查看日志文件确认切换过程
- 确保所有 API Key 都有效且有足够配额

### 问题4：代理连接失败
```bash
# 检查代理服务器是否运行
curl -x http://localhost:10808 https://www.google.com

# 临时禁用代理测试
unset GEMINI_PROXY
gemini
```

## 📄 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源协议。

## 🔗 相关链接

- **官方原版**：[google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)
- **增强版本**：[cosyeezz/cosyee-gemini](https://github.com/cosyeezz/cosyee-gemini)

---

<p align="center">
  基于 Google Gemini CLI 的企业级增强版本
</p>
