package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"sync"
	"time"
)

// Config 配置结构
type Config struct {
	Port        int         `json:"port"`
	Backends    []Backend   `json:"backends"`
	HealthCheck HealthCheck `json:"health_check"`
	MaxFailures int         `json:"max_failures"`
	LogLevel    string      `json:"log_level"`
}

// Backend 后端服务配置
type Backend struct {
	URL    string `json:"url"`
	APIKey string `json:"api_key"`
}

// HealthCheck 健康检查配置
type HealthCheck struct {
	Enabled         bool `json:"enabled"`
	IntervalSeconds int  `json:"interval_seconds"`
	TimeoutSeconds  int  `json:"timeout_seconds"`
	Path            string `json:"path"`
}

// LoadBalancer 负载均衡器
type LoadBalancer struct {
	config       Config
	backends     []*BackendServer
	currentIndex int
	mutex        sync.RWMutex
}

// BackendServer 后端服务器状态
type BackendServer struct {
	Backend     Backend
	URL         *url.URL
	Proxy       *httputil.ReverseProxy
	Healthy     bool
	FailCount   int
	LastChecked time.Time
	mutex       sync.RWMutex
}

// NewLoadBalancer 创建负载均衡器
func NewLoadBalancer(config Config) (*LoadBalancer, error) {
	lb := &LoadBalancer{
		config:   config,
		backends: make([]*BackendServer, 0, len(config.Backends)),
	}

	// 初始化后端服务器
	for _, backend := range config.Backends {
		u, err := url.Parse(backend.URL)
		if err != nil {
			return nil, fmt.Errorf("invalid backend URL %s: %v", backend.URL, err)
		}

		// 创建反向代理
		proxy := httputil.NewSingleHostReverseProxy(u)
		
		// 自定义Director来处理API Key
		originalDirector := proxy.Director
		proxy.Director = func(req *http.Request) {
			originalDirector(req)
			// 添加API Key到查询参数
			q := req.URL.Query()
			q.Set("key", backend.APIKey)
			req.URL.RawQuery = q.Encode()
		}

		server := &BackendServer{
			Backend:     backend,
			URL:         u,
			Proxy:       proxy,
			Healthy:     true,
			FailCount:   0,
			LastChecked: time.Now(),
		}

		lb.backends = append(lb.backends, server)
	}

	return lb, nil
}

// GetNextHealthyBackend 获取下一个健康的后端服务器
func (lb *LoadBalancer) GetNextHealthyBackend() *BackendServer {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()

	if len(lb.backends) == 0 {
		return nil
	}

	// 简单轮询算法
	start := lb.currentIndex
	for i := 0; i < len(lb.backends); i++ {
		idx := (start + i) % len(lb.backends)
		backend := lb.backends[idx]
		
		backend.mutex.RLock()
		healthy := backend.Healthy
		backend.mutex.RUnlock()
		
		if healthy {
			lb.currentIndex = (idx + 1) % len(lb.backends)
			return backend
		}
	}

	// 如果没有健康的后端，返回第一个作为fallback
	if len(lb.backends) > 0 {
		log.Printf("警告: 没有健康的后端服务器，使用第一个作为fallback")
		lb.currentIndex = 1 % len(lb.backends)
		return lb.backends[0]
	}

	return nil
}

// HandleRequest 处理HTTP请求
func (lb *LoadBalancer) HandleRequest(w http.ResponseWriter, r *http.Request) {
	startTime := time.Now()
	
	backend := lb.GetNextHealthyBackend()
	if backend == nil {
		log.Printf("❌ 请求失败: 没有可用的后端服务器 - %s %s", r.Method, r.URL.Path)
		http.Error(w, "没有可用的后端服务器", http.StatusServiceUnavailable)
		return
	}

	// 获取API密钥的简化版本用于日志
	maskedKey := backend.Backend.APIKey
	if len(maskedKey) > 8 {
		maskedKey = maskedKey[:4] + "****" + maskedKey[len(maskedKey)-4:]
	}

	log.Printf("🔄 转发请求: %s %s -> %s (Key: %s)", 
		r.Method, r.URL.Path, backend.URL.Host, maskedKey)
	
	// 使用反向代理转发请求
	backend.Proxy.ServeHTTP(w, r)
	
	// 计算请求耗时
	duration := time.Since(startTime)
	log.Printf("✅ 请求完成: %s %s (耗时: %v)", r.Method, r.URL.Path, duration)
}

// MarkBackendUnhealthy 标记后端服务器为不健康
func (lb *LoadBalancer) MarkBackendUnhealthy(backend *BackendServer) {
	backend.mutex.Lock()
	defer backend.mutex.Unlock()
	
	backend.FailCount++
	if backend.FailCount >= lb.config.MaxFailures {
		backend.Healthy = false
		log.Printf("后端服务器 %s 被标记为不健康 (失败次数: %d)", 
			backend.URL.Host, backend.FailCount)
	}
}

// CheckHealth 健康检查
func (lb *LoadBalancer) CheckHealth(backend *BackendServer) {
	backend.mutex.Lock()
	defer backend.mutex.Unlock()

	client := &http.Client{
		Timeout: time.Duration(lb.config.HealthCheck.TimeoutSeconds) * time.Second,
	}

	// 构造健康检查URL
	checkURL := backend.Backend.URL + lb.config.HealthCheck.Path + "?key=" + backend.Backend.APIKey
	
	resp, err := client.Get(checkURL)
	if err != nil {
		backend.FailCount++
		if backend.FailCount >= lb.config.MaxFailures {
			backend.Healthy = false
		}
		log.Printf("健康检查失败 %s: %v (失败次数: %d)", 
			backend.URL.Host, err, backend.FailCount)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		// 健康检查成功，重置状态
		wasUnhealthy := !backend.Healthy
		backend.Healthy = true
		backend.FailCount = 0
		backend.LastChecked = time.Now()
		
		if wasUnhealthy {
			log.Printf("🟢 后端恢复健康: %s", backend.URL.Host)
		} else {
			log.Printf("✅ 健康检查成功: %s", backend.URL.Host)
		}
	} else {
		backend.FailCount++
		if backend.FailCount >= lb.config.MaxFailures {
			backend.Healthy = false
			log.Printf("🔴 后端服务器不健康: %s - HTTP %d (失败次数: %d/%d)", 
				backend.URL.Host, resp.StatusCode, backend.FailCount, lb.config.MaxFailures)
		} else {
			log.Printf("⚠️  健康检查失败: %s - HTTP %d (失败次数: %d/%d)", 
				backend.URL.Host, resp.StatusCode, backend.FailCount, lb.config.MaxFailures)
		}
	}
}

// StartHealthCheck 启动健康检查
func (lb *LoadBalancer) StartHealthCheck() {
	if !lb.config.HealthCheck.Enabled {
		log.Println("健康检查已禁用")
		return
	}

	interval := time.Duration(lb.config.HealthCheck.IntervalSeconds) * time.Second
	ticker := time.NewTicker(interval)
	
	log.Printf("启动健康检查，间隔: %v", interval)
	
	go func() {
		for range ticker.C {
			for _, backend := range lb.backends {
				go lb.CheckHealth(backend)
			}
		}
	}()
}

// GetStatus 获取状态信息
func (lb *LoadBalancer) GetStatus(w http.ResponseWriter, r *http.Request) {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()

	status := make(map[string]interface{})
	backends := make([]map[string]interface{}, 0)

	for i, backend := range lb.backends {
		backend.mutex.RLock()
		backendInfo := map[string]interface{}{
			"index":        i,
			"url":          backend.Backend.URL,
			"healthy":      backend.Healthy,
			"fail_count":   backend.FailCount,
			"last_checked": backend.LastChecked.Format("2006-01-02 15:04:05"),
		}
		backend.mutex.RUnlock()
		backends = append(backends, backendInfo)
	}

	status["backends"] = backends
	status["current_index"] = lb.currentIndex
	status["timestamp"] = time.Now().Format("2006-01-02 15:04:05")

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

// LoadConfig 加载配置文件
func LoadConfig(filename string) (Config, error) {
	var config Config
	
	file, err := os.Open(filename)
	if err != nil {
		return config, err
	}
	defer file.Close()

	bytes, err := io.ReadAll(file)
	if err != nil {
		return config, err
	}

	err = json.Unmarshal(bytes, &config)
	return config, err
}

func main() {
	// 加载配置
	config, err := LoadConfig("config.json")
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}

	// 创建负载均衡器
	lb, err := NewLoadBalancer(config)
	if err != nil {
		log.Fatalf("创建负载均衡器失败: %v", err)
	}

	// 启动健康检查
	lb.StartHealthCheck()

	// 设置路由
	http.HandleFunc("/", lb.HandleRequest)
	http.HandleFunc("/status", lb.GetStatus)

	// 启动服务器
	addr := fmt.Sprintf(":%d", config.Port)
	log.Printf("🚀 Gemini代理服务器启动在端口 %d", config.Port)
	log.Printf("📊 状态页面: http://localhost%s/status", addr)
	log.Printf("🔧 健康检查: %v (间隔: %ds)", config.HealthCheck.Enabled, config.HealthCheck.IntervalSeconds)
	log.Printf("⚡ 最大失败次数: %d", config.MaxFailures)
	log.Printf("📝 日志级别: %s", config.LogLevel)
	
	// 输出后端服务器信息
	log.Printf("🌐 配置了 %d 个后端服务器:", len(config.Backends))
	for i, backend := range config.Backends {
		// 隐藏API Key的敏感信息
		maskedKey := backend.APIKey
		if len(maskedKey) > 8 {
			maskedKey = maskedKey[:4] + "****" + maskedKey[len(maskedKey)-4:]
		}
		log.Printf("  [%d] %s (Key: %s)", i, backend.URL, maskedKey)
	}
	
	log.Printf("🎯 负载均衡算法: 轮询 (Round Robin)")
	log.Printf("📡 代理模式: 透明转发 + API密钥注入")

	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("服务器启动失败: %v", err)
	}
}
