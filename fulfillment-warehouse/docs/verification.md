# Verification

The checks below ran on PostgreSQL 16.2 in single-user mode on 2026-11-19.
The same workflow tests, generation and report scripts were also run manually
on a Windows installation of PostgreSQL 18.7. SQL uses features available in
both versions.

- Migrations 01-08 and 11 executed successfully on an empty database.
- Schema, index and stock transfer tests passed.
- Generated 5000 cycles through the business procedures.
- Result: 5500 receipts, 5000 shipments, 5000 picking tasks, 20500 movements
  and 103000 audit entries.
- Inventory reconciliation returned zero mismatches.
- Workflow test rejected repeated dispatch and editing of final headers/lines.
- Edge-case test checked invalid transitions, repeated receipt posting, atomic
  rollback after a receipt capacity/zone error, excessive picking and partial shipping.
- All analytical queries executed successfully.

The seller query used idx_shipments_seller_status_created. The product history
query used idx_stock_movements_product_created, with an observed execution time
of 0.068 ms versus 4.561 ms when index scans were disabled. These are single-run
observations on this machine, not a portable benchmark. Both queries also
perform a MIN key lookup; compare plans and buffers rather than treating the
timing ratio as an isolated index-speed measurement.

No multi-session concurrency benchmark was possible in the socket-restricted
environment. Procedures serialize through a shared transaction advisory lock.
The Python network runner is supplied for a normal local PostgreSQL connection;
the SQL was executed locally through PostgreSQL's single-user backend here.

## Repository packaging checks

After formatting, a fresh database passed migrations, tests 01-05 and the
analytical queries. The walkthrough ran both before and after a 20-cycle
dataset. SQL token comparison confirmed that formatting and comment edits did
not change the existing SQL statements. Python files compiled successfully.
The GitHub Actions workflow is configured for PostgreSQL 16 and 18; it has not
been executed on GitHub yet. No CI badge or hosted test result is claimed here.
