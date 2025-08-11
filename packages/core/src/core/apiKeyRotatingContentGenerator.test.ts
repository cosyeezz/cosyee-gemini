/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ApiKeyRotatingContentGenerator } from './apiKeyRotatingContentGenerator.js';
import { ContentGeneratorConfig } from './contentGenerator.js';
import { Config } from '../config/config.js';

// Mock GoogleGenAI
vi.mock('@google/genai', () => ({
  GoogleGenAI: vi.fn().mockImplementation(() => ({
    models: {
      generateContent: vi.fn(),
      generateContentStream: vi.fn(),
      countTokens: vi.fn(),
      embedContent: vi.fn(),
    },
  })),
}));

describe('ApiKeyRotatingContentGenerator', () => {
  let mockConfig: ContentGeneratorConfig;
  let mockGcConfig: Config;
  
  beforeEach(() => {
    mockConfig = {
      model: 'gemini-pro',
      authType: 'gemini-api-key' as any,
      vertexai: false,
    };
    
    mockGcConfig = {} as Config;
    
    // Reset environment variables
    delete process.env.GEMINI_API_KEY;
  });

  it('should handle single API key without rotation', async () => {
    process.env.GEMINI_API_KEY = 'single-key';
    
    const generator = new ApiKeyRotatingContentGenerator(mockConfig, mockGcConfig);
    
    // Should work normally without any rotation logic
    expect(generator).toBeDefined();
  });

  it('should handle multiple API keys with comma separation', async () => {
    process.env.GEMINI_API_KEY = 'key1,key2,key3';
    
    const generator = new ApiKeyRotatingContentGenerator(mockConfig, mockGcConfig);
    
    expect(generator).toBeDefined();
  });

  it('should implement ContentGenerator interface', () => {
    process.env.GEMINI_API_KEY = 'test-key';
    
    const generator = new ApiKeyRotatingContentGenerator(mockConfig, mockGcConfig);
    
    expect(typeof generator.generateContent).toBe('function');
    expect(typeof generator.generateContentStream).toBe('function');
    expect(typeof generator.countTokens).toBe('function');
    expect(typeof generator.embedContent).toBe('function');
  });
});
