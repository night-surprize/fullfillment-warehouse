# Demo walkthrough

After installation, run `examples/demo.sql` as one script in a fresh connection.
It works on an empty database and on the larger generated dataset. All added
records have a transaction prefix. Its final ROLLBACK removes them.

The scenario uses one seller and one SKU, a desk lamp weighing 0.5 kg with a
volume of 0.01 m3. It creates the document IDs itself, so no manual ID editing
is needed.

| Step | Main storage | Overflow | Damaged | Packing | Shipped |
|---|---:|---:|---:|---:|---:|
| Receive 100 | 98 | 0 | 2 | 0 | 0 |
| Move 10 | 88 | 10 | 2 | 0 | 0 |
| Pick 5 | 83 | 10 | 2 | 5 | 0 |
| Dispatch 5 | 83 | 10 | 2 | 0 | 5 |

The first result set shows 95 units still in the warehouse. The second shows
8 requested and 5 shipped, with status shipped. The remaining three requested
units are visible on the closed document; no follow-up order is created.
The third result set lists five journal rows: two receipt movements, one
transfer, one picking movement and one dispatch movement.

To explain the project, start with this distinction: documents record intent
and workflow, inventory gives the current balance, and stock_movements records
the physical changes. One posting procedure updates the balance and adds the
journal row in the same transaction. A reconciliation query can then verify
that these two representations still agree.

After the demo, generate a larger dataset and open sql/09_analytical_queries.sql.
The seller ranking and seven-day moving average show window functions; the
location paths show recursive CTEs. sql/10_explain.sql shows the indexes used
for two recurring access patterns. The batch timestamps make processing-time
metrics synthetic, so use the query plans to discuss performance rather than
claiming realistic warehouse service levels.
