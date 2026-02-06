// ============================================================================
// Health Check Routes
// ============================================================================

import { Router, Request, Response } from 'express';
import { Pool } from 'pg';
import { config } from '../config';

const router = Router();

// Создать connection pool для health check
const pool = new Pool({
  connectionString: config.databaseUrl,
});

/**
 * GET /health
 * Health check endpoint для Docker healthcheck и мониторинга
 */
router.get('/', async (req: Request, res: Response) => {
  try {
    // Проверить подключение к БД
    const dbCheck = await pool.query('SELECT NOW()');
    const dbOk = dbCheck.rows.length > 0;

    const health = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.nodeEnv,
      database: dbOk ? 'connected' : 'disconnected',
      version: process.env.npm_package_version || '1.0.0',
    };

    res.status(200).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * GET /health/readiness
 * Kubernetes readiness probe
 */
router.get('/readiness', async (req: Request, res: Response) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ ready: true });
  } catch (error) {
    res.status(503).json({ ready: false });
  }
});

/**
 * GET /health/liveness
 * Kubernetes liveness probe
 */
router.get('/liveness', (req: Request, res: Response) => {
  res.status(200).json({ alive: true });
});

export default router;
