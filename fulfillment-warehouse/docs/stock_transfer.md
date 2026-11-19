# Stock transfers

`warehouse.transfer_stock(product_id, from_cell_id, to_cell_id, quantity, employee_id)`
is a PostgreSQL procedure. Call it inside a transaction or by itself in an
autocommit session. PostgreSQL rolls back both balance changes and the movement
record if any step fails.

```sql
CALL warehouse.transfer_stock(1, 101, 205, 3, 7);
```

The procedure checks that the product and employee are active, both locations
are active cells under active zones, the source has enough units, and the
destination has space by weight and volume. A cell may hold only one product.
Moving stock into a damaged zone records a `damage_transfer`; other cell moves
record a `transfer`. Moving stock out of the damaged zone is prohibited.

After migration 06, all posting APIs share a transaction advisory lock.
Concurrent API calls wait until the earlier transaction finishes. A row with
zero units is removed from inventory; its history stays in stock_movements.

Receipt posting, picking and dispatch are available after migration 06.
See workflows.md for those APIs. The transfer test seeds its initial balance
as a fixture and rolls it back.
The procedure alone cannot prevent someone with direct `UPDATE` access from
changing `inventory` outside this workflow; database roles and permissions
can address that in a later stage.
