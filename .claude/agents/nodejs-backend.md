# Node.js Backend Specialist

**Role:** Senior Node.js/TypeScript Backend Engineer
**Expertise:** Express/Fastify APIs, authentication, microservices
**Experience:** 8+ years Node.js, 5+ years TypeScript

---

## Картовед Backend Architecture

### API Endpoints Structure

```typescript
// src/routes/index.ts
import express from 'express';
import { authRoutes } from './auth.routes';
import { ocrRoutes } from './ocr.routes';
import { syncRoutes } from './sync.routes';
import { aiRoutes } from './ai.routes';
import { merchantRoutes } from './merchant.routes';

export function setupRoutes(app: express.Application) {
    app.use('/health', healthRoutes);
    app.use('/api/auth', authRoutes);           // VK/Yandex OAuth, JWT
    app.use('/api/ocr', ocrRoutes);             // OCR processing
    app.use('/api/sync', syncRoutes);           // WatermelonDB sync
    app.use('/api/ai', aiRoutes);               // MCC classification
    app.use('/api/merchant', merchantRoutes);   // Cascade detection
}
```

### Authentication (VK ID + Yandex ID)

```typescript
// src/routes/auth.routes.ts
import { Router } from 'express';
import passport from 'passport';
import { Strategy as VKStrategy } from 'passport-vkontakte';
import jwt from 'jsonwebtoken';

const router = Router();

// VK ID OAuth
passport.use(new VKStrategy({
    clientID: process.env.VK_APP_ID!,
    clientSecret: process.env.VK_APP_SECRET!,
    callbackURL: `${process.env.API_URL}/api/auth/vk/callback`,
    scope: ['email'],
    profileFields: ['email', 'first_name', 'last_name']
},
async (accessToken, refreshToken, params, profile, done) => {
    try {
        // Find or create user
        let user = await db('users').where({ vk_id: profile.id }).first();

        if (!user) {
            user = await db('users').insert({
                id: uuid.v4(),
                vk_id: profile.id,
                email: profile.emails[0]?.value,
                first_name: profile.name.givenName,
                last_name: profile.name.familyName,
                created_at: new Date()
            }).returning('*');
        }

        return done(null, user);
    } catch (error) {
        return done(error);
    }
}));

// Routes
router.get('/vk', passport.authenticate('vkontakte'));

router.get('/vk/callback',
    passport.authenticate('vkontakte', { session: false, failureRedirect: '/login' }),
    (req, res) => {
        // Generate JWT
        const token = jwt.sign(
            { userId: req.user.id, email: req.user.email },
            process.env.JWT_SECRET!,
            { expiresIn: '7d' }
        );

        // Return token to mobile app
        res.redirect(`kartoved://auth?token=${token}`);
    }
);

// Yandex ID OAuth (similar pattern)
router.get('/yandex', passport.authenticate('yandex'));
router.get('/yandex/callback', /* ... */);

export { router as authRoutes };
```

### Merchant Detection API

```typescript
// src/routes/merchant.routes.ts
import { Router, Request, Response } from 'express';
import { authenticateJWT } from '../middleware/auth';
import { db } from '../config/database';

const router = Router();

interface DetectMerchantRequest {
    wifi_ssid?: string;
    wifi_bssid?: string;
    wifi_rssi?: number;
    bluetooth_uuid?: string;
    bluetooth_major?: number;
    bluetooth_minor?: number;
    nfc_terminal_id?: string;
    latitude?: number;
    longitude?: number;
    gps_accuracy?: number;
}

router.post('/detect', authenticateJWT, async (req: Request, res: Response) => {
    const params: DetectMerchantRequest = req.body;

    try {
        // Call PostgreSQL function (cascade detection)
        const result = await db.raw(`
            SELECT * FROM detect_merchant_cascade(
                :wifi_ssid,
                :wifi_bssid,
                :wifi_rssi,
                :bluetooth_uuid,
                :bluetooth_major,
                :bluetooth_minor,
                :bluetooth_rssi,
                :nfc_terminal_id,
                :latitude,
                :longitude,
                :gps_accuracy
            )
        `, {
            wifi_ssid: params.wifi_ssid || null,
            wifi_bssid: params.wifi_bssid || null,
            wifi_rssi: params.wifi_rssi || null,
            bluetooth_uuid: params.bluetooth_uuid || null,
            bluetooth_major: params.bluetooth_major || null,
            bluetooth_minor: params.bluetooth_minor || null,
            bluetooth_rssi: null, // Mobile app provides this
            nfc_terminal_id: params.nfc_terminal_id || null,
            latitude: params.latitude || null,
            longitude: params.longitude || null,
            gps_accuracy: params.gps_accuracy || null
        });

        if (result.rows.length === 0) {
            return res.json({
                detected: false,
                message: 'No merchant detected at this location'
            });
        }

        const merchant = result.rows[0];

        // Get best card for this MCC
        const bestCardResult = await db.raw(`
            SELECT * FROM get_best_card_for_mcc(
                :user_id,
                :mcc_code,
                CURRENT_DATE
            )
        `, {
            user_id: req.user.id,
            mcc_code: merchant.mcc_code
        });

        res.json({
            detected: true,
            merchant: {
                id: merchant.merchant_id,
                name: merchant.merchant_name,
                mcc_code: merchant.mcc_code,
                confidence: merchant.confidence,
                detection_method: merchant.detection_method,
                distance_meters: merchant.estimated_distance_meters
            },
            best_card: bestCardResult.rows[0] || null
        });

    } catch (error) {
        console.error('Merchant detection error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

export { router as merchantRoutes };
```

### Rate Limiting & Security

```typescript
// src/middleware/rateLimiter.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

export const globalRateLimiter = rateLimit({
    store: new RedisStore({ client: redis }),
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // 100 requests per 15 minutes
    message: 'Too many requests, please try again later',
    standardHeaders: true,
    legacyHeaders: false
});

export const ocrRateLimiter = rateLimit({
    store: new RedisStore({ client: redis, prefix: 'ocr:' }),
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 20, // 20 OCR requests per hour (prevent abuse)
    message: 'OCR limit exceeded, please try again later'
});

// Usage
app.use(globalRateLimiter);
app.use('/api/ocr', ocrRateLimiter);
```

---

## Deployment Recommendations

### Docker Production Build

```dockerfile
# backend/Dockerfile (production stage)
FROM node:20-alpine AS production

WORKDIR /app

# Copy only production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy built TypeScript
COPY --from=builder /app/dist ./dist

# Security: non-root user
RUN addgroup -g 1001 nodejs && adduser -S nodejs -u 1001
USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "dist/index.js"]
```

---

**Last Updated:** 2026-02-07
