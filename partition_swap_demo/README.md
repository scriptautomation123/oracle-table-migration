## dba instructions

```bash
cd install
./install.sh logging_pkg HR_OWNER --sysdba
./install.sh partition_swap_pkg HR_OWNER --sysdba
./install.sh demo_setup/demo-setup.sql HR_OWNER --sysdba
```

Standard run

```bash
./run_partition_swap.sh
```

# With custom config

```bash
DB_USER=produser \
DB_PASS=prodpass \
DB_CONNECT=prod-db:1521/PROD \
LOG_DIR=/var/log/partition_swap \
./run_partition_swap.sh
```

# Autosys job definition

```bash
command: /path/to/run_partition_swap.sh
std_out_file: /logs/partition_swap_$AUTO_JOB_NAME.out
std_err_file: /logs/partition_swap_$AUTO_JOB_NAME.err
```
