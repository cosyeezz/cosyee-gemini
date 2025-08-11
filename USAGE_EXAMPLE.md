# Gemini CLI 本地测试指南

本文档提供了如何在本地构建、配置和测试 Gemini CLI 代理与 API Key 轮询功能的完整步骤。

## 功能概述

此增强版本的 Gemini CLI 支持以下新功能：

1. **默认代理支持**: 所有 API 请求默认通过 `http://localhost:10808` 代理，可通过环境变量自定义
2. **多 API Key 轮询**: 支持负载均衡和自动故障转移
3. **可观测性**: 在 Key 切换时输出详细的日志信息

## 前置要求

- Node.js 版本 20.19.0 (开发环境推荐)
- 一个或多个有效的 Gemini API Key
- (可选) 运行在 10808 端口的代理服务器

## 安装方式

### 方式一：全局安装 (推荐)

如果您想在任何目录下直接使用 `gemini` 命令，可以进行全局安装：

#### Git 直接安装 (可能较慢)
```powershell
npm install -g git+https://github.com/cosyeezz/cosyee-gemini.git
```

#### Git 克隆 + 本地安装 (推荐，更稳定)
如果上述方法卡住或失败，请使用这个替代方案：

```powershell
# 1. 克隆仓库
git clone https://github.com/cosyeezz/cosyee-gemini.git
cd cosyee-gemini

# 2. 全局安装
npm install -g .

# 3. 清理临时文件 (可选)
cd ..
Remove-Item -Recurse -Force cosyee-gemini
```

#### 验证安装
```powershell
gemini --version
# 应该输出: 0.1.18
```

安装成功后，您可以直接跳到 [第二步：环境变量配置](#第二步环境变量配置)。

---

### 方式二：本地开发模式

如果您想修改代码或进行开发，请使用本地构建方式：

## 第一步：构建项目

1. 打开您的终端 (PowerShell)
2. 确保您位于项目根目录：
   ```powershell
   cd D:\AI\cosyee-gemini
   ```

3. 安装依赖 (如果还未安装)：
   ```powershell
   npm install
   ```

4. 构建项目：
   ```powershell
   npm run build
   ```

   > **注意**: 构建过程会将 TypeScript 代码编译为 JavaScript。如果看到任何编译错误，请先解决这些问题。

## 第二步：环境变量配置

### 代理配置 (可选)

如果您想测试代理功能，请设置以下环境变量之一：

```powershell
# 使用默认代理 (会自动使用 localhost:10808)
# 无需设置任何变量

# 或者自定义代理地址
$env:GEMINI_PROXY="http://localhost:8080"

# 或者使用标准代理环境变量
$env:HTTPS_PROXY="http://localhost:8080"
$env:HTTP_PROXY="http://localhost:8080"
```

### API Key 配置

#### 单个 API Key (现有行为)
```powershell
$env:GEMINI_API_KEY="your_single_api_key_here"
```

#### 多个 API Key (新功能)
```powershell
# 使用逗号分隔多个 Key
$env:GEMINI_API_KEY="key1,key2,key3"
```

## 命令使用说明

根据您的安装方式，请使用对应的命令：

### 全局安装用户 (推荐)
```powershell
# 基本命令
gemini -p "您的问题"

# 交互模式
gemini
```

### 本地开发用户
```powershell
# 基本命令
npm start -- -p "您的问题"

# 交互模式
npm start
```

> **注意**：以下所有测试示例都会同时提供两种命令格式。

## 第三步：测试场景

### 场景 1：负载均衡测试

**目标**: 验证多个有效 Key 之间的轮询负载均衡

1. **设置环境变量**:
   ```powershell
   # 将这些替换为您的真实有效 Key
   $env:GEMINI_API_KEY="AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,AIzaSyCyyyyyyyyyyyyyyyyyyyyyyyyyyy"
   ```

2. **第一次测试**:
   ```powershell
   # 全局安装用户
   gemini -p "你好，请回答一个简单的问题"
   
   # 本地开发用户
   npm start -- -p "你好，请回答一个简单的问题"
   ```

   **预期输出**:
   ```
   [Gemini CLI] Request succeeded. Next request will use key ending with "...yyyy"
   # AI 的回答内容
   ```

3. **第二次测试**:
   ```powershell
   # 全局安装用户
   gemini -p "今天是星期几？"
   
   # 本地开发用户
   npm start -- -p "今天是星期几？"
   ```

   **预期输出**:
   ```
   [Gemini CLI] Request succeeded. Next request will use key ending with "...xxxx"
   # AI 的回答内容
   ```

4. **验证结果**: 
   - 两次请求都应该成功
   - 日志显示 Key 在两次请求之间发生了轮换
   - 这证明负载均衡功能正常工作

### 场景 2：故障转移测试

**目标**: 验证当第一个 Key 失效时，系统能够自动切换到备用 Key

1. **设置环境变量**:
   ```powershell
   # 第一个是故意的无效 Key，第二个是您的真实有效 Key
   $env:GEMINI_API_KEY="INVALID_KEY_THAT_WILL_FAIL,AIzaSyCyyyyyyyyyyyyyyyyyyyyyyyyyyy"
   ```

2. **执行测试**:
   ```powershell
   npm start -- -p "给我讲一个关于程序员的笑话"
   ```

3. **预期输出**:
   ```
   [Gemini CLI] API Key ending with "...FAIL" failed. Attempting key ending with "...yyyy"
   [Gemini CLI] Request succeeded. Next request will use key ending with "...FAIL"
   # AI 的回答内容
   ```

4. **验证结果**:
   - 请求最终成功，尽管第一个 Key 失败了
   - 日志清楚地显示了故障转移过程
   - 这证明故障转移功能正常工作

### 场景 3：代理功能测试

**目标**: 验证 API 请求是否通过指定的代理服务器

**前提条件**: 您需要在本地运行一个代理服务器 (如 mitmproxy, Charles, 或其他)

1. **启动代理服务器**:
   - 在端口 10808 (默认) 或其他端口启动您的代理
   - 配置代理以记录或显示通过它的请求

2. **设置环境变量**:
   ```powershell
   $env:GEMINI_API_KEY="your_valid_api_key"
   $env:GEMINI_PROXY="http://localhost:10808"  # 或您的代理地址
   ```

3. **执行测试**:
   ```powershell
   npm start -- -p "测试代理连接"
   ```

4. **验证结果**:
   - 检查您的代理服务器日志
   - 应该能看到 Gemini CLI 发出的 HTTPS 请求经过了代理
   - 请求应该成功完成并返回 AI 回答

### 场景 4：单个 Key 向后兼容性测试

**目标**: 确保现有的单 Key 配置仍然正常工作

1. **设置环境变量**:
   ```powershell
   $env:GEMINI_API_KEY="your_single_api_key"
   ```

2. **执行测试**:
   ```powershell
   npm start -- -p "测试单个 API Key 的兼容性"
   ```

3. **预期输出**:
   ```
   # AI 的回答内容 (不应该有任何轮询相关的日志)
   ```

4. **验证结果**:
   - 请求应该成功
   - 不应该看到任何关于 Key 轮换的日志信息
   - 行为应该与修改前完全一致

## 第四步：交互模式测试

除了非交互模式 (`-p` 参数) 外，您还可以在交互模式下测试：

1. **启动交互模式**:
   ```powershell
   # 全局安装用户
   gemini
   
   # 本地开发用户
   npm start
   ```

2. **进行多轮对话**:
   ```
   > 你好，我想测试多轮对话
   > 请记住我刚才说的话
   > 现在再回复我
   ```

3. **观察日志**:
   - 每次成功的请求后，都应该看到 Key 轮换的日志
   - 多轮对话应该在不同的 Key 之间轮换

## 第五步：错误处理测试

### 测试所有 Key 都失效的情况

1. **设置环境变量**:
   ```powershell
   $env:GEMINI_API_KEY="AIzaSyDZOr7WaY45IWrjZ7LEI0J8DuXvwXXCCGA,AIzaSyAngfVNv1OrMRg_AGYUkgaH_0NisFd_JXE,AIzaSyA_a2GqkWm12ctG5780w3S8D2vR58xsnrA"
   ```

2. **执行测试**:
   ```powershell
   npm start -- -p "这个请求应该失败"
   ```

3. **预期输出**:
   ```
   [Gemini CLI] API Key ending with "...EY_1" failed. Attempting key ending with "...EY_2"
   [Gemini CLI] API Key ending with "...EY_2" failed. Attempting key ending with "...EY_3"
   # 最终错误信息
   ```

4. **验证结果**:
   - 系统应该尝试所有 Key
   - 最终应该抛出合适的错误信息
   - 不应该无限循环

## 故障排除

### 安装问题

1. **`npm install -g git+...` 卡住或失败**:
   ```powershell
   # 解决方案：使用 Git 克隆 + 本地安装
   git clone https://github.com/cosyeezz/cosyee-gemini.git
   npm install -g ./cosyee-gemini
   Remove-Item -Recurse -Force cosyee-gemini
   ```

2. **`gemini` 命令不存在**:
   - 检查全局安装是否成功：`npm ls -g --depth=0`
   - 确保 npm 全局 bin 目录在 PATH 中：`npm config get prefix`
   - 重新安装：`npm uninstall -g @google/gemini-cli && npm install -g ./cosyee-gemini`

3. **GitHub 推送保护错误** (开发者相关):
   - 如果您在开发时遇到 "Secret scanning found a Google OAuth Client ID" 错误
   - 这些是公开的 OAuth 客户端 ID，可以安全地允许
   - 访问 GitHub 提供的链接并选择 "It's used in tests"

### 运行问题

1. **构建失败**:
   - 确保 Node.js 版本为 20.19.0
   - 运行 `npm install` 重新安装依赖
   - 检查是否有 TypeScript 编译错误

2. **环境变量未生效**:
   - 确保在同一个 PowerShell 会话中设置变量和运行命令
   - 使用 `echo $env:GEMINI_API_KEY` 验证变量是否正确设置

3. **代理连接失败**:
   - 确保代理服务器正在运行并监听指定端口
   - 检查防火墙设置
   - 尝试使用 `curl` 测试代理连接

4. **API Key 错误**:
   - 验证 API Key 的有效性
   - 确保 Key 有足够的配额
   - 检查 Key 的权限设置

### 调试技巧

1. **启用详细日志**:
   ```powershell
   $env:DEBUG="1"
   npm start -- -p "调试模式测试"
   ```

2. **检查网络请求**:
   - 使用代理工具 (如 mitmproxy) 监控请求
   - 检查请求头和响应

3. **验证配置**:
   ```powershell
   # 检查当前环境变量
   echo $env:GEMINI_API_KEY
   echo $env:GEMINI_PROXY
   ```

## 结论

完成以上测试后，您应该能够验证：

- ✅ 代理功能正常工作
- ✅ 多 API Key 负载均衡正常工作  
- ✅ 故障转移机制正常工作
- ✅ 向后兼容性保持良好
- ✅ 错误处理合理且有用的日志输出

如果任何测试失败，请参考故障排除部分，或检查实现代码是否与设计方案一致。


# 调试方案：使用文件日志验证API Key轮询

## 问题背景

经过多次交互式聊天测试，我们发现之前在 `ApiKeyRotatingContentGenerator.ts` 中添加的 `console.log` 语句并未显示在终端UI上。

**根本原因**: 项目使用的界面库 `Ink` 接管了 `stdout` (标准输出流) 来渲染其React组件。在这个过程中，常规的 `console.log` 输出会被抑制或重定向，以防止破坏UI布局。这导致我们无法通过终端直接观察到API Key的轮询日志。

## 解决方案

为了绕开 `Ink` 的UI渲染，我们需要一个独立的、持久化的日志记录方式。最直接可靠的方法是将日志信息写入到一个本地文件中。

## 修改计划

我们将对 `apiKeyRotatingContentGenerator.ts` 文件进行一个最小化的、临时的修改，仅用于调试和验证目的。

### 第一步：导入 `fs` 模块

在 `packages/core/src/core/apiKeyRotatingContentGenerator.ts` 文件的顶部，添加对Node.js内置文件系统模块的导入。

```typescript
import * as fs from 'fs';
```

### 第二步：替换 `console.log` 为文件写入

在 `ApiKeyRotatingContentGenerator.ts` 文件中，找到所有 `console.log` 语句，并将它们替换为 `fs.appendFileSync`。

1.  **修改成功日志 (负载均衡)**

    *   **位置**: 在 `executeWithRetry` 方法的 `try` 块中，请求成功之后。
    *   **原始代码**:
        ```typescript
        console.log(`[Gemini CLI] Request succeeded. Next request will use key ending with "...${this.keyManager.getCurrentKey().slice(-4)}"`);
        ```
    *   **修改为**:
        ```typescript
        fs.appendFileSync('rotation.log', `[SUCCESS] Request succeeded. Next request will use key ending with "...${this.keyManager.getCurrentKey().slice(-4)}"\n`);
        ```

2.  **修改失败日志 (故障转移)**

    *   **位置**: 在 `executeWithRetry` 方法的 `catch` 块中，确认是认证错误并准备切换Key时。
    *   **原始代码**:
        ```typescript
        console.log(`[Gemini CLI] API Key ending with "...${oldKey.slice(-4)}" failed. Attempting key ending with "...${this.keyManager.getCurrentKey().slice(-4)}"`);
        ```
    *   **修改为**:
        ```typescript
        fs.appendFileSync('rotation.log', `[FAILURE] API Key ending with "...${oldKey.slice(-4)}" failed. Attempting key ending with "...${this.keyManager.getCurrentKey().slice(-4)}"\n`);
        ```

## 验证步骤

1.  **应用修改**: 按照上述计划修改 `apiKeyRotatingContentGenerator.ts` 文件。

2.  **重新构建**: 在项目根目录运行 `npm run build` 以编译更改。

3.  **准备测试环境**:
    *   (可选) 在终端运行 `del rotation.log` (Windows) 或 `rm rotation.log` (macOS/Linux) 删除旧的日志文件。
    *   设置包含多个API Key的环境变量，例如:
        ```powershell
        $env:GEMINI_API_KEY="VALID_KEY_1,VALID_KEY_2"
        ```

4.  **执行测试**:
    *   启动交互式聊天: `npm start`
    *   进行至少两轮成功的对话。

5.  **检查日志文件**:
    *   测试完成后，退出聊天框。
    *   在项目根目录下找到新生成的 `rotation.log` 文件。
    *   使用 `type rotation.log` (Windows) 或 `cat rotation.log` (macOS/Linux) 查看文件内容，或直接在代码编辑器中打开它。

## 预期结果

`rotation.log` 文件中的内容应该清晰地记录了API Key的轮换过程，例如：
[SUCCESS] Request succeeded. Next request will use key ending with "...KEY_2"
[SUCCESS] Request succeeded. Next request will use key ending with "...KEY_1"

如果进行故障转移测试，内容应该类似于：
[FAILURE] API Key ending with "...FAIL" failed. Attempting key ending with "...KEY_2"
[SUCCESS] Request succeeded. Next request will use key ending with "...FAIL"

通过检查这个日志文件，我们就可以最终确认负载均衡和故障转移功能是否按预期工作。