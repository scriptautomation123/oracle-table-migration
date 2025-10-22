# Oracle Performance Testing Configuration

## Codespace Machine Specifications

This environment is configured to request the **largest GitHub Codespace machine**:
- **32 vCPUs** (physical cores)
- **64 GB RAM**
- **128 GB Storage**

### Resource Allocation

#### Oracle Database Container
- **CPU Limit**: 16 cores (50% of total)
- **CPU Reservation**: 8 cores (guaranteed)
- **Memory Limit**: 32 GB (50% of total)
- **Memory Reservation**: 16 GB (guaranteed)
- **Shared Memory (SGA)**: 8 GB
- **tmpfs**: 8 GB for /dev/shm

#### Workspace Container
- **CPU Limit**: 8 cores (25% of total)
- **CPU Reservation**: 4 cores (guaranteed)
- **Memory Limit**: 16 GB (25% of total)
- **Memory Reservation**: 8 GB (guaranteed)

## Oracle Performance Tuning Settings

### Memory Configuration (SGA/PGA)

The Oracle XE container is configured with:
- `shm_size: 8gb` - Shared memory for System Global Area (SGA)
- Archive logging disabled for testing (better performance)
- Character set: AL32UTF8 (UTF-8 support)

### Recommended Oracle Initialization Parameters

Connect as SYSDBA and tune these parameters for performance testing:

```sql
-- Connect as SYSDBA
sqlplus sys/Oracle123!@localhost:1521/XEPDB1 as sysdba

-- Increase SGA size (within XE limits)
ALTER SYSTEM SET sga_target=4G SCOPE=SPFILE;
ALTER SYSTEM SET pga_aggregate_target=2G SCOPE=SPFILE;

-- Optimize for OLTP workloads
ALTER SYSTEM SET optimizer_mode='ALL_ROWS' SCOPE=BOTH;
ALTER SYSTEM SET optimizer_index_cost_adj=100 SCOPE=BOTH;

-- Parallel query execution (use available CPUs)
ALTER SYSTEM SET parallel_max_servers=16 SCOPE=BOTH;
ALTER SYSTEM SET parallel_min_servers=4 SCOPE=BOTH;

-- Buffer cache settings
ALTER SYSTEM SET db_cache_size=2G SCOPE=SPFILE;

-- Shared pool
ALTER SYSTEM SET shared_pool_size=512M SCOPE=SPFILE;

-- Sort and hash operations
ALTER SYSTEM SET sort_area_size=10485760 SCOPE=SPFILE;
ALTER SYSTEM SET hash_area_size=10485760 SCOPE=SPFILE;

-- Commit behavior
ALTER SYSTEM SET commit_write='BATCH,NOWAIT' SCOPE=BOTH;

-- Restart required for SPFILE changes
SHUTDOWN IMMEDIATE;
STARTUP;
```

### Partition Performance Settings

```sql
-- Enable partition-wise joins
ALTER SESSION SET parallel_degree_policy=AUTO;
ALTER SESSION SET optimizer_features_enable='21.1.0';

-- For interval partitioning performance
ALTER SYSTEM SET deferred_segment_creation=FALSE SCOPE=BOTH;
```

## Performance Monitoring

### Real-time Monitoring Scripts

#### 1. Monitor Active Sessions
```sql
SELECT 
    sid, 
    serial#, 
    username, 
    status, 
    sql_id,
    event,
    wait_time,
    seconds_in_wait
FROM v$session 
WHERE username IS NOT NULL 
ORDER BY seconds_in_wait DESC;
```

#### 2. Monitor SQL Performance
```sql
SELECT 
    sql_id,
    executions,
    elapsed_time/1000000 as elapsed_sec,
    cpu_time/1000000 as cpu_sec,
    buffer_gets,
    disk_reads,
    rows_processed
FROM v$sql 
WHERE elapsed_time > 1000000
ORDER BY elapsed_time DESC
FETCH FIRST 20 ROWS ONLY;
```

#### 3. Monitor Tablespace Usage
```sql
SELECT 
    tablespace_name,
    ROUND(used_space * 8192 / 1024 / 1024, 2) AS used_mb,
    ROUND(tablespace_size * 8192 / 1024 / 1024, 2) AS total_mb,
    ROUND(used_percent, 2) AS used_percent
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;
```

#### 4. Monitor Wait Events
```sql
SELECT 
    event,
    total_waits,
    time_waited_micro/1000000 as time_waited_sec,
    average_wait_ms
FROM v$system_event
WHERE wait_class != 'Idle'
ORDER BY time_waited_micro DESC
FETCH FIRST 20 ROWS ONLY;
```

## Performance Testing Best Practices

### 1. Data Volume Testing
- Test with realistic data volumes (millions of rows)
- Use the provided test data generation scripts
- Monitor partition creation and management

### 2. Concurrent Load Testing
- Run multiple migration scripts in parallel
- Monitor lock contention
- Track session counts and resource usage

### 3. I/O Performance
- Monitor disk read/write operations
- Track buffer cache hit ratio
- Analyze wait events related to I/O

### 4. Partition-Specific Testing
- Test interval partition creation performance
- Measure partition pruning effectiveness
- Validate hash sub-partition distribution

## Benchmark Targets

### Expected Performance Metrics (Large Machine)

| Operation | Target | Metric |
|-----------|--------|--------|
| Initial Data Load | > 100,000 rows/sec | Bulk INSERT |
| Delta Load | > 50,000 rows/sec | Incremental INSERT |
| Index Creation | < 30 sec | Per million rows |
| Partition Creation | < 1 sec | Per partition |
| Table Swap | < 5 sec | RENAME operation |

### Resource Utilization Targets

| Resource | Target Range | Notes |
|----------|--------------|-------|
| CPU Usage | 60-80% | During peak operations |
| Memory Usage | 70-85% | Oracle SGA + PGA |
| I/O Wait | < 10% | Disk operations |
| Network Latency | < 1ms | Container-to-container |

## Monitoring Commands

### System Resource Monitoring

```bash
# Monitor container resources
docker stats oracle-test-db workspace

# Check Oracle container logs
docker logs -f oracle-test-db

# Monitor disk I/O
iostat -x 5

# Monitor memory usage
free -h && sync && echo 3 > /proc/sys/vm/drop_caches && free -h

# Check network performance
docker network inspect oracle-network
```

### Oracle-Specific Monitoring

```bash
# Connect to Oracle and check performance
sqlplus hr/hr123@localhost:1521/XEPDB1

# Generate AWR report (if available in XE)
@?/rdbms/admin/awrrpt.sql

# Check alert log
tail -f /opt/oracle/diag/rdbms/xe/XE/trace/alert_XE.log
```

## Scaling Considerations

### When to Use Large Codespace
- Testing with > 1M rows per table
- Running parallel migration jobs
- Performance benchmarking
- Load testing with concurrent users
- Complex partition operations

### When Smaller Machines Suffice
- Development and debugging
- Single table migrations
- Configuration changes
- Documentation work

## Cost Optimization

GitHub Codespaces billing is based on machine hours:
- **32-core machine**: ~4x cost of 4-core machine
- Use for performance testing only
- Stop codespace when not actively testing
- Consider using prebuilds for faster startup

## Troubleshooting Performance Issues

### High CPU Usage
1. Check for full table scans: `SELECT * FROM v$sql WHERE plan_hash_value IN (...)`
2. Verify indexes are being used
3. Monitor parallel execution

### High Memory Usage
1. Check SGA/PGA allocation
2. Monitor session memory: `SELECT * FROM v$sesstat WHERE statistic# IN (15,16)`
3. Adjust PGA_AGGREGATE_TARGET if needed

### Slow I/O
1. Check for disk contention
2. Verify tmpfs is being used for temp operations
3. Monitor redo log performance

### Lock Contention
1. Query DBA_BLOCKERS and DBA_WAITERS
2. Check for long-running transactions
3. Optimize transaction size in migration scripts

## Additional Resources

- Oracle XE Documentation: https://docs.oracle.com/en/database/oracle/oracle-database/21/
- GitHub Codespaces Docs: https://docs.github.com/en/codespaces
- Docker Resource Limits: https://docs.docker.com/compose/compose-file/#resources
