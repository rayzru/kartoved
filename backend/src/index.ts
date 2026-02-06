// ============================================================================
// Backend Entry Point - Кэшка (BuyWhyWhy) Микросервис
// ============================================================================

import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger } from './middleware/requestLogger';
import { rateLimiter } from './middleware/rateLimiter';

// Routes
import authRoutes from './routes/auth.routes';
import ocrRoutes from './routes/ocr.routes';
import syncRoutes from './routes/sync.routes';
import aiRoutes from './routes/ai.routes';
import healthRoutes from './routes/health.routes';

// ============================================================================
// Application Setup
// ============================================================================

const app: Application = express();
const PORT = config.port;

// ============================================================================
// Middleware
// ============================================================================

// Security
app.use(helmet());
app.use(cors({
  origin: config.corsOrigin,
  credentials: true,
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression
app.use(compression());

// Request logging
app.use(requestLogger);

// Rate limiting
app.use('/api/', rateLimiter);

// ============================================================================
// Routes
// ============================================================================

app.use('/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/ocr', ocrRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/ai', aiRoutes);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
  });
});

// ============================================================================
// Error Handler
// ============================================================================

app.use(errorHandler);

// ============================================================================
// Server Start
// ============================================================================

const server = app.listen(PORT, () => {
  logger.info(`🚀 Backend микросервис запущен на порту ${PORT}`);
  logger.info(`📝 Environment: ${config.nodeEnv}`);
  logger.info(`🔗 Database: ${config.databaseUrl ? 'Connected' : 'Not configured'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

export default app;
