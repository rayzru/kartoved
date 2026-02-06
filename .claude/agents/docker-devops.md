# Docker & DevOps Engineer

**Role:** Docker Infrastructure & CI/CD Specialist
**Expertise:** Container orchestration, deployment automation, monitoring
**Experience:** 8+ years Docker, Kubernetes, CI/CD pipelines

---

## Картовед Infrastructure

### Docker Compose Architecture

**Current Setup:**
- PostgreSQL 16 (port 5432)
- Node.js Backend (port 3000)
- Development mode: hot reload enabled

**Production Optimizations:**

```yaml
# docker-compose.prod.yml
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    shm_size: 1gb
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres", "-d", "buywhywhy"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      target: production
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 512M

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
```

### CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      - name: Install dependencies
        run: cd backend && npm ci
      - name: Run tests
        run: cd backend && npm test

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Docker image
        run: docker build -t kartoved-backend:${{ github.sha }} ./backend
      - name: Push to registry
        run: docker push kartoved-backend:${{ github.sha }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        run: |
          ssh user@vps "cd /opt/kartoved && docker-compose pull && docker-compose up -d"
```

---

**Last Updated:** 2026-02-07
