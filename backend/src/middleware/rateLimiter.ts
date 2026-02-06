// ============================================================================
// Rate Limiter Middleware
// ============================================================================

import rateLimit from 'express-rate-limit';

export const rateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 минут
  max: 100, // Максимум 100 запросов на IP
  message: {
    error: 'Too Many Requests',
    message: 'Слишком много запросов с вашего IP. Попробуйте позже.',
  },
  standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
  legacyHeaders: false, // Disable `X-RateLimit-*` headers
});

// Rate limiter для OCR endpoints (более строгий)
export const ocrRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 час
  max: 20, // Максимум 20 OCR запросов в час
  message: {
    error: 'Too Many OCR Requests',
    message: 'Превышен лимит OCR запросов. Попробуйте через час.',
  },
});

// Rate limiter для auth endpoints
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 минут
  max: 5, // Максимум 5 попыток входа
  message: {
    error: 'Too Many Login Attempts',
    message: 'Слишком много попыток входа. Попробуйте через 15 минут.',
  },
});
