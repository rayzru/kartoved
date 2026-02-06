// ============================================================================
// Sync Routes (Синхронизация данных между мобильным приложением и бэкендом)
// ============================================================================

import { Router } from 'express';

const router = Router();

// TODO: Implement sync service
// import { pushChanges, pullChanges } from '../services/sync.service';

/**
 * POST /api/sync/push
 * Отправить локальные изменения на сервер
 *
 * Body:
 *   {
 *     changes: [
 *       { table: "bank_cards", operation: "INSERT", data: {...} },
 *       { table: "card_cashback_rates", operation: "UPDATE", data: {...} }
 *     ],
 *     last_sync_at: "2026-02-07T12:00:00Z"
 *   }
 *
 * Response:
 *   {
 *     success: true,
 *     conflicts: [],
 *     server_timestamp: "2026-02-07T12:05:00Z"
 *   }
 */
router.post('/push', (req, res) => {
  // TODO: Implement push sync
  res.status(501).json({ message: 'Push sync not implemented yet' });
});

/**
 * POST /api/sync/pull
 * Получить изменения с сервера
 *
 * Body:
 *   {
 *     last_sync_at: "2026-02-07T12:00:00Z",
 *     user_id: "uuid"
 *   }
 *
 * Response:
 *   {
 *     changes: [
 *       { table: "russian_banks", operation: "UPDATE", data: {...} },
 *       { table: "mcc_codes", operation: "INSERT", data: {...} }
 *     ],
 *     server_timestamp: "2026-02-07T12:05:00Z",
 *     has_more: false
 *   }
 */
router.post('/pull', (req, res) => {
  // TODO: Implement pull sync
  res.status(501).json({ message: 'Pull sync not implemented yet' });
});

/**
 * GET /api/sync/status
 * Получить статус последней синхронизации пользователя
 */
router.get('/status', (req, res) => {
  // TODO: Implement sync status
  res.status(501).json({ message: 'Sync status not implemented yet' });
});

export default router;
