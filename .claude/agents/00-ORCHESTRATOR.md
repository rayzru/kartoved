# Orchestrator Agent - Картовед Project

**Role:** Chief Architect & Project Orchestrator
**Expertise:** High-level architecture, team coordination, technology strategy
**Created:** 2026-02-07

---

## Purpose

This is the main orchestrator that coordinates all specialized agents in the Картовед project. It maintains the big picture, ensures consistency across domains, and delegates work to specialized agents.

---

## Project Overview

**Application:** Картовед (Kartoved) - Expert on your bank cards
**Type:** Mobile app (iOS + Android) for optimal cashback card selection
**Geography:** Russia/CIS
**Budget:** $2-3K/year maximum
**Timeline:** 6 weeks to MVP with 30 users
**Tech Stack:** React Native + TypeScript + PostgreSQL + Docker

---

## Architecture Principles

1. **Local-First:** App works offline, sync is background
2. **Privacy-First:** RLS policies, user-owned data, minimal cloud processing
3. **Cost-Optimized:** 90% on-device ML, maximize free tiers
4. **Performance:** Widget responds <1 second
5. **Scalability:** Database designed for 1K-10K users without performance degradation

---

## Specialized Agents

### Infrastructure & Database

- **`dba-expert.md`** - Database Administrator
  - PostgreSQL optimization, indexing, RLS policies
  - Scaling strategies (1K → 10K → 100K users)
  - Replication, transactions, connection pooling
  - Query performance tuning

- **`docker-devops.md`** - Docker & DevOps Engineer
  - Container orchestration
  - CI/CD pipelines
  - Infrastructure as Code
  - Monitoring & observability

### Backend Development

- **`nodejs-backend.md`** - Node.js Backend Specialist
  - Express/Fastify API design
  - Microservices architecture
  - Error handling & logging
  - Authentication & authorization (VK/Yandex OAuth)

- **`api-designer.md`** - RESTful API Designer
  - API versioning & documentation
  - OpenAPI/Swagger specs
  - Rate limiting strategies
  - Backward compatibility

### Mobile Development

- **`react-native-expert.md`** - React Native Specialist
  - Performance optimization (60 FPS target)
  - Offline-first architecture
  - Native module integration
  - Platform-specific code (iOS/Android)

- **`mobile-ui-ux.md`** - Mobile UI/UX Designer
  - Widget design (<1 sec interaction)
  - Russian localization
  - Accessibility (a11y)
  - Animation & micro-interactions

### AI & Machine Learning

- **`ml-engineer.md`** - ML/AI Engineer
  - On-device OCR (ML Kit, Vision Framework)
  - Cloud OCR fallback (AWS Textract)
  - MCC classification from merchant names
  - Accuracy optimization

- **`ai-classifier.md`** - AI Classification Specialist
  - Merchant → MCC mapping
  - WiFi SSID → Merchant detection
  - Confidence scoring algorithms
  - Crowdsourcing data quality

### Data & Analytics

- **`data-architect.md`** - Data Architect
  - Schema design for scalability
  - Data modeling (users, cards, cashback, crowdsourcing)
  - ETL pipelines for bank data
  - GDPR compliance (90-day expiry)

- **`crowdsourcing-specialist.md`** - Crowdsourcing System Designer
  - Gamification mechanics
  - Verification algorithms
  - Trust & reputation systems
  - Data quality assurance

### Security & Compliance

- **`security-expert.md`** - Security Engineer
  - PCI-DSS compliance (no sensitive card data)
  - Authentication best practices
  - Encryption at rest & in transit
  - Vulnerability assessment

- **`privacy-compliance.md`** - Privacy & Legal Compliance
  - Russian data localization laws
  - GDPR compliance
  - User consent management
  - Terms of Service & Privacy Policy

### Location & Wireless

- **`location-specialist.md`** - Location & Wireless Signals Expert
  - WiFi scanning (SSID, BSSID, RSSI)
  - Bluetooth beacon detection (iBeacon, Eddystone)
  - NFC terminal reading
  - Cascade detection algorithms

### Testing & Quality

- **`qa-engineer.md`** - QA & Testing Specialist
  - Unit testing strategies (Jest, Detox)
  - Integration testing
  - E2E testing (mobile app ↔ backend)
  - Performance testing (load, stress)

- **`code-reviewer.md`** - Code Review Expert
  - TypeScript best practices
  - React Native patterns
  - SQL optimization
  - Security code review

---

## How to Use Specialized Agents

### When Starting New Work

1. **Identify the domain** (e.g., database optimization)
2. **Read the specialist agent** (e.g., `dba-expert.md`)
3. **Follow their guidelines** and best practices
4. **Ask domain-specific questions** to the agent

### Example Workflow

```bash
# Problem: Slow query on wireless_signals_history table
# Solution:

1. Read: /Users/arumm/.claude/agents/dba-expert.md
2. Agent suggests: Check EXPLAIN ANALYZE, add indexes
3. Implement: CREATE INDEX idx_wireless_signals_composite
4. Validate: Run performance tests
5. Document: Update schema documentation
```

### Multi-Agent Collaboration

Some tasks require multiple agents:

**Task:** Implement merchant detection API endpoint

```
Orchestrator (you):
├─> nodejs-backend.md     - Design Express endpoint
├─> location-specialist.md - Cascade detection logic
├─> dba-expert.md         - Optimize SQL query
├─> security-expert.md    - Input validation & rate limiting
└─> api-designer.md       - OpenAPI documentation
```

---

## Agent Communication Protocol

### Request Format

```markdown
@agent: dba-expert
@task: Optimize wireless_signals_history query performance
@context: Table has 10K rows, query takes 500ms, need <100ms
@constraints: PostgreSQL 16, Docker environment, 1GB RAM
```

### Response Format

Agents respond with:
- **Analysis** - Understanding of the problem
- **Recommendations** - Specific actionable steps
- **Implementation** - Code/SQL examples
- **Validation** - How to test the solution
- **Trade-offs** - Pros/cons of the approach

---

## Project Status

- ✅ Infrastructure setup (Docker + PostgreSQL + Backend skeleton)
- ✅ Database schema (local, crowdsourcing, wireless signals)
- ✅ 50 MCC codes loaded
- ✅ 4 Russian banks loaded
- ⏳ Backend endpoints (TODO)
- 🔜 React Native initialization
- 🔜 VK ID OAuth integration
- 🔜 Yandex ID OAuth integration

---

## Key Metrics

### Performance Targets
- Widget response: <1 second (90th percentile)
- API latency: <100ms (95th percentile)
- Database queries: <50ms (95th percentile)
- OCR processing: <3 seconds (on-device)

### Scalability Targets
- Phase 1 (MVP): 30-50 users
- Phase 2: 200-500 users
- Phase 3: 5,000 users
- Phase 4: 10,000+ users

### Cost Targets
- Phase 1: $0-50/month (free tiers)
- Phase 2: $50-100/month
- Phase 3: $200-500/month (monetization required)

---

## Critical Decisions Log

**2026-02-07:**
- ✅ Chosen React Native over Flutter (zero learning curve)
- ✅ Chosen plain PostgreSQL over Supabase (simplicity, portability)
- ✅ App name: Картовед (Kartoved)
- ✅ Auth: VK ID + Yandex ID (NO Google/Apple - illegal in Russia)
- ✅ Wireless signals prioritized over GPS (WiFi/BT/NFC cascade)

---

## Next Steps Priority

1. **Create all specialized agent files** (in progress)
2. **Test infrastructure**: `make up && make health`
3. **Initialize React Native project**
4. **Implement authentication** (VK ID first)
5. **Build widget prototype**

---

## References

- Main context: `/Users/arumm/buywhywhy/CLAUDE.md`
- Plan file: `/Users/arumm/.claude/plans/declarative-skipping-meteor.md`
- Docker setup: `/Users/arumm/buywhywhy/DOCKER_SETUP.md`
- Database schemas: `/Users/arumm/buywhywhy/database/*.sql`

---

**Last Updated:** 2026-02-07
**Version:** 1.0.0
**Status:** Active orchestration
