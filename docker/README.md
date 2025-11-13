# Oracle Database Docker Setup

Quick start guide for running Oracle Database 23 Free with automatic schema and data initialization.

## 📋 Quick Start

```bash
# Start and test database (first time or existing)
./start-and-test.sh

# Start fresh (clean data and restart)
./start-and-test.sh fresh
```

## 🧹 Cleanup Options

### Option 1: Using start-and-test.sh

```bash
# Clean data only (keep image)
./start-and-test.sh clean-data

# Clean everything (containers, volumes, images)
./start-and-test.sh clean

# Clean and start fresh
./start-and-test.sh fresh
```

### Option 2: Using clean.sh (Interactive)

```bash
./clean.sh
# Follow the menu prompts
```

### Option 3: Manual Docker Compose Commands

```bash
# Stop containers
docker compose -f docker-compose.yml down

# Stop and remove volumes (data)
docker compose -f docker-compose.yml down -v

# Stop, remove volumes and images (everything)
docker compose -f docker-compose.yml down -v --rmi all
```

## 🔧 Manual Operations

### Start Database

```bash
docker compose -f docker-compose.yml up -d
```

### View Logs

```bash
# Follow logs
docker compose -f docker-compose.yml logs -f oracle

# View recent logs
docker compose -f docker-compose.yml logs --tail=100 oracle
```

### Check Status

```bash
docker compose -f docker-compose.yml ps
```

### Connect to Database

```bash
# As HR user (table owner)
docker compose -f docker-compose.yml exec oracle sqlplus hr/hr123@FREEPDB1

# As HR_APP_USER (application user)
docker compose -f docker-compose.yml exec oracle sqlplus hr_app_user/hrapp123@FREEPDB1

# As SYSTEM user
docker compose -f docker-compose.yml exec oracle sqlplus system/Oracle123!@FREEPDB1
```

### Shell Access

```bash
docker compose -f docker-compose.yml exec oracle bash
```

## 📁 Directory Structure

```bash
docker/
├── docker-compose.yml      # Main compose configuration
├── start-and-test.sh       # All-in-one startup and test script
├── test-db-init.sh         # Database verification script
├── clean.sh                # Interactive cleanup menu
└── init-scripts/           # Auto-executed on first startup
    ├── 01_create_schemas.sql
    ├── 02_create_hr_tables.sh
    ├── 02_create_hr_tables.sql
    ├── 03_generate_test_data.sh
    └── 04_generate_test_data.sql
```

## 🗄️ Database Details

### Connection Information

- **Host**: localhost
- **Port**: 1521
- **Service**: FREEPDB1

### Users Created

| User          | Password     | Role        | Purpose                     |
| ------------- | ------------ | ----------- | --------------------------- |
| `hr`          | `hr123`      | Table Owner | Owns all tables and objects |
| `hr_app_user` | `hrapp123`   | Application | Uses HR_APP role for access |
| `system`      | `Oracle123!` | Admin       | System administration       |

### Tables Created

**Non-Partitioned (3):**

- `EMPLOYEES` - Employee data
- `DEPARTMENTS` - Department information
- `JOBS` - Job definitions

**Interval Partitioned (4):**

- `SALES_TRANSACTIONS` - MONTH interval
- `ORDER_HEADERS` - MONTH interval
- `CUSTOMER_INTERACTIONS` - MONTH interval
- `AUDIT_LOG` - MONTH interval with HASH subpartitions

### Test Data

- ~500+ rows inserted across all tables
- Automatic partition creation via INTERVAL partitioning
- Statistics gathered on all tables

## 🔄 Initialization Process

On **first startup** (when volume is empty):

1. Oracle Database starts and initializes
2. `01_create_schemas.sql` - Creates HR, HR_APP_USER, and roles
3. `02_create_hr_tables.sh` - Creates all tables (runs as HR user)
4. `03_generate_test_data.sh` - Populates tables with test data
5. Database marked healthy and ready

**Subsequent startups**: Init scripts are **skipped** (data persists in volume)

## 🚀 Performance Settings

- **Memory Limit**: 16GB max
- **Memory Reservation**: 4GB minimum
- **Shared Memory**: 4GB (for Oracle SGA)
- **Healthcheck**: 90s grace period + 10 retries
- **Image**: `gvenzl/oracle-free:23-slim-faststart` (optimized startup)

## 📊 Verification

After startup, the test script verifies:

- ✅ All tables created
- ✅ Row counts populated
- ✅ Partition configuration
- ✅ Indexes created (local/global)
- ✅ Statistics gathered

## 🐛 Troubleshooting

### Database won't start

```bash
# Check logs
docker compose -f docker-compose.yml logs oracle

# Check if port is already in use
sudo lsof -i :1521

# Clean start
./start-and-test.sh fresh
```

### Initialization scripts didn't run

Init scripts only run on **first startup** with an empty volume.

To re-run initialization:

```bash
# Remove volume and restart
./start-and-test.sh fresh
```

### Out of memory errors

```bash
# Reduce memory limits in docker-compose.yml
mem_limit: 8G
mem_reservation: 2G
shm_size: 2gb
```

### Timeout waiting for healthy status

First startup can take 60-120 seconds. If it times out:

```bash
# Check logs for errors
docker compose -f docker-compose.yml logs oracle

# Increase timeout in start-and-test.sh (default: 300s)
```

## 📝 Adding Custom Init Scripts

Add files to `init-scripts/` directory:

```bash
# SQL scripts (run as SYS/SYSTEM)
init-scripts/05_my_script.sql

# Shell scripts (can switch users)
init-scripts/05_my_script.sh
```

Scripts execute in **alphabetical order** on first startup only.

Example shell script to run as specific user:

```bash
#!/bin/bash
sqlplus -s hr/hr123@//localhost/FREEPDB1 <<'EOF'
-- Your SQL here
EOF
```

## 🔗 External Connections

From host machine or other containers:

```bash
# SQLPlus (if installed locally)
sqlplus hr/hr123@//localhost:1521/FREEPDB1

# SQL Developer
Host: localhost
Port: 1521
Service: FREEPDB1
User: hr
Password: hr123
```

From within Docker network:

```bash
# Use service name 'oracle' instead of localhost
sqlplus hr/hr123@//oracle:1521/FREEPDB1
```

## 📚 Additional Resources

- [gvenzl/oracle-free Docker Hub](https://hub.docker.com/r/gvenzl/oracle-free)
- [Oracle Database Free Documentation](https://www.oracle.com/database/free/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
