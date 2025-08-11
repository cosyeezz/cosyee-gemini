/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';

/**
 * 获取API Key轮询日志文件的路径（跨平台统一）
 */
export function getApiKeyRotationLogPath(): string {
  const homeDir = os.homedir();
  let logDir: string;

  switch (process.platform) {
    case 'win32':
      // Windows: %USERPROFILE%\.gemini-cli\logs\
      logDir = path.join(homeDir, '.gemini-cli', 'logs');
      break;
    case 'darwin':
      // macOS: ~/Library/Logs/gemini-cli/
      logDir = path.join(homeDir, 'Library', 'Logs', 'gemini-cli');
      break;
    default:
      // Linux/Unix: ~/.local/share/gemini-cli/logs/
      logDir = path.join(homeDir, '.local', 'share', 'gemini-cli', 'logs');
      break;
  }

  return path.join(logDir, 'api-key-rotation.log');
}

/**
 * 安全地写入日志文件（确保目录存在）
 */
export function safeLogWrite(message: string): void {
  try {
    const logPath = getApiKeyRotationLogPath();
    const logDir = path.dirname(logPath);
    
    // 确保目录存在
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
    
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] ${message}\n`;
    
    // 追加写入日志文件
    fs.appendFileSync(logPath, logEntry, 'utf8');
  } catch (error) {
    // 静默处理日志写入错误，避免影响主功能
    // console.error('Failed to write API key rotation log:', error);
  }
}
