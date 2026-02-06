# ============================================================================
# Multi-stage Dockerfile для Backend Микросервиса
# ============================================================================
#
# Stages:
# 1. base - общая база с Node.js
# 2. development - для локальной разработки с hot reload
# 3. builder - компиляция TypeScript
# 4. production - минимальный production image
#
# Build commands:
#   docker build --target development -t buywhywhy-backend:dev .
#   docker build --target production -t buywhywhy-backend:prod .
#
# ============================================================================

# ==========================================================================
# Stage 1: Base
# ==========================================================================
FROM node:20-alpine AS base

WORKDIR /app

# Установить зависимости для нативных модулей
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    curl

# ==========================================================================
# Stage 2: Development (для локальной разработки)
# ==========================================================================
FROM base AS development

ENV NODE_ENV=development

# Копировать package files
COPY package*.json ./

# Установить все зависимости (включая devDependencies)
RUN npm ci

# Копировать исходный код
COPY . .

# Открыть порт
EXPOSE 3000

# Запустить с hot reload (ts-node-dev или nodemon)
CMD ["npm", "run", "dev"]

# ==========================================================================
# Stage 3: Builder (компиляция TypeScript)
# ==========================================================================
FROM base AS builder

WORKDIR /app

# Копировать package files
COPY package*.json ./

# Установить зависимости
RUN npm ci

# Копировать исходный код
COPY . .

# Скомпилировать TypeScript
RUN npm run build

# Удалить devDependencies
RUN npm prune --production

# ==========================================================================
# Stage 4: Production
# ==========================================================================
FROM node:20-alpine AS production

ENV NODE_ENV=production

WORKDIR /app

# Создать non-root пользователя
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Копировать скомпилированный код и node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Переключиться на non-root пользователя
USER nodejs

# Открыть порт
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Запустить приложение
CMD ["node", "dist/index.js"]
