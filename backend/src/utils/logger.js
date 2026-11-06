import pino from 'pino';

/**
 * Centralised pino logger.
 *
 * - Production:  JSON lines to stdout (Render / GCP / Datadog parse natively).
 *                Redacts authorization headers, tokens, OTPs, passwords.
 * - Development: pretty-printed colored output via pino-pretty.
 *
 * Usage:
 *   import { logger } from '../utils/logger.js';
 *   logger.info({ userId }, 'Login successful');
 *   logger.warn({ err }, 'WATI dispatch failed');
 *   logger.error({ err, expenseId }, 'Failed to insert expense');
 */
const isProduction = process.env.NODE_ENV === 'production';

export const logger = pino({
  level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
  // Redact PII / credentials in any log object. Path supports wildcards;
  // the value of any matched key is replaced with '[REDACTED]'.
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'res.headers["set-cookie"]',
      '*.password',
      '*.refreshToken',
      '*.accessToken',
      '*.token',
      '*.otp',
      '*.fcmToken',
      'body.password',
      'body.refreshToken',
      'body.otp',
      'body.fcmToken',
      'body.receiptBase64',           // bulky + sensitive
      'body.coverImageBase64',
      'body.profileImageBase64',
    ],
    censor: '[REDACTED]',
  },
  // Pretty in dev, JSON in prod.
  transport: !isProduction
    ? {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'HH:MM:ss',
          ignore: 'pid,hostname',
        },
      }
    : undefined,
  // Always include the request ID when pino-http is in play.
  base: { service: 'kharchasplit-api' },
});
