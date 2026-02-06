// ============================================================================
// Authentication Routes (VK ID, Yandex ID, Email)
// ============================================================================

import { Router } from 'express';
import { authRateLimiter } from '../middleware/rateLimiter';

const router = Router();

// TODO: Implement auth controllers
// import { login, register, refresh, logout } from '../controllers/auth.controller';

/**
 * POST /api/auth/register
 * Регистрация через Email + Password
 */
router.post('/register', authRateLimiter, (req, res) => {
  // TODO: Implement registration
  res.status(501).json({ message: 'Not implemented yet' });
});

/**
 * POST /api/auth/login
 * Вход через Email + Password
 */
router.post('/login', authRateLimiter, (req, res) => {
  // TODO: Implement login
  res.status(501).json({ message: 'Not implemented yet' });
});

/**
 * POST /api/auth/vk
 * OAuth вход через VK ID
 */
router.post('/vk', (req, res) => {
  // TODO: Implement VK OAuth
  res.status(501).json({ message: 'VK OAuth not implemented yet' });
});

/**
 * POST /api/auth/yandex
 * OAuth вход через Yandex ID
 */
router.post('/yandex', (req, res) => {
  // TODO: Implement Yandex OAuth
  res.status(501).json({ message: 'Yandex OAuth not implemented yet' });
});

/**
 * POST /api/auth/refresh
 * Обновить access token через refresh token
 */
router.post('/refresh', (req, res) => {
  // TODO: Implement token refresh
  res.status(501).json({ message: 'Not implemented yet' });
});

/**
 * POST /api/auth/logout
 * Logout пользователя
 */
router.post('/logout', (req, res) => {
  // TODO: Implement logout
  res.status(501).json({ message: 'Not implemented yet' });
});

export default router;
