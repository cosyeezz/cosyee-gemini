#!/bin/bash

# Gemini代理负载均衡器安装脚本

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🚀 Gemini代理负载均衡器安装脚本"
echo "================================="

# 检查Go是否安装
echo -e "\n${YELLOW}1. 检查Go语言环境...${NC}"
if command -v go &> /dev/null; then
    GO_VERSION=$(go version | cut -d' ' -f3)
    echo -e "${GREEN}✅ Go已安装: $GO_VERSION${NC}"
else
    echo -e "${RED}❌ Go未安装${NC}"
    echo "请访问 https://golang.org/dl/ 下载安装Go语言"
    echo "或运行以下命令 (Linux):"
    echo "wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz"
    echo "sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz"
    echo "export PATH=\$PATH:/usr/local/go/bin"
    exit 1
fi

# 检查配置文件
echo -e "\n${YELLOW}2. 检查配置文件...${NC}"
if [ -f "config.json" ]; then
    echo -e "${GREEN}✅ 配置文件存在${NC}"
    
    # 检查是否包含示例密钥
    if grep -q "your-gemini-api-key" config.json; then
        echo -e "${RED}⚠️  请先配置您的Gemini API密钥${NC}"
        echo "编辑 config.json 文件，替换示例密钥为真实密钥"
        read -p "是否现在编辑配置文件? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} config.json
        fi
    fi
else
    echo -e "${RED}❌ 配置文件不存在${NC}"
    exit 1
fi

# 编译程序
echo -e "\n${YELLOW}3. 编译程序...${NC}"
if go build -o gemini-proxy main.go; then
    echo -e "${GREEN}✅ 编译成功${NC}"
    chmod +x gemini-proxy
else
    echo -e "${RED}❌ 编译失败${NC}"
    exit 1
fi

# 测试配置
echo -e "\n${YELLOW}4. 测试配置...${NC}"
if ./gemini-proxy &
then
    PROXY_PID=$!
    sleep 3
    
    # 测试状态接口
    if curl -s http://localhost:8000/status > /dev/null; then
        echo -e "${GREEN}✅ 服务启动成功${NC}"
        kill $PROXY_PID
    else
        echo -e "${RED}❌ 服务启动失败${NC}"
        kill $PROXY_PID 2>/dev/null
        exit 1
    fi
else
    echo -e "${RED}❌ 程序启动失败${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 安装完成！${NC}"
echo -e "\n${YELLOW}使用方法:${NC}"
echo "1. 启动服务: ./gemini-proxy"
echo "2. 查看状态: curl http://localhost:8000/status"
echo "3. 运行测试: ./test.sh"
echo "4. 后台运行: nohup ./gemini-proxy > proxy.log 2>&1 &"

echo -e "\n${YELLOW}配置文件位置:${NC} config.json"
echo -e "${YELLOW}日志输出:${NC} 控制台 (可重定向到文件)"
echo -e "${YELLOW}状态页面:${NC} http://localhost:8000/status"

echo -e "\n${GREEN}准备就绪！您现在可以启动负载均衡器了。${NC}"
