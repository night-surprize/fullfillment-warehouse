# Workflows

## Upgrade

On the existing database, run 06_operations.sql, 07_document_rules.sql,
08_analytics.sql and 11_demo_generator.sql once in that order. Files 09 and
10 are repeatable reports and plan inspection queries, not migrations.
Run each migration as a complete script with autocommit enabled.

## Receipts

Insert a receipts header and receipt_items with expected quantities, then:

```sql
CALL warehouse.start_receipt(1, 7);
CALL warehouse.receive_receipt(1, 7, '[
  {"item_id":1,"accepted":98,"damaged":2,"cell_id":101,"damaged_cell_id":301}
]'::jsonb);
```

Replace IDs with existing records. Every line must appear exactly once.
Accepted goods go to receiving/storage, damaged goods to the damaged zone.
Expected and received quantities may differ. Posting is atomic and rejects
repeated calls. Returns require a sorting center; the original shipment is
optional. If present, it must be shipped and match the seller and center.

Receipt statuses: created -> expected (optional) -> receiving -> received.
Cancellation is allowed before posting with UPDATE receipts SET status='cancelled'.
Products must belong to the document seller. Final headers and items are immutable.

## Shipments

Insert a shipments header and shipment_items, then:

```sql
CALL warehouse.confirm_shipment(1);
CALL warehouse.pick_shipment(1,7,'[
  {"item_id":1,"from_cell":101,"to_cell":201,"quantity":5}
]'::jsonb);
CALL warehouse.pack_shipment(1);
CALL warehouse.dispatch_shipment(1,7);
```

Picking moves stock from storage to packing. Multiple routes may supply one
line; each item/source/target route must be unique. Partial shipments are allowed:
pick at least one unit for the document and at most the requested quantity per
line. Dispatch ships all picked units. Unfulfilled requested quantities stay
visible in the final document and do not create another document automatically.
Confirmation does not reserve stock. Insufficient stock aborts the operation.

Statuses: created -> confirmed -> picked -> packed -> shipped.
Cancellation is permitted in created/confirmed before any picking.

## Data generation

```sql
CALL warehouse.generate_demo_data(5000,0.42);
```

Or install python/requirements.txt, set DATABASE_URL and run:

```powershell
python python/generate_data.py --cycles 5000 --seed 0.42
```

Each run appends a separate transaction-prefixed dataset: 20 sellers, 200 products,
600 cells, one employee and center. At 5000 cycles it posts 5500 receipts,
5000 shipments, 5000 picking tasks, 20500 stock movements, plus items and audit rows.
Every tenth cycle includes a return. Existing data are never cleared.
The seed controls random values; IDs and prefixes differ between runs.
Capacities are intentionally large for this stress dataset.

Created dates span 30 days. Processing and shipping timestamps reflect the
actual batch run. The generator does not simulate historical processing-time
distributions; batch durations are not realistic warehouse performance.

## Reports and tests

09_analytical_queries.sql includes seller volume ranks, a seven-day moving
average of created shipments with empty days, recursive location paths,
receipt discrepancies and damage share, and cell utilization.
v_stock_ledger exposes running balances using a window SUM.
v_inventory_reconciliation must return zero rows for data posted through APIs.

After generation run tests/04_workflow_test.sql and tests/05_edge_cases_test.sql.
The latter rolls back its additions. Use the updated test 03 after migration 06.
tests/run_integration.py applies migrations to an empty TEST_DATABASE_URL and
refuses an existing warehouse schema.

10_explain.sql compares actual plans and buffer reads for seller queues and
product movement history, including a local comparison with index scans
disabled. Timings depend on data volume, caching and machine.

## Scope and concurrency

All posting APIs acquire the same transaction advisory lock before changing
stock. Concurrent API calls serialize until COMMIT/ROLLBACK. This intentionally
trades throughput for clarity. Multi-session load testing is not included.
Stock and audit history reject row UPDATE/DELETE. Audit stores before/after
JSON, database user and row keys for documents, items, picking and inventory.
Generic audit employee_id is NULL; operation records identify the employee.

The database owner can directly modify inventory or disable triggers. The
internal post_stock helper and APIs are not a permission boundary; no untrusted
application role is included. TRUNCATE is an owner maintenance action outside
row triggers. Use the documented APIs for stock changes. Inventory counts have
storage tables only; count posting is outside this receipt/shipment scope.
