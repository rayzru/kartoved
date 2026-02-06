# Security Expert - Security Engineer

**Role:** Application Security & Compliance Specialist
**Expertise:** PCI-DSS, OWASP Top 10, encryption, authentication
**Experience:** 10+ years application security

---

## Картовед Security Requirements

### Critical Constraints
- ❌ NO full card numbers stored (PCI-DSS Level 1 avoidance)
- ❌ NO CVV codes stored
- ❌ NO plain-text passwords
- ✅ Only last 4 digits + bank name
- ✅ JWT authentication with refresh tokens
- ✅ Row-Level Security (RLS) in PostgreSQL

### Authentication Best Practices

```typescript
// Password hashing (if email/password auth)
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12;

async function hashPassword(plainPassword: string): Promise<string> {
    return bcrypt.hash(plainPassword, SALT_ROUNDS);
}

async function verifyPassword(plainPassword: string, hash: string): Promise<boolean> {
    return bcrypt.compare(plainPassword, hash);
}

// JWT tokens
import jwt from 'jsonwebtoken';

function generateAccessToken(userId: string): string {
    return jwt.sign(
        { userId, type: 'access' },
        process.env.JWT_SECRET!,
        { expiresIn: '15m' } // Short-lived
    );
}

function generateRefreshToken(userId: string): string {
    return jwt.sign(
        { userId, type: 'refresh' },
        process.env.JWT_REFRESH_SECRET!,
        { expiresIn: '7d' } // Long-lived
    );
}
```

### Input Validation (Prevent SQL Injection)

```typescript
import { z } from 'zod';

const MerchantDetectionSchema = z.object({
    wifi_ssid: z.string().max(255).optional(),
    wifi_bssid: z.string().regex(/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/).optional(),
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional()
});

router.post('/detect', async (req, res) => {
    try {
        const validated = MerchantDetectionSchema.parse(req.body);
        // Safe to use validated data
    } catch (error) {
        return res.status(400).json({ error: 'Invalid input' });
    }
});
```

### Rate Limiting (DDoS Protection)

```typescript
// See nodejs-backend.md for full implementation
// OCR endpoint: 20 requests/hour
// General API: 100 requests/15min
// Auth endpoints: 5 requests/15min (brute-force protection)
```

### Russian Data Localization Law

**Требования 152-ФЗ:**
- Personal data must be stored on servers in Russia
- User consent for data processing
- Right to data deletion

**Implementation:**
- VPS in Russia (Selectel, Timeweb, Yandex Cloud)
- Consent checkbox during registration
- `/api/user/delete-account` endpoint

---

**Last Updated:** 2026-02-07
