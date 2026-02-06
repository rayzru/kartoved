// ============================================================================
// AI Routes (MCC classification, merchant recognition)
// ============================================================================

import { Router } from 'express';

const router = Router();

// TODO: Implement AI service
// import { classifyMerchant, findMccByName } from '../services/ai.service';

/**
 * POST /api/ai/classify-merchant
 * Определить MCC код по названию магазина через ИИ
 *
 * Body:
 *   {
 *     merchant_name: "Пятёрочка",
 *     context: "voice" | "manual" | "wifi" (optional)
 *   }
 *
 * Response:
 *   {
 *     mcc_code: "5411",
 *     category_name_ru: "Продукты, Супермаркеты",
 *     confidence: 0.95,
 *     common_merchants: ["Пятёрочка", "Магнит", "Перекрёсток"]
 *   }
 */
router.post('/classify-merchant', async (req, res) => {
  try {
    const { merchant_name, context } = req.body;

    if (!merchant_name) {
      return res.status(400).json({ error: 'merchant_name is required' });
    }

    // TODO: Implement AI classification
    // const result = await classifyMerchant(merchant_name, context);

    res.status(501).json({
      message: 'AI classification not implemented yet',
      received: { merchant_name, context },
    });
  } catch (error) {
    res.status(500).json({
      error: 'AI classification failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * POST /api/ai/voice-to-mcc
 * Распознать речь и определить MCC код
 *
 * Body: multipart/form-data
 *   - audio: File (voice recording)
 *
 * Response:
 *   {
 *     transcription: "Пятёрочка",
 *     mcc_code: "5411",
 *     category_name_ru: "Продукты, Супермаркеты",
 *     confidence: 0.88
 *   }
 */
router.post('/voice-to-mcc', async (req, res) => {
  // TODO: Implement voice recognition + MCC classification
  res.status(501).json({ message: 'Voice-to-MCC not implemented yet' });
});

/**
 * GET /api/ai/suggestions
 * Получить умные предложения для пользователя
 * (например, "Вы часто покупаете в Пятёрочке, выберите категорию Продукты")
 */
router.get('/suggestions', (req, res) => {
  // TODO: Implement AI suggestions
  res.status(501).json({ message: 'AI suggestions not implemented yet' });
});

export default router;
