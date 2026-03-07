# PostgreSQL Tuning Baseline (1 GB RAM / 1 vCPU / SSD)

This document is for a small DigitalOcean droplet profile:

- 1 GB RAM
- 1 vCPU
- SSD disk

Use this only after collecting a baseline (`pg_stat_statements`, `pg_stat_activity`, endpoint timings).

## 1) Capture current values

```sql
SELECT name, setting, unit, source
FROM pg_settings
WHERE name IN (
  'max_connections',
  'shared_buffers',
  'effective_cache_size',
  'work_mem',
  'maintenance_work_mem',
  'random_page_cost',
  'effective_io_concurrency',
  'wal_buffers',
  'checkpoint_timeout',
  'checkpoint_completion_target',
  'autovacuum_vacuum_scale_factor',
  'autovacuum_analyze_scale_factor',
  'shared_preload_libraries',
  'track_io_timing',
  'log_min_duration_statement'
)
ORDER BY name;
```

## 2) Recommended target values (small droplet)

Old values vary by package defaults. Set these explicitly:

- `max_connections`: old = package default, new = `30`
- `shared_buffers`: old = package default, new = `256MB`
- `effective_cache_size`: old = package default, new = `640MB`
- `work_mem`: old = package default, new = `4MB`
- `maintenance_work_mem`: old = package default, new = `64MB`
- `random_page_cost`: old = package default, new = `1.1`
- `effective_io_concurrency`: old = package default, new = `200`
- `wal_buffers`: old = package default, new = `8MB`
- `checkpoint_timeout`: old = package default, new = `10min`
- `checkpoint_completion_target`: old = package default, new = `0.9`
- `autovacuum_vacuum_scale_factor`: old = package default, new = `0.05`
- `autovacuum_analyze_scale_factor`: old = package default, new = `0.02`
- `track_io_timing`: old = package default, new = `on`
- `log_min_duration_statement`: old = package default, new = `250ms` (temporary during tuning)

For query tracking:

- `shared_preload_libraries`: include `pg_stat_statements`

## 3) Apply (ALTER SYSTEM)

```sql
ALTER SYSTEM SET max_connections = '30';
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '640MB';
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET random_page_cost = '1.1';
ALTER SYSTEM SET effective_io_concurrency = '200';
ALTER SYSTEM SET wal_buffers = '8MB';
ALTER SYSTEM SET checkpoint_timeout = '10min';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';
ALTER SYSTEM SET autovacuum_vacuum_scale_factor = '0.05';
ALTER SYSTEM SET autovacuum_analyze_scale_factor = '0.02';
ALTER SYSTEM SET track_io_timing = 'on';
ALTER SYSTEM SET log_min_duration_statement = '250ms';
```

Set preload libraries (append if needed):

```sql
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
```

Then:

```sql
SELECT pg_reload_conf();
```

Restart PostgreSQL after `shared_preload_libraries` changes.

## 4) pg_stat_statements enable

After restart:

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

## 5) Rollback

Reset one by one:

```sql
ALTER SYSTEM RESET max_connections;
ALTER SYSTEM RESET shared_buffers;
ALTER SYSTEM RESET effective_cache_size;
ALTER SYSTEM RESET work_mem;
ALTER SYSTEM RESET maintenance_work_mem;
ALTER SYSTEM RESET random_page_cost;
ALTER SYSTEM RESET effective_io_concurrency;
ALTER SYSTEM RESET wal_buffers;
ALTER SYSTEM RESET checkpoint_timeout;
ALTER SYSTEM RESET checkpoint_completion_target;
ALTER SYSTEM RESET autovacuum_vacuum_scale_factor;
ALTER SYSTEM RESET autovacuum_analyze_scale_factor;
ALTER SYSTEM RESET track_io_timing;
ALTER SYSTEM RESET log_min_duration_statement;
ALTER SYSTEM RESET shared_preload_libraries;
SELECT pg_reload_conf();
```

Restart PostgreSQL if `shared_preload_libraries` was changed.

## 6) Host checks

Run on Ubuntu host during load:

```bash
free -h
vmstat 1 10
iostat -xz 1 10
pidstat -u -r -d 1 10
ss -s
ulimit -n
```

If swap is active and `si/so` are non-zero under steady load, reduce memory pressure first (pool size, `max_connections`, query batch size) before increasing memory knobs.
