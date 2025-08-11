/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import {
  CountTokensParameters,
  CountTokensResponse,
  EmbedContentParameters,
  EmbedContentResponse,
  GenerateContentParameters,
  GenerateContentResponse,
  GoogleGenAI,
} from '@google/genai';
import * as fs from 'fs';
import { ContentGenerator, ContentGeneratorConfig } from './contentGenerator.js';
import { Config } from '../config/config.js';

/**
 * API Key 轮询管理器
 */
class ApiKeyManager {
  private keys: string[];
  private currentIndex = 0;

  constructor(apiKeyString: string) {
    this.keys = apiKeyString.split(',').map(k => k.trim()).filter(Boolean);
  }

  getCurrentKey(): string {
    return this.keys[this.currentIndex] || '';
  }

  rotateToNext(): void {
    if (this.keys.length > 1) {
      this.currentIndex = (this.currentIndex + 1) % this.keys.length;
    }
  }

  hasMultipleKeys(): boolean {
    return this.keys.length > 1;
  }

  getKeyCount(): number {
    return this.keys.length;
  }
}

/**
 * 装饰器：为ContentGenerator添加API Key轮询和故障转移功能
 * 遵循单一职责原则，只负责API Key管理，不处理日志记录
 */
export class ApiKeyRotatingContentGenerator implements ContentGenerator {
  private keyManager: ApiKeyManager;
  private createGenerator: () => ContentGenerator;

  constructor(
    private config: ContentGeneratorConfig,
    private gcConfig: Config
  ) {
    const apiKeyString = process.env.GEMINI_API_KEY || config.apiKey || '';
    this.keyManager = new ApiKeyManager(apiKeyString);
    
    // 保存创建 ContentGenerator 的工厂函数
    this.createGenerator = () => {
      const version = process.env.CLI_VERSION || process.version;
      const googleGenAI = new GoogleGenAI({
        apiKey: this.keyManager.getCurrentKey(),
        vertexai: config.vertexai,
        httpOptions: {
          headers: {
            'User-Agent': `GeminiCLI/${version} (${process.platform}; ${process.arch})`,
          },
        },
      });
      return googleGenAI.models;
    };
  }

  /**
   * 核心重试逻辑 - 通用的重试框架，不包含具体业务代码
   */
  private async executeWithRetry<T>(
    operation: (generator: ContentGenerator) => Promise<T>
  ): Promise<T> {
    if (!this.keyManager.hasMultipleKeys()) {
      // 单Key情况，直接执行，不需要轮询
      const generator = this.createGenerator();
      return operation(generator);
    }

    const maxAttempts = this.keyManager.getKeyCount();
    let lastError: any;
    
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      const generator = this.createGenerator();
      
      try {
        const result = await operation(generator);
        
        // 成功后轮询到下一个Key（负载均衡）
        this.keyManager.rotateToNext();
        fs.appendFileSync('rotation.log', `[SUCCESS] Request succeeded. Next request will use key ending with "...${this.keyManager.getCurrentKey().slice(-4)}"\n`);
        
        return result;
      } catch (error) {
        lastError = error;
        
        // 检查是否是认证错误
        if (this.isAuthenticationError(error) && attempt < maxAttempts - 1) {
          const oldKey = this.keyManager.getCurrentKey();
          this.keyManager.rotateToNext();
          fs.appendFileSync('rotation.log', `[FAILURE] API Key ending with "...${oldKey.slice(-4)}" failed. Attempting key ending with "...${this.keyManager.getCurrentKey().slice(-4)}"\n`);
          continue;
        }
        
        throw error;
      }
    }
    
    throw lastError;
  }

  /**
   * 判断是否是认证错误
   */
  private isAuthenticationError(error: any): boolean {
    const status = error?.status || error?.response?.status;
    return status === 401 || status === 403;
  }

  // 接口实现 - 只是简单的委托，不重写业务逻辑
  async generateContent(
    req: GenerateContentParameters,
    userPromptId: string,
  ): Promise<GenerateContentResponse> {
    return this.executeWithRetry(
      generator => generator.generateContent(req, userPromptId)
    );
  }

  async generateContentStream(
    req: GenerateContentParameters,
    userPromptId: string,
  ): Promise<AsyncGenerator<GenerateContentResponse>> {
    return this.executeWithRetry(
      generator => generator.generateContentStream(req, userPromptId)
    );
  }

  async countTokens(req: CountTokensParameters): Promise<CountTokensResponse> {
    return this.executeWithRetry(
      generator => generator.countTokens(req)
    );
  }

  async embedContent(req: EmbedContentParameters): Promise<EmbedContentResponse> {
    return this.executeWithRetry(
      generator => generator.embedContent(req)
    );
  }
}
