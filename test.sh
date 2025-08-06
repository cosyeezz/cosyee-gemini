#!/bin/bash

# Gemini代理负载均衡器测试脚本

BASE_URL="http://localhost:8000"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Gemini代理负载均衡器测试脚本"
echo "================================="

# 检查服务是否运行
echo -e "\n${YELLOW}1. 检查服务状态...${NC}"
if curl -s "$BASE_URL/status" > /dev/null; then
    echo -e "${GREEN}✅ 服务正在运行${NC}"
else
    echo -e "${RED}❌ 服务未运行，请先启动服务：go run main.go${NC}"
    exit 1
fi

# 获取状态信息
echo -e "\n${YELLOW}2. 获取负载均衡器状态...${NC}"
curl -s "$BASE_URL/status" | jq '.' || curl -s "$BASE_URL/status"

# 测试模型列表API
echo -e "\n${YELLOW}3. 测试模型列表API...${NC}"
response=$(curl -s -w "%{http_code}" -o response.tmp "$BASE_URL/v1beta/models")
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ 模型列表API调用成功${NC}"
    echo "前5个模型："
    cat response.tmp | jq '.models[0:5] | .[] | .name' 2>/dev/null || head -10 response.tmp
else
    echo -e "${RED}❌ 模型列表API调用失败 (HTTP $response)${NC}"
    cat response.tmp
fi

# 测试负载均衡轮询
echo -e "\n${YELLOW}4. 测试负载均衡轮询 (发送5个请求)...${NC}"
for i in {1..5}; do
    echo -n "请求 $i: "
    response=$(curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/v1beta/models")
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}成功${NC}"
    else
        echo -e "${RED}失败 (HTTP $response)${NC}"
    fi
    sleep 1
done

# 测试聊天API
echo -e "\n${YELLOW}5. 测试聊天API...${NC}"
chat_payload='{
    "contents": [
        {
            "parts": [
                {
                    "text": "Hello! Please respond with just \"Hello from Gemini\" to test the API."
                }
            ]
        }
    ]
}'

response=$(curl -s -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$chat_payload" \
    -o chat_response.tmp \
    "$BASE_URL/v1beta/models/gemini-pro:generateContent")

if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ 聊天API调用成功${NC}"
    echo "响应内容："
    cat chat_response.tmp | jq '.candidates[0].content.parts[0].text' 2>/dev/null || cat chat_response.tmp
else
    echo -e "${RED}❌ 聊天API调用失败 (HTTP $response)${NC}"
    cat chat_response.tmp
fi

# 测试健康检查
echo -e "\n${YELLOW}6. 等待健康检查日志...${NC}"
echo "请查看服务器日志，应该能看到健康检查的输出"
echo "健康检查每30秒执行一次"

# 性能测试
echo -e "\n${YELLOW}7. 简单性能测试 (10个并发请求)...${NC}"
start_time=$(date +%s)
for i in {1..10}; do
    (curl -s -o /dev/null "$BASE_URL/status") &
done
wait
end_time=$(date +%s)
duration=$((end_time - start_time))
echo -e "${GREEN}✅ 10个并发请求完成，耗时: ${duration}秒${NC}"

# 清理临时文件
rm -f response.tmp chat_response.tmp

echo -e "\n${GREEN}🎉 测试完成！${NC}"
echo "如果所有测试都通过，说明负载均衡器工作正常"
echo -e "\n${YELLOW}监控建议：${NC}"
echo "- 访问 $BASE_URL/status 查看实时状态"
echo "- 观察服务器日志中的轮询和健康检查信息"
echo "- 监控API密钥的使用情况和失败次数"
