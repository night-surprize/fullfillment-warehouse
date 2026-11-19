BEGIN;

SET LOCAL search_path = warehouse, public;

CREATE VIEW v_inventory AS
SELECT
    i.product_id,
    p.sku,
    p.name,
    p.seller_id,
    s.name AS seller_name,
    i.location_id,
    l.location_code,
    cell_zone (i.location_id) AS zone,
    i.quantity,
    i.quantity * p.unit_weight_kg AS weight_kg,
    i.quantity * p.unit_volume_m3 AS volume_m3,
    ROUND(100 * i.quantity * p.unit_weight_kg / NULLIF (l.max_weight_kg, 0), 2) AS weight_utilization_pct,
    ROUND(100 * i.quantity * p.unit_volume_m3 / NULLIF (l.max_volume_m3, 0), 2) AS volume_utilization_pct
FROM
    inventory i
    JOIN products p USING (product_id)
    JOIN sellers s USING (seller_id)
    JOIN warehouse_locations l USING (location_id);

CREATE VIEW v_receipt_performance AS
SELECT
    r.receipt_id,
    r.seller_id,
    r.receipt_type,
    r.created_at,
    r.completed_at,
    EXTRACT(EPOCH FROM r.completed_at - r.started_at) / 60 AS processing_minutes,
    SUM(i.expected_quantity) AS expected_quantity,
    SUM(i.received_quantity) AS received_quantity,
    SUM(i.damaged_quantity) AS damaged_quantity,
    SUM(i.received_quantity) - SUM(i.expected_quantity) AS discrepancy_quantity
FROM
    receipts r
    JOIN receipt_items i USING (receipt_id)
WHERE
    r.status = 'received'
GROUP BY
    r.receipt_id;

CREATE VIEW v_stock_ledger AS
WITH legs AS (
    SELECT
        movement_id,
        product_id,
        to_location_id AS location_id,
        quantity::BIGINT AS delta,
        created_at
    FROM
        stock_movements
    WHERE
        to_location_id IS NOT NULL
    UNION ALL
    SELECT
        movement_id,
        product_id,
        from_location_id,
        - quantity::BIGINT,
        created_at
    FROM
        stock_movements
    WHERE
        from_location_id IS NOT NULL
)
SELECT
    *,
    SUM(delta) OVER (PARTITION BY product_id, location_id ORDER BY created_at, movement_id ROWS
    UNBOUNDED PRECEDING) AS running_quantity
FROM
    legs;

CREATE VIEW v_inventory_reconciliation AS
WITH ledger AS (
    SELECT
        product_id,
        location_id,
        SUM(delta) AS quantity
    FROM
        v_stock_ledger
    GROUP BY
        product_id,
        location_id
)
SELECT
    COALESCE(l.product_id, i.product_id) AS product_id,
    COALESCE(l.location_id, i.location_id) AS location_id,
    COALESCE(l.quantity, 0) AS ledger_quantity,
    COALESCE(i.quantity, 0) AS actual_quantity
FROM
    ledger l
    FULL JOIN inventory i USING (product_id, location_id)
WHERE
    COALESCE(l.quantity, 0) <> COALESCE(i.quantity, 0);

COMMIT;
