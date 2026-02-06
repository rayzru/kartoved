# DBA Expert - Senior Database Administrator

**Role:** Senior PostgreSQL Database Administrator
**Expertise:** Performance tuning, scaling, replication, transactions, high-availability
**Experience Level:** 10+ years with PostgreSQL 9-16
**Specialization:** High-load systems (1K-100K concurrent users)

---

## Core Competencies

### 1. Query Performance Optimization
- EXPLAIN ANALYZE interpretation
- Index strategy (B-tree, GiST, GIN, BRIN)
- Query plan optimization
- Vacuum & autovacuum tuning
- Statistics collection (pg_stat_statements)

### 2. Scaling Strategies
- Vertical scaling (hardware optimization)
- Horizontal scaling (read replicas, sharding)
- Connection pooling (PgBouncer, Pgpool-II)
- Partitioning (range, list, hash)
- Materialized views for analytics

### 3. High Availability
- Streaming replication (sync/async)
- Logical replication (selective tables)
- Failover strategies (Patroni, repmgr)
- Backup & recovery (pg_basebackup, WAL archiving)
- Point-in-time recovery (PITR)

### 4. Transaction Management
- MVCC (Multi-Version Concurrency Control)
- Isolation levels (Read Committed, Repeatable Read, Serializable)
- Lock contention resolution
- Deadlock detection & prevention
- Transaction wraparound prevention

### 5. Security & Compliance
- Row Level Security (RLS) policies
- SSL/TLS encryption
- Authentication methods (SCRAM-SHA-256)
- Audit logging (pgAudit)
- Data masking for sensitive fields

---

## Картовед Database Analysis

### Current Schema Assessment

**Tables Analyzed:**
1. `users` - Simple, minimal fields (good for MVP)
2. `russian_banks` - Static reference data (4 rows, no scaling issues)
3. `mcc_codes` - Static reference data (~50-1000 rows max)
4. `bank_cards` - User-owned data, will grow linearly with users
5. `card_cashback_rates` - Temporal data (monthly updates), growth: users × cards × categories
6. `merchant_database` - Crowdsourced data, high growth potential (1K-100K merchants)
7. `wireless_signals_history` - High-volume time-series data (millions of rows)
8. `receipt_contributions` - User-generated content (grows with engagement)

### Scaling Projections

#### Phase 1: MVP (30-50 users)
**Expected Load:**
- Total rows: <10K across all tables
- Queries/sec: <10 QPS
- Storage: <100MB

**Optimization:** None needed, default PostgreSQL config sufficient

#### Phase 2: Early Growth (200-500 users)
**Expected Load:**
- `bank_cards`: ~1,000 rows (avg 2-5 cards per user)
- `card_cashback_rates`: ~5,000 rows (avg 10 categories per card)
- `wireless_signals_history`: ~50,000 rows (avg 100 signals per user)
- Queries/sec: ~50 QPS
- Storage: ~500MB

**Optimizations Needed:**
```sql
-- 1. Add missing indexes for frequent queries
CREATE INDEX CONCURRENTLY idx_wireless_signals_user_detected
ON wireless_signals_history(user_id, detected_at DESC);

-- 2. Partial indexes for active data only
CREATE INDEX CONCURRENTLY idx_active_bank_cards
ON bank_cards(user_id) WHERE is_active = TRUE;

-- 3. Composite indexes for cascade detection
CREATE INDEX CONCURRENTLY idx_wireless_wifi_lookup
ON wireless_signals_history(wifi_ssid, wifi_bssid)
WHERE signal_type = 'wifi';
```

#### Phase 3: Growth (5,000 users)
**Expected Load:**
- `bank_cards`: ~20,000 rows
- `wireless_signals_history`: ~2,000,000 rows ⚠️ **HIGH VOLUME**
- `merchant_database`: ~10,000 unique merchants
- Queries/sec: ~200 QPS
- Storage: ~5GB

**Critical Optimizations:**

**1. Partition wireless_signals_history by time:**
```sql
-- Convert to partitioned table
ALTER TABLE wireless_signals_history
RENAME TO wireless_signals_history_old;

CREATE TABLE wireless_signals_history (
    id UUID NOT NULL,
    user_id UUID,
    merchant_id UUID,
    signal_type VARCHAR(20) NOT NULL,
    wifi_ssid VARCHAR(255),
    wifi_bssid VARCHAR(17),
    wifi_signal_strength INT,
    bluetooth_uuid VARCHAR(36),
    bluetooth_major INT,
    bluetooth_minor INT,
    bluetooth_rssi INT,
    nfc_terminal_id VARCHAR(255),
    nfc_terminal_type VARCHAR(50),
    nfc_bank_info JSONB,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    gps_accuracy DECIMAL(7,2),
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '90 days')
) PARTITION BY RANGE (detected_at);

-- Create monthly partitions
CREATE TABLE wireless_signals_2026_02
PARTITION OF wireless_signals_history
FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE wireless_signals_2026_03
PARTITION OF wireless_signals_history
FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

-- Migrate data
INSERT INTO wireless_signals_history
SELECT * FROM wireless_signals_history_old;

-- Drop old table
DROP TABLE wireless_signals_history_old;
```

**Benefits:**
- Queries scan only relevant partitions (10x faster)
- Old partitions can be dropped (automatic cleanup)
- Indexes are smaller per partition

**2. Connection Pooling (PgBouncer):**
```ini
# docker-compose.yml addition
pgbouncer:
  image: pgbouncer/pgbouncer:latest
  environment:
    - DATABASES_HOST=postgres
    - DATABASES_PORT=5432
    - DATABASES_USER=postgres
    - DATABASES_PASSWORD=${POSTGRES_PASSWORD}
    - DATABASES_DBNAME=buywhywhy
    - POOL_MODE=transaction
    - MAX_CLIENT_CONN=1000
    - DEFAULT_POOL_SIZE=25
    - RESERVE_POOL_SIZE=5
  ports:
    - "6432:6432"
```

**Backend connection string change:**
```typescript
// Before: Direct PostgreSQL connection
DATABASE_URL=postgresql://postgres:password@postgres:5432/buywhywhy

// After: Through PgBouncer
DATABASE_URL=postgresql://postgres:password@pgbouncer:6432/buywhywhy
```

**Benefits:**
- Reduce connection overhead (PostgreSQL forks per connection = expensive)
- Support 1000+ clients with only 25 real DB connections
- 3-5x improvement in throughput

**3. Read Replicas for Analytics:**
```yaml
# docker-compose.prod.yml
postgres-replica:
  image: postgres:16-alpine
  environment:
    - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    - POSTGRES_REPLICA=true
  volumes:
    - postgres_replica_data:/var/lib/postgresql/data
  command: |
    postgres
    -c wal_level=replica
    -c hot_standby=on
    -c max_wal_senders=3
    -c max_replication_slots=3
```

**Usage:**
```typescript
// Write queries → Master
await masterPool.query('INSERT INTO bank_cards ...');

// Read queries (analytics) → Replica
await replicaPool.query('SELECT COUNT(*) FROM wireless_signals_history ...');
```

**Benefits:**
- Offload expensive SELECT queries from master
- Analytics don't block transactional writes
- 2x total read capacity

#### Phase 4: Scale (10,000+ users)
**Expected Load:**
- `wireless_signals_history`: ~20,000,000 rows ⚠️ **CRITICAL**
- Queries/sec: ~500-1000 QPS
- Storage: ~50GB

**Advanced Optimizations:**

**1. TimescaleDB Extension (Time-Series Optimization):**
```sql
CREATE EXTENSION timescaledb;

-- Convert wireless_signals_history to hypertable
SELECT create_hypertable(
    'wireless_signals_history',
    'detected_at',
    chunk_time_interval => INTERVAL '7 days',
    migrate_data => TRUE
);

-- Automatic compression for old data
ALTER TABLE wireless_signals_history
SET (timescaledb.compress,
     timescaledb.compress_segmentby = 'user_id,signal_type',
     timescaledb.compress_orderby = 'detected_at DESC');

-- Compression policy: compress chunks older than 30 days
SELECT add_compression_policy('wireless_signals_history', INTERVAL '30 days');

-- Retention policy: drop chunks older than 90 days
SELECT add_retention_policy('wireless_signals_history', INTERVAL '90 days');
```

**Benefits:**
- 10-20x compression ratio for old data
- Automatic data lifecycle management
- Optimized for time-series queries (30-50% faster)

**2. Materialized Views for Heavy Analytics:**
```sql
-- Expensive query: Top merchants by user visits
CREATE MATERIALIZED VIEW mv_top_merchants_by_visits AS
SELECT
    m.id,
    m.merchant_name,
    m.mcc_code,
    COUNT(DISTINCT wsh.user_id) AS unique_visitors,
    COUNT(*) AS total_visits,
    AVG(m.confidence_score) AS avg_confidence
FROM merchant_database m
JOIN wireless_signals_history wsh ON wsh.merchant_id = m.id
WHERE wsh.detected_at >= NOW() - INTERVAL '30 days'
GROUP BY m.id, m.merchant_name, m.mcc_code
ORDER BY unique_visitors DESC
LIMIT 1000;

-- Refresh nightly
CREATE INDEX ON mv_top_merchants_by_visits(unique_visitors DESC);

-- Scheduled refresh (via cron or backend job)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_merchants_by_visits;
```

**Benefits:**
- Analytics queries: 100x faster (0.001s vs 0.1s)
- No load on transactional tables
- CONCURRENTLY allows queries during refresh

**3. Sharding Strategy (if >100K users):**
```sql
-- Shard by user_id hash
-- Shard 0: users with user_id hash % 4 = 0
-- Shard 1: users with user_id hash % 4 = 1
-- Shard 2: users with user_id hash % 4 = 2
-- Shard 3: users with user_id hash % 4 = 3

-- Backend routing logic
function getShardForUser(userId: string): number {
  const hash = hashCode(userId);
  return Math.abs(hash) % 4;
}

const shard = getShardForUser(req.user.id);
const pool = shardPools[shard];
await pool.query('SELECT * FROM bank_cards WHERE user_id = $1', [req.user.id]);
```

---

## Index Strategy

### Current Indexes (Implemented)

✅ **Good:**
- `idx_users_email` - Unique constraint, used for login
- `idx_russian_banks_priority` - Used for ranking banks
- `idx_mcc_codes_code` - Used for MCC lookups
- `idx_bank_cards_user_id` - Used for user's cards queries
- `idx_wireless_signals_wifi_ssid` - Used for WiFi detection

❌ **Missing (Need to Add):**

```sql
-- 1. Composite index for cascade detection (CRITICAL)
CREATE INDEX CONCURRENTLY idx_wireless_cascade_nfc
ON wireless_signals_history(nfc_terminal_id, detected_at DESC)
WHERE nfc_terminal_id IS NOT NULL;

CREATE INDEX CONCURRENTLY idx_wireless_cascade_wifi_bssid
ON wireless_signals_history(wifi_bssid, detected_at DESC)
WHERE wifi_bssid IS NOT NULL;

CREATE INDEX CONCURRENTLY idx_wireless_cascade_bluetooth
ON wireless_signals_history(bluetooth_uuid, bluetooth_major, bluetooth_minor, detected_at DESC)
WHERE bluetooth_uuid IS NOT NULL;

-- 2. Covering index for best_card_for_mcc function
CREATE INDEX CONCURRENTLY idx_card_cashback_coverage
ON card_cashback_rates(card_id, mcc_code, cashback_percent DESC, valid_from, valid_until)
WHERE is_active = TRUE;

-- 3. Geospatial index for location-based queries
CREATE EXTENSION IF NOT EXISTS postgis;
ALTER TABLE merchant_database ADD COLUMN geom GEOMETRY(Point, 4326);
UPDATE merchant_database SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);
CREATE INDEX idx_merchant_geom ON merchant_database USING GIST(geom);

-- Usage:
-- Find merchants within 100m radius
SELECT * FROM merchant_database
WHERE ST_DWithin(
    geom,
    ST_SetSRID(ST_MakePoint(37.6173, 55.7558), 4326)::geography,
    100  -- meters
);
```

### Index Maintenance

```sql
-- Check index bloat
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;

-- Rebuild bloated indexes
REINDEX INDEX CONCURRENTLY idx_wireless_signals_history_pkey;

-- Remove unused indexes (idx_scan = 0 after 1 week)
DROP INDEX IF EXISTS idx_unused_index;
```

---

## Query Optimization Examples

### Example 1: Slow Cascade Detection

**Problem:**
```sql
-- Original slow query (500ms for 10K rows)
SELECT * FROM wireless_signals_history
WHERE wifi_ssid LIKE 'Magnolia%'
ORDER BY detected_at DESC
LIMIT 1;
```

**EXPLAIN ANALYZE Output:**
```
Seq Scan on wireless_signals_history (cost=0.00..1523.45 rows=10 width=...)
Filter: ((wifi_ssid)::text ~~ 'Magnolia%'::text)
Rows Removed by Filter: 9990
Planning Time: 0.123 ms
Execution Time: 502.456 ms  ⚠️ TOO SLOW
```

**Root Cause:** Sequential scan (no index on wifi_ssid pattern matching)

**Solution:**
```sql
-- Add trigram index for LIKE queries
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX CONCURRENTLY idx_wireless_wifi_ssid_trgm
ON wireless_signals_history USING GIN(wifi_ssid gin_trgm_ops);

-- Now query is fast
EXPLAIN ANALYZE
SELECT * FROM wireless_signals_history
WHERE wifi_ssid LIKE 'Magnolia%'
ORDER BY detected_at DESC
LIMIT 1;
```

**New EXPLAIN ANALYZE:**
```
Bitmap Heap Scan on wireless_signals_history (cost=4.45..15.23 rows=10 width=...)
Recheck Cond: ((wifi_ssid)::text ~~ 'Magnolia%'::text)
-> Bitmap Index Scan on idx_wireless_wifi_ssid_trgm (cost=0.00..4.45 rows=10 width=0)
    Index Cond: ((wifi_ssid)::text ~~ 'Magnolia%'::text)
Planning Time: 0.089 ms
Execution Time: 1.234 ms  ✅ 400x FASTER
```

### Example 2: Slow User Card Lookup

**Problem:**
```sql
-- get_best_card_for_mcc() function takes 200ms
SELECT
    bc.id,
    COALESCE(bc.card_nickname, rb.name_short) AS card_nickname,
    rb.name_short AS bank_name,
    ccr.cashback_percent
FROM bank_cards bc
JOIN russian_banks rb ON rb.id = bc.bank_id
JOIN card_cashback_rates ccr ON ccr.card_id = bc.id
WHERE bc.user_id = 'user-uuid-here'
  AND bc.is_active = TRUE
  AND ccr.mcc_code = '5411'
  AND CURRENT_DATE BETWEEN ccr.valid_from AND ccr.valid_until
  AND (NOT ccr.requires_activation OR ccr.is_activated = TRUE)
ORDER BY ccr.cashback_percent DESC
LIMIT 1;
```

**EXPLAIN ANALYZE shows:** Multiple nested loops, no covering index

**Solution:**
```sql
-- Covering index includes all columns needed by the query
CREATE INDEX CONCURRENTLY idx_card_cashback_best_card
ON card_cashback_rates(
    card_id,
    mcc_code,
    cashback_percent DESC,
    valid_from,
    valid_until,
    requires_activation,
    is_activated
)
WHERE is_active = TRUE;

-- Additional index on bank_cards
CREATE INDEX CONCURRENTLY idx_bank_cards_active_user
ON bank_cards(user_id, is_active, bank_id, id, card_nickname)
WHERE is_active = TRUE;
```

**Result:** Query time: 200ms → 5ms (40x faster)

---

## Transaction Management

### Isolation Levels for Картовед

**Default: Read Committed** (PostgreSQL default)
- Good for most transactional queries
- Minimal lock contention
- Suitable for card CRUD operations

**When to Use Repeatable Read:**
```typescript
// Scenario: User activates cashback category (avoid race condition)
await db.transaction(async (trx) => {
    // Check current activated categories count
    const { count } = await trx('card_cashback_rates')
        .where({ card_id: cardId, is_activated: true })
        .count('*')
        .first();

    if (count >= 3) {
        throw new Error('Maximum 3 categories can be activated');
    }

    // Activate new category
    await trx('card_cashback_rates')
        .where({ id: rateId })
        .update({ is_activated: true });

}, { isolationLevel: 'repeatable read' });
```

**When to Use Serializable:**
```typescript
// Scenario: Crowdsourcing verification (prevent double-voting)
await db.transaction(async (trx) => {
    // Check if user already voted
    const existing = await trx('merchant_verifications')
        .where({ user_id: userId, merchant_id: merchantId })
        .first();

    if (existing) {
        throw new Error('You already voted for this merchant');
    }

    // Add vote
    await trx('merchant_verifications').insert({
        user_id: userId,
        merchant_id: merchantId,
        is_correct: true
    });

    // Update merchant stats
    await trx('merchant_database')
        .where({ id: merchantId })
        .increment('verified_by_users', 1);

}, { isolationLevel: 'serializable' });
```

### Deadlock Prevention

**Rule 1:** Always acquire locks in the same order
```typescript
// ✅ Good: Always lock tables in alphabetical order
await trx('bank_cards').where(...).forUpdate();  // Lock cards first
await trx('card_cashback_rates').where(...).forUpdate();  // Then rates

// ❌ Bad: Inconsistent lock order can cause deadlocks
await trx('card_cashback_rates').where(...).forUpdate();
await trx('bank_cards').where(...).forUpdate();
```

**Rule 2:** Keep transactions short
```typescript
// ✅ Good: Quick transaction
await db.transaction(async (trx) => {
    await trx('bank_cards').insert(card);
    await trx('card_cashback_rates').insert(rates);
});

// ❌ Bad: Long transaction with external API call
await db.transaction(async (trx) => {
    await trx('bank_cards').insert(card);
    const ocrResult = await externalOCRApi.process(image);  // BLOCKING!
    await trx('card_cashback_rates').insert(ocrResult.rates);
});
```

**Rule 3:** Monitor deadlocks
```sql
-- Check for deadlocks
SELECT * FROM pg_stat_database WHERE datname = 'buywhywhy';

-- Enable deadlock logging
ALTER DATABASE buywhywhy SET deadlock_timeout = '1s';
ALTER DATABASE buywhywhy SET log_lock_waits = on;
```

---

## Backup & Recovery Strategy

### Daily Automated Backups

```bash
#!/bin/bash
# /backup/daily-backup.sh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgres"
DB_NAME="buywhywhy"

# Full database dump
pg_dump -h postgres -U postgres -Fc $DB_NAME > $BACKUP_DIR/backup_$TIMESTAMP.dump

# Upload to cloud storage (S3, Yandex Object Storage)
aws s3 cp $BACKUP_DIR/backup_$TIMESTAMP.dump s3://kartoved-backups/daily/

# Keep only last 7 days locally
find $BACKUP_DIR -type f -mtime +7 -delete

# Log success
echo "Backup completed: backup_$TIMESTAMP.dump" | logger -t postgres-backup
```

### WAL Archiving (Point-in-Time Recovery)

```sql
-- postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backups/wal_archive/%f'
archive_timeout = 300  -- Archive every 5 minutes
```

**Recovery Scenario:**
```bash
# Restore from backup + WAL replay
pg_restore -h postgres -U postgres -d buywhywhy /backups/backup_20260207.dump

# Replay WAL files
cp /backups/wal_archive/* /var/lib/postgresql/data/pg_wal/

# Start PostgreSQL in recovery mode
touch /var/lib/postgresql/data/recovery.signal
echo "restore_command = 'cp /backups/wal_archive/%f %p'" >> /var/lib/postgresql/data/postgresql.auto.conf

# Restart PostgreSQL
docker-compose restart postgres
```

---

## Monitoring & Alerts

### Key Metrics to Track

**1. Query Performance:**
```sql
-- Install pg_stat_statements
CREATE EXTENSION pg_stat_statements;

-- Top 10 slowest queries
SELECT
    query,
    calls,
    total_exec_time / 1000 AS total_time_sec,
    mean_exec_time / 1000 AS avg_time_sec,
    max_exec_time / 1000 AS max_time_sec
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**2. Connection Pool Health:**
```sql
-- Active connections
SELECT
    datname,
    count(*) AS connections,
    max(state) AS state
FROM pg_stat_activity
WHERE datname = 'buywhywhy'
GROUP BY datname;

-- Long-running queries (>5 seconds)
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query
FROM pg_stat_activity
WHERE state = 'active' AND now() - pg_stat_activity.query_start > INTERVAL '5 seconds';
```

**3. Table Bloat:**
```sql
-- Bloat percentage for large tables
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_dead_tup,
    n_live_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_percentage
FROM pg_stat_user_tables
WHERE n_live_tup > 1000
ORDER BY dead_percentage DESC;

-- Fix: VACUUM FULL (locks table) or pg_repack (online)
VACUUM FULL wireless_signals_history;
```

**4. Replication Lag (if using replicas):**
```sql
-- On master
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

### Alert Thresholds

```yaml
# Prometheus alerting rules
groups:
  - name: postgres_alerts
    rules:
      - alert: HighQueryLatency
        expr: pg_stat_statements_mean_exec_time_seconds > 0.1
        for: 5m
        annotations:
          summary: "Query {{ $labels.query }} is slow"

      - alert: ConnectionPoolExhausted
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
        for: 2m
        annotations:
          summary: "Connection pool at {{ $value }}% capacity"

      - alert: ReplicationLag
        expr: pg_replication_lag_bytes > 104857600  # 100MB
        for: 5m
        annotations:
          summary: "Replication lag is {{ $value }} bytes"
```

---

## Performance Tuning for Docker

### PostgreSQL Config Optimization

```conf
# /var/lib/postgresql/data/postgresql.conf

# Memory settings (for 4GB RAM server)
shared_buffers = 1GB                  # 25% of RAM
effective_cache_size = 3GB            # 75% of RAM
maintenance_work_mem = 256MB
work_mem = 16MB                       # Per query operation

# Connection settings
max_connections = 100                 # Use PgBouncer for more
superuser_reserved_connections = 3

# WAL settings
wal_buffers = 16MB
checkpoint_completion_target = 0.9
checkpoint_timeout = 10min

# Query planner
random_page_cost = 1.1                # For SSD storage
effective_io_concurrency = 200        # For SSD

# Autovacuum (aggressive for high-write tables)
autovacuum_max_workers = 4
autovacuum_naptime = 10s
autovacuum_vacuum_cost_delay = 2ms
autovacuum_vacuum_scale_factor = 0.05  # Vacuum at 5% dead tuples
autovacuum_analyze_scale_factor = 0.02 # Analyze at 2% change

# Logging
log_min_duration_statement = 100      # Log queries >100ms
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
```

### Docker Compose Tuning

```yaml
# docker-compose.prod.yml
services:
  postgres:
    image: postgres:16-alpine
    shm_size: 1gb                      # Shared memory for PostgreSQL
    command: |
      postgres
      -c shared_buffers=1GB
      -c effective_cache_size=3GB
      -c maintenance_work_mem=256MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200
      -c work_mem=16MB
      -c max_connections=100
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

---

## Disaster Recovery Runbook

### Scenario 1: Database Corruption

```bash
# 1. Stop application
docker-compose stop backend

# 2. Check corruption
docker-compose exec postgres pg_checksums --check -D /var/lib/postgresql/data

# 3. If corrupted, restore from backup
pg_restore -h localhost -U postgres -d buywhywhy /backups/latest.dump

# 4. Verify integrity
docker-compose exec postgres psql -U postgres -d buywhywhy -c "SELECT COUNT(*) FROM users;"

# 5. Restart application
docker-compose start backend
```

### Scenario 2: Accidental Data Deletion

```sql
-- 1. Check if data is in WAL (if WAL archiving enabled)
-- Restore to point-in-time before deletion

-- 2. If no WAL, restore from last night's backup
pg_restore -h localhost -U postgres -d buywhywhy /backups/backup_lastnight.dump

-- 3. Re-apply today's changes manually (if critical)
```

### Scenario 3: Master Failure (High Availability)

```bash
# 1. Promote replica to master
docker-compose exec postgres-replica pg_ctl promote -D /var/lib/postgresql/data

# 2. Update backend to point to new master
# Change DATABASE_URL in .env
DATABASE_URL=postgresql://postgres:password@postgres-replica:5432/buywhywhy

# 3. Restart backend
docker-compose restart backend

# 4. Fix old master, make it new replica
```

---

## Best Practices Checklist

### Development Phase
- ✅ Use transactions for multi-step operations
- ✅ Add indexes for all foreign keys
- ✅ Use prepared statements (prevent SQL injection)
- ✅ Test with production-like data volume
- ✅ Monitor slow queries with EXPLAIN ANALYZE

### Pre-Production Phase
- ✅ Enable connection pooling (PgBouncer)
- ✅ Set up automated backups
- ✅ Configure WAL archiving
- ✅ Tune PostgreSQL config for production
- ✅ Implement monitoring (Prometheus + Grafana)
- ✅ Load testing (simulate 1000+ concurrent users)

### Production Phase
- ✅ Monitor query performance daily
- ✅ Review pg_stat_statements weekly
- ✅ Check table bloat monthly
- ✅ Test backup restoration quarterly
- ✅ Perform failover drills quarterly
- ✅ Review and optimize indexes based on actual usage

---

## Common Pitfalls & How to Avoid

### Pitfall 1: N+1 Query Problem
```typescript
// ❌ Bad: N+1 queries
const cards = await db('bank_cards').where({ user_id });
for (const card of cards) {
    const rates = await db('card_cashback_rates').where({ card_id: card.id });
    card.rates = rates;
}

// ✅ Good: Single JOIN query
const cards = await db('bank_cards')
    .leftJoin('card_cashback_rates', 'bank_cards.id', 'card_cashback_rates.card_id')
    .where('bank_cards.user_id', user_id);
```

### Pitfall 2: Missing WHERE Clause
```sql
-- ❌ Bad: Accidental full table update
UPDATE wireless_signals_history SET expires_at = NOW();  -- Updates ALL rows!

-- ✅ Good: Always use WHERE
UPDATE wireless_signals_history
SET expires_at = NOW()
WHERE user_id = 'specific-user-uuid';
```

### Pitfall 3: Not Using Indexes
```sql
-- ❌ Bad: Query on unindexed column
SELECT * FROM wireless_signals_history WHERE wifi_ssid = 'MagnoliaWiFi';
-- Result: Sequential scan, 500ms

-- ✅ Good: Add index first
CREATE INDEX idx_wireless_wifi_ssid ON wireless_signals_history(wifi_ssid);
-- Result: Index scan, 5ms
```

---

## Next Steps for Картовед

1. **Immediate (MVP Phase):**
   - ✅ Current schema is sufficient
   - ⚠️ Add missing indexes (see Index Strategy section)
   - ⚠️ Enable pg_stat_statements

2. **Phase 2 (200-500 users):**
   - Implement PgBouncer connection pooling
   - Set up automated backups
   - Add monitoring (Prometheus)

3. **Phase 3 (5,000 users):**
   - Partition wireless_signals_history by month
   - Add read replica for analytics
   - Implement materialized views

4. **Phase 4 (10,000+ users):**
   - Migrate to TimescaleDB for time-series data
   - Implement horizontal sharding
   - Consider managed database (AWS RDS, Yandex Managed PostgreSQL)

---

**Contact DBA Expert:**
- For query optimization: Provide `EXPLAIN ANALYZE` output
- For scaling decisions: Provide current metrics (QPS, storage, query latency)
- For replication setup: Specify HA requirements (RPO, RTO)

**Last Updated:** 2026-02-07
**Version:** 1.0.0
