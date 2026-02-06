// ============================================================================
// Configuration Management
// ============================================================================

import dotenv from 'dotenv';

dotenv.config();

interface Config {
  nodeEnv: string;
  port: number;
  databaseUrl: string;
  corsOrigin: string | string[];

  // JWT
  jwtSecret: string;
  jwtRefreshSecret: string;
  jwtExpiresIn: string;
  jwtRefreshExpiresIn: string;

  // VK OAuth
  vkAppId: string;
  vkSecureKey: string;

  // Yandex OAuth
  yandexClientId: string;
  yandexClientSecret: string;

  // AWS (для OCR fallback)
  awsAccessKeyId?: string;
  awsSecretAccessKey?: string;
  awsRegion: string;

  // Yandex Cloud (для OCR/AI)
  yandexCloudApiKey?: string;
  yandexFolderId?: string;
}

const getEnv = (key: string, defaultValue?: string): string => {
  const value = process.env[key] || defaultValue;
  if (!value && !defaultValue) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value as string;
};

export const config: Config = {
  nodeEnv: getEnv('NODE_ENV', 'development'),
  port: parseInt(getEnv('PORT', '3000'), 10),
  databaseUrl: getEnv('DATABASE_URL'),
  corsOrigin: getEnv('CORS_ORIGIN', '*'),

  // JWT
  jwtSecret: getEnv('JWT_SECRET'),
  jwtRefreshSecret: getEnv('JWT_REFRESH_SECRET'),
  jwtExpiresIn: getEnv('JWT_EXPIRES_IN', '15m'),
  jwtRefreshExpiresIn: getEnv('JWT_REFRESH_EXPIRES_IN', '7d'),

  // VK OAuth
  vkAppId: getEnv('VK_APP_ID', ''),
  vkSecureKey: getEnv('VK_SECURE_KEY', ''),

  // Yandex OAuth
  yandexClientId: getEnv('YANDEX_CLIENT_ID', ''),
  yandexClientSecret: getEnv('YANDEX_CLIENT_SECRET', ''),

  // AWS
  awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID,
  awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  awsRegion: getEnv('AWS_REGION', 'eu-central-1'),

  // Yandex Cloud
  yandexCloudApiKey: process.env.YANDEX_CLOUD_API_KEY,
  yandexFolderId: process.env.YANDEX_FOLDER_ID,
};
