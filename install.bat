@echo off
REM Gemini代理负载均衡器安装脚本 (Windows版本)

echo 🚀 Gemini代理负载均衡器安装脚本
echo =================================

REM 检查Go是否安装
echo.
echo 1. 检查Go语言环境...
go version >nul 2>&1
if %errorlevel% == 0 (
    for /f "tokens=3" %%i in ('go version') do set GO_VERSION=%%i
    echo ✅ Go已安装: %GO_VERSION%
) else (
    echo ❌ Go未安装
    echo 请访问 https://golang.org/dl/ 下载安装Go语言
    echo 下载 go1.21.x.windows-amd64.msi 并安装
    pause
    exit /b 1
)

REM 检查配置文件
echo.
echo 2. 检查配置文件...
if exist "config.json" (
    echo ✅ 配置文件存在
    
    REM 检查是否包含示例密钥
    findstr /C:"your-gemini-api-key" config.json >nul 2>&1
    if %errorlevel% == 0 (
        echo ⚠️  请先配置您的Gemini API密钥
        echo 编辑 config.json 文件，替换示例密钥为真实密钥
        set /p choice="是否现在编辑配置文件? (y/n): "
        if /i "%choice%"=="y" (
            notepad config.json
        )
    )
) else (
    echo ❌ 配置文件不存在
    pause
    exit /b 1
)

REM 编译程序
echo.
echo 3. 编译程序...
go build -o gemini-proxy.exe main.go
if %errorlevel% == 0 (
    echo ✅ 编译成功
) else (
    echo ❌ 编译失败
    pause
    exit /b 1
)

REM 测试配置
echo.
echo 4. 测试配置...
start /b gemini-proxy.exe
timeout /t 3 /nobreak >nul

REM 测试状态接口
curl -s http://localhost:8000/status >nul 2>&1
if %errorlevel% == 0 (
    echo ✅ 服务启动成功
    taskkill /f /im gemini-proxy.exe >nul 2>&1
) else (
    echo ❌ 服务启动失败
    taskkill /f /im gemini-proxy.exe >nul 2>&1
    pause
    exit /b 1
)

echo.
echo 🎉 安装完成！
echo.
echo 使用方法:
echo 1. 启动服务: gemini-proxy.exe
echo 2. 查看状态: curl http://localhost:8000/status
echo 3. 运行测试: test.bat
echo 4. 后台运行: start /b gemini-proxy.exe

echo.
echo 配置文件位置: config.json
echo 日志输出: 控制台 ^(可重定向到文件^)
echo 状态页面: http://localhost:8000/status

echo.
echo 准备就绪！您现在可以启动负载均衡器了。
echo.
pause
