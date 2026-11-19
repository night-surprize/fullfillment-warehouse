-- Запускать после генерации данных. Сравниваем планы и обращения к буферам.
ANALYZE warehouse.shipments;

ANALYZE warehouse.stock_movements;

EXPLAIN (
    ANALYZE,
    BUFFERS
)
SELECT
    *
FROM
    warehouse.shipments
WHERE
    seller_id = (
        SELECT
            MIN(seller_id)
        FROM
            warehouse.shipments)
    AND status = 'shipped'
ORDER BY
    created_at DESC
LIMIT 20;

EXPLAIN (
    ANALYZE,
    BUFFERS
)
SELECT
    *
FROM
    warehouse.stock_movements
WHERE
    product_id = (
        SELECT
            MIN(product_id)
        FROM
            warehouse.stock_movements)
ORDER BY
    created_at DESC
LIMIT 20;

-- Настройки действуют только в этой транзакции и сбрасываются при ROLLBACK.
BEGIN;

SET LOCAL enable_indexscan = off;

SET LOCAL enable_indexonlyscan = off;

SET LOCAL enable_bitmapscan = off;

EXPLAIN (
    ANALYZE,
    BUFFERS
)
SELECT
    *
FROM
    warehouse.stock_movements
WHERE
    product_id = (
        SELECT
            MIN(product_id)
        FROM
            warehouse.stock_movements)
ORDER BY
    created_at DESC
LIMIT 20;

ROLLBACK;
