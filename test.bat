@echo off
REM Gemini代理负载均衡器测试脚本 (Windows版本)

set BASE_URL=http://localhost:8000

echo 🚀 Gemini代理负载均衡器测试脚本
echo =================================

REM 检查服务是否运行
echo.
echo 1. 检查服务状态...
curl -s "%BASE_URL%/status" >nul 2>&1
if %errorlevel% == 0 (
    echo ✅ 服务正在运行
) else (
    echo ❌ 服务未运行，请先启动服务：go run main.go
    pause
    exit /b 1
)

REM 获取状态信息
echo.
echo 2. 获取负载均衡器状态...
curl -s "%BASE_URL%/status"

REM 测试模型列表API
echo.
echo 3. 测试模型列表API...
curl -s -w "HTTP状态码: %%{http_code}" -o response.tmp "%BASE_URL%/v1beta/models"
echo.
findstr /C:"models" response.tmp >nul 2>&1
if %errorlevel% == 0 (
    echo ✅ 模型列表API调用成功
) else (
    echo ❌ 模型列表API调用失败
    type response.tmp
)

REM 测试负载均衡轮询
echo.
echo 4. 测试负载均衡轮询 ^(发送5个请求^)...
for /l %%i in (1,1,5) do (
    echo | set /p="请求 %%i: "
    curl -s -w "%%{http_code}" -o nul "%BASE_URL%/v1beta/models" > temp_status.txt
    set /p status=<temp_status.txt
    if "!status!" == "200" (
        echo 成功
    ) else (
        echo 失败 ^(HTTP !status!^)
    )
    timeout /t 1 /nobreak >nul
)

REM 测试聊天API
echo.
echo 5. 测试聊天API...
echo {"contents":[{"parts":[{"text":"Hello! Please respond with just \"Hello from Gemini\" to test the API."}]}]} > chat_payload.json
curl -s -w "HTTP状态码: %%{http_code}" -X POST ^
    -H "Content-Type: application/json" ^
    -d @chat_payload.json ^
    -o chat_response.tmp ^
    "%BASE_URL%/v1beta/models/gemini-pro:generateContent"
echo.
findstr /C:"candidates" chat_response.tmp >nul 2>&1
if %errorlevel% == 0 (
    echo ✅ 聊天API调用成功
    echo 响应内容：
    type chat_response.tmp
) else (
    echo ❌ 聊天API调用失败
    type chat_response.tmp
)

REM 测试健康检查
echo.
echo 6. 等待健康检查日志...
echo 请查看服务器日志，应该能看到健康检查的输出
echo 健康检查每30秒执行一次

REM 性能测试
echo.
echo 7. 简单性能测试 ^(10个请求^)...
set start_time=%time%
for /l %%i in (1,1,10) do (
    start /b curl -s -o nul "%BASE_URL%/status"
)
timeout /t 3 /nobreak >nul
set end_time=%time%
echo ✅ 10个请求已发送

REM 清理临时文件
del /q response.tmp chat_response.tmp chat_payload.json temp_status.txt 2>nul

echo.
echo 🎉 测试完成！
echo 如果所有测试都通过，说明负载均衡器工作正常
echo.
echo 监控建议：
echo - 访问 %BASE_URL%/status 查看实时状态
echo - 观察服务器日志中的轮询和健康检查信息
echo - 监控API密钥的使用情况和失败次数
echo.
pause
