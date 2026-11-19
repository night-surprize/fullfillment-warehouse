# Setup

## PostgreSQL on Windows

Install PostgreSQL and keep the service running. No WSL or Docker is required.
Open PowerShell in the repository root. If psql is not on PATH, add its bin
directory for the current session:

```powershell
$env:Path = "C:\Program Files\PostgreSQL\18\bin;" + $env:Path
psql --version
```

Connect as the administrator once:

```powershell
psql -h localhost -U postgres -d postgres
```

In psql, create a login and database. Skip objects you already have:

```sql
CREATE ROLE warehouse_user LOGIN;
\password warehouse_user
CREATE DATABASE fulfillment_warehouse OWNER warehouse_user;
\q
```

The password prompt keeps the password out of command history. Then install:

```powershell
psql -h localhost -U warehouse_user -d fulfillment_warehouse -f scripts/install.sql
```

The installer applies each migration in its own transaction and stops on error.
It refuses an existing warehouse schema. If a new installation fails halfway,
fix the cause and apply the remaining migrations manually, or use another empty
database. There is no migration tracking table or automatic downgrade.

## VS Code

Connect to localhost:5432, database fulfillment_warehouse, as warehouse_user.
Use autocommit and run each file in full. scripts/install.sql and scripts/test.sql
use psql commands, so run those two from the terminal. Individual files in sql/
and tests/ are plain SQL and can run in the editor.

Several tests contain BEGIN and ROLLBACK. Run them in a separate connection
after committing the generated data. A ROLLBACK also discards any earlier
uncommitted work in that same connection. If the editor reports that the
transaction is aborted, issue ROLLBACK before trying another command.

If your extension starts transactions automatically, use psql for the tests.
Seeing BEGIN report that a transaction is already open means the script joined
that transaction rather than creating a nested one.

## Existing installation

If migrations 01-08 and 11 already ran, no schema update is needed for this
release. Documentation, formatting, launch scripts and the demo were added.
Do not rerun the old CREATE TABLE/TYPE migrations on a populated database.

For a database that has only 01-05, apply 06, 07, 08 and 11 once, in that order.
Files 09 and 10 can be repeated after data generation.

## Data and tests

```powershell
psql -h localhost -U warehouse_user -d fulfillment_warehouse -c "CALL warehouse.generate_demo_data(5000, 0.42);"
psql -h localhost -U warehouse_user -d fulfillment_warehouse -f scripts/test.sql
```

A successful standalone CALL commits its data before the tests begin. The
generator appends records each time. To confirm one completed run:

```sql
SELECT count(*) FROM warehouse.receipts;        -- 5500
SELECT count(*) FROM warehouse.shipments;       -- 5000
SELECT count(*) FROM warehouse.stock_movements; -- 20500
SELECT * FROM warehouse.v_inventory_reconciliation; -- результат должен быть пустым
```

Those counts assume the database had no business data before generation.

## Python runner

Python is optional. For the generator client or a fresh integration run:

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r python/requirements.txt
$env:DATABASE_URL = "postgresql://warehouse_user@localhost:5432/fulfillment_warehouse"
.venv\Scripts\python.exe python/generate_data.py --cycles 5000 --seed 0.42
```

Configure a local PostgreSQL password file for Python, or supply credentials
through your environment. Do not commit connection strings containing passwords.
Special characters in URI passwords must be percent-encoded.

The automated runner installs a schema itself and needs a different, empty DB:

```powershell
createdb -h localhost -U warehouse_user warehouse_test
$env:TEST_DATABASE_URL = "postgresql://warehouse_user@localhost:5432/warehouse_test"
.venv\Scripts\python.exe tests/run_integration.py
```

Creating a database requires CREATEDB privilege; otherwise ask the database
administrator to create warehouse_test owned by warehouse_user. The runner
refuses a database that already contains the warehouse schema. It commits its
small generated dataset and leaves the test database available for inspection.
