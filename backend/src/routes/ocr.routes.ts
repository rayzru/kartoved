// ============================================================================
// OCR Routes (Распознавание скриншотов банковских приложений)
// ============================================================================

import { Router } from 'express';
import multer from 'multer';
import { ocrRateLimiter } from '../middleware/rateLimiter';

const router = Router();

// Multer configuration для загрузки изображений
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
  },
  fileFilter: (req, file, cb) => {
    // Разрешить только изображения
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  },
});

// TODO: Implement OCR service
// import { processScreenshot } from '../services/ocr.service';

/**
 * POST /api/ocr/bank-screenshot
 * Распознать скриншот банковского приложения
 *
 * Body: multipart/form-data
 *   - image: File (screenshot)
 *   - bank: string (optional, hints for better recognition)
 *
 * Response:
 *   {
 *     categories: [
 *       { mcc_code: "5411", name_ru: "Продукты", cashback_percent: 5.0 },
 *       { mcc_code: "5814", name_ru: "Кафе", cashback_percent: 3.0 }
 *     ],
 *     confidence: 0.92,
 *     method: "ml-kit" | "aws-textract"
 *   }
 */
router.post(
  '/bank-screenshot',
  ocrRateLimiter,
  upload.single('image'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No image file provided' });
      }

      // TODO: Implement OCR processing
      // const result = await processScreenshot(req.file.buffer, req.body.bank);

      res.status(501).json({
        message: 'OCR not implemented yet',
        receivedFile: {
          size: req.file.size,
          mimetype: req.file.mimetype,
        },
      });
    } catch (error) {
      res.status(500).json({
        error: 'OCR processing failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }
);

/**
 * GET /api/ocr/status
 * Получить статус OCR сервиса (ML Kit доступен? AWS credentials настроены?)
 */
router.get('/status', (req, res) => {
  const status = {
    mlKit: true, // Always available on-device
    awsTextract: !!(
      process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY
    ),
    yandexVision: !!(
      process.env.YANDEX_CLOUD_API_KEY && process.env.YANDEX_FOLDER_ID
    ),
  };

  res.json(status);
});

export default router;
