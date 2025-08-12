# 本地安装指南

这份指南将帮助你在本地安装并全局使用 `gemini` 命令。

## 📦 安装步骤

### 1. 下载代码
```bash
git clone https://github.com/cosyeezz/cosyee-gemini.git
cd cosyee-gemini
```

### 2. 安装依赖
```bash
npm install
```

### 3. 全局安装
```bash
npm install -g .
```

> **说明**：`npm install -g .` 会自动运行 `prepare` 脚本，构建 bundle 文件，然后将 `gemini` 命令链接到全局。

## ✅ 验证安装

```bash
# 检查版本
gemini --version

# 启动对话
gemini
```

## 🔧 配置 API Key

### 方式1：环境变量
```bash
export GEMINI_API_KEY="your-api-key-here"
gemini
```

### 方式2：多个 API Key（支持轮询）
```bash
export GEMINI_API_KEY="key1,key2,key3"
gemini
```

### 方式3：配置代理（可选）
```bash
export GEMINI_PROXY="http://localhost:10808"
gemini
```

## 🔄 更新版本

当有新的代码更新时：

```bash
cd cosyee-gemini
git pull
npm install -g .
```

## 🗑️ 卸载

```bash
npm uninstall -g @google/gemini-cli
```

## 🚀 开始使用

安装完成后，你可以在任何目录下直接使用：

```bash
# 启动交互式对话
gemini

# 非交互式使用
gemini -p "解释这段代码的功能"

# 在特定目录中使用
cd your-project
gemini
```

## 💡 功能特点

- ✅ **多 API Key 轮询**：自动负载均衡和故障转移
- ✅ **代理支持**：默认支持本地代理
- ✅ **详细日志**：API Key 切换日志记录
- ✅ **跨平台**：支持 Windows、macOS、Linux

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

### 问题3：API Key 轮询日志位置
- **Windows**: `%USERPROFILE%\.gemini-cli\logs\api-key-rotation.log`
- **macOS**: `~/Library/Logs/gemini-cli/api-key-rotation.log`
- **Linux**: `~/.local/share/gemini-cli/logs/api-key-rotation.log` 